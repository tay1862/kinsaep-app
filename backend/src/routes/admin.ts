import { Router, Response } from 'express';
import { Subscription, SubscriptionStatus } from '@prisma/client';

import { prisma } from '../lib/prisma';
import { AuthRequest, requireAdmin } from '../middleware/auth';

export const adminRouter = Router();

adminRouter.use(requireAdmin);

adminRouter.get('/dashboard', async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const [stores, totalUsers, recentActivity] = await Promise.all([
      prisma.store.findMany({ include: { subscription: true } }),
      prisma.user.count(),
      prisma.activityLog.findMany({
        orderBy: { createdAt: 'desc' },
        take: 20,
        include: {
          user: { select: { name: true, email: true } },
          store: { select: { name: true } },
        },
      }),
    ]);

    const summary = stores.reduce<Record<string, number>>((accumulator, store) => {
      const accessMode = getAccessMode(store.subscription);
      accumulator[accessMode] = (accumulator[accessMode] ?? 0) + 1;
      return accumulator;
    }, {});

    res.json({
      totalStores: stores.length,
      activeStores: summary.ACTIVE ?? 0,
      totalUsers,
      statusBreakdown: summary,
      recentActivity,
    });
  } catch (error) {
    console.error('Admin dashboard error:', error);
    res.status(500).json({ error: 'Failed to load dashboard.' });
  }
});

adminRouter.get('/stores', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const skip = (page - 1) * limit;

    const [stores, total] = await Promise.all([
      prisma.store.findMany({
        skip,
        take: limit,
        include: {
          owner: { select: { name: true, email: true, phone: true } },
          subscription: true,
          _count: { select: { sales: true, items: true, staff: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.store.count(),
    ]);

    res.json({
      stores: stores.map((store) => ({
        id: store.id,
        name: store.name,
        owner: store.owner,
        subscription: store.subscription,
        accessMode: getAccessMode(store.subscription),
        counts: {
          sales: store._count.sales,
          items: store._count.items,
          staff: store._count.staff,
        },
      })),
      total,
      page,
      totalPages: Math.ceil(total / limit),
    });
  } catch {
    res.status(500).json({ error: 'Failed to load stores.' });
  }
});

adminRouter.get('/stores/:storeId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const store = await prisma.store.findUnique({
      where: { id: req.params.storeId },
      include: {
        owner: { select: { name: true, email: true, phone: true, createdAt: true } },
        subscription: true,
        staff: { select: { id: true, name: true, role: true, isActive: true } },
        _count: { select: { sales: true, items: true, categories: true, shifts: true } },
      },
    });

    if (!store) {
      res.status(404).json({ error: 'Store not found.' });
      return;
    }

    res.json({
      ...store,
      accessMode: getAccessMode(store.subscription),
    });
  } catch {
    res.status(500).json({ error: 'Failed to load store.' });
  }
});

adminRouter.patch(
  '/stores/:storeId/subscription',
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { status, plan, validUntil } = req.body;
      const { storeId } = req.params;

      const subscription = await prisma.subscription.findUnique({ where: { storeId } });
      if (!subscription) {
        res.status(404).json({ error: 'Subscription not found for this store.' });
        return;
      }

      const nextValidUntil =
        status === 'ACTIVE'
          ? validUntil
            ? new Date(validUntil)
            : subscription.validUntil > new Date()
                ? subscription.validUntil
                : new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
          : validUntil
              ? new Date(validUntil)
              : subscription.validUntil;

      const updated = await prisma.subscription.update({
        where: { storeId },
        data: {
          ...(status && { status }),
          ...(plan && { plan }),
          validUntil: nextValidUntil,
        },
      });

      await prisma.activityLog.create({
        data: {
          userId: req.userId,
          storeId,
          action: status === 'BLOCKED' ? 'ADMIN_BLOCK_STORE' : 'ADMIN_UPDATE_SUBSCRIPTION',
          details: {
            oldStatus: subscription.status,
            newStatus: status,
            plan,
            validUntil: nextValidUntil,
          },
        },
      });

      res.json({
        message: 'Subscription updated.',
        subscription: updated,
        accessMode: getAccessMode(updated),
      });
    } catch {
      res.status(500).json({ error: 'Failed to update subscription.' });
    }
  },
);

adminRouter.get('/logs', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 50;
    const storeId = req.query.storeId as string | undefined;

    const where = storeId ? { storeId } : {};

    const [logs, total] = await Promise.all([
      prisma.activityLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
        include: {
          user: { select: { name: true, email: true } },
          store: { select: { name: true } },
          staff: { select: { name: true, role: true } },
        },
      }),
      prisma.activityLog.count({ where }),
    ]);

    res.json({ logs, total, page, totalPages: Math.ceil(total / limit) });
  } catch {
    res.status(500).json({ error: 'Failed to load logs.' });
  }
});

function getAccessMode(
  subscription: Subscription | null,
): 'OFFLINE_ONLY' | 'ACTIVE' | 'BLOCKED' | 'EXPIRED' {
  if (!subscription) {
    return 'OFFLINE_ONLY';
  }

  if (subscription.status === SubscriptionStatus.ACTIVE) {
    return subscription.validUntil > new Date() ? 'ACTIVE' : 'EXPIRED';
  }

  if (subscription.status === SubscriptionStatus.EXPIRED) {
    return 'EXPIRED';
  }

  if (
    subscription.status === SubscriptionStatus.BLOCKED &&
    subscription.plan === 'FREE'
  ) {
    return 'OFFLINE_ONLY';
  }

  return 'BLOCKED';
}
