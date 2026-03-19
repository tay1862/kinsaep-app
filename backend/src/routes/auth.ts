import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

import { prisma } from '../lib/prisma';
import { createLocalPinHash } from '../utils/pinHash';

export const authRouter = Router();

authRouter.post('/register', async (req, res: Response): Promise<void> => {
  try {
    const { email, password, name, phone, storeName, businessType, currency, locale } = req.body;

    if (!email || !password || !name || !storeName) {
      res
        .status(400)
        .json({ error: 'Email, password, name, and storeName are required.' });
      return;
    }
    if (password.length < 6) {
      res.status(400).json({ error: 'Password must be at least 6 characters.' });
      return;
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      res.status(409).json({ error: 'Email already registered.' });
      return;
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const defaultPin = '0000';
    const farFuture = new Date('2099-12-31T23:59:59.000Z');

    const result = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email,
          password: hashedPassword,
          name,
          phone: phone || null,
          role: 'OWNER',
        },
      });

      const store = await tx.store.create({
        data: {
          name: storeName,
          businessType: businessType || 'retail',
          currency: currency || 'LAK',
          locale: locale || 'lo',
          ownerId: user.id,
        },
      });

      await tx.subscription.create({
        data: {
          storeId: store.id,
          plan: 'FREE',
          status: 'BLOCKED',
          validUntil: farFuture,
        },
      });

      await tx.staff.create({
        data: {
          storeId: store.id,
          name,
          pin: await bcrypt.hash(defaultPin, 10),
          pinLocalHash: createLocalPinHash(defaultPin),
          role: 'OWNER',
        },
      });

      await tx.activityLog.create({
        data: {
          userId: user.id,
          storeId: store.id,
          action: 'REGISTER',
          details: { email, storeName, accessMode: 'OFFLINE_ONLY' },
        },
      });

      return { user, store };
    });

    const accessToken = generateAccessToken(result.user.id, result.user.role, result.store.id);
    const refreshToken = generateRefreshToken(result.user.id);

    res.status(201).json({
      message:
        'Cloud store created. Sync stays offline-only until an admin activates your subscription.',
      accessToken,
      refreshToken,
      user: { id: result.user.id, email: result.user.email, name: result.user.name },
      store: {
        id: result.store.id,
        name: result.store.name,
        currency: result.store.currency,
        locale: result.store.locale,
      },
      subscriptionStatus: 'BLOCKED',
    });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Registration failed.' });
  }
});

authRouter.post('/login', async (req, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ error: 'Email and password are required.' });
      return;
    }

    const user = await prisma.user.findUnique({
      where: { email },
      include: {
        stores: {
          include: { subscription: true },
          take: 1,
        },
      },
    });

    if (!user || !user.isActive) {
      res.status(401).json({ error: 'Invalid email or password.' });
      return;
    }

    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) {
      res.status(401).json({ error: 'Invalid email or password.' });
      return;
    }

    const store = user.stores[0];
    const storeId = store?.id;

    const subscriptionStatus = await resolveSubscriptionStatus(store?.subscription?.id ?? null);

    await prisma.activityLog.create({
      data: {
        userId: user.id,
        storeId,
        action: 'LOGIN',
        details: { subscriptionStatus },
        ipAddress: req.ip,
      },
    });

    const accessToken = generateAccessToken(user.id, user.role, storeId);
    const refreshToken = generateRefreshToken(user.id);

    res.json({
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, name: user.name, role: user.role },
      store: store
        ? {
            id: store.id,
            name: store.name,
            currency: store.currency,
            locale: store.locale,
          }
        : null,
      subscriptionStatus,
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Login failed.' });
  }
});

authRouter.post('/refresh', async (req, res: Response): Promise<void> => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      res.status(400).json({ error: 'Refresh token is required.' });
      return;
    }

    const decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET!) as {
      userId: string;
    };
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      include: { stores: { take: 1 } },
    });

    if (!user || !user.isActive) {
      res.status(401).json({ error: 'User not found or inactive.' });
      return;
    }

    const storeId = user.stores[0]?.id;
    const accessToken = generateAccessToken(user.id, user.role, storeId);
    const newRefreshToken = generateRefreshToken(user.id);

    res.json({ accessToken, refreshToken: newRefreshToken });
  } catch {
    res.status(401).json({ error: 'Invalid refresh token.' });
  }
});

authRouter.post('/forgot-password', async (req, res: Response): Promise<void> => {
  try {
    const { email } = req.body;
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      res.json({ message: 'If the email exists, a reset link has been sent.' });
      return;
    }

    const resetToken = jwt.sign(
      { userId: user.id, type: 'reset' },
      process.env.JWT_SECRET!,
      { expiresIn: '1h' },
    );

    await prisma.activityLog.create({
      data: { userId: user.id, action: 'PASSWORD_RESET_REQUEST' },
    });

    res.json({
      message: 'If the email exists, a reset link has been sent.',
      ...(process.env.NODE_ENV === 'development' && { resetToken }),
    });
  } catch {
    res.status(500).json({ error: 'Failed to process request.' });
  }
});

async function resolveSubscriptionStatus(subscriptionId: string | null): Promise<string> {
  if (!subscriptionId) {
    return 'NONE';
  }

  const subscription = await prisma.subscription.findUnique({ where: { id: subscriptionId } });
  if (!subscription) {
    return 'NONE';
  }

  if (subscription.status === 'BLOCKED' || subscription.status === 'CANCELLED') {
    return 'BLOCKED';
  }

  const now = new Date();
  if (subscription.status === 'ACTIVE' && now > subscription.validUntil) {
    await prisma.subscription.update({
      where: { id: subscription.id },
      data: { status: 'EXPIRED' },
    });
    return 'EXPIRED';
  }

  return subscription.status;
}

function generateAccessToken(userId: string, role: string, storeId?: string): string {
  return jwt.sign({ userId, role, storeId }, process.env.JWT_SECRET!, {
    expiresIn: '24h',
  });
}

function generateRefreshToken(userId: string): string {
  return jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET!, { expiresIn: '30d' });
}
