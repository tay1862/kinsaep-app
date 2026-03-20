import { Router, Response } from 'express';
import bcrypt from 'bcryptjs';

import { prisma } from '../lib/prisma';
import { broadcastToStore } from '../lib/realtime';
import { assertStoreLimit } from '../lib/storeAccess';
import { AuthRequest } from '../middleware/auth';
import { createLocalPinHash } from '../utils/pinHash';

export const staffRouter = Router();

staffRouter.get('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const staff = await prisma.staff.findMany({
      where: { storeId },
      select: {
        id: true,
        name: true,
        role: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });
    res.json(staff);
  } catch {
    res.status(500).json({ error: 'Failed to load staff.' });
  }
});

staffRouter.post('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const { name, pin, role } = req.body;
    if (!name || !pin) {
      res.status(400).json({ error: 'Name and PIN are required.' });
      return;
    }
    if (pin.length < 4 || pin.length > 6) {
      res.status(400).json({ error: 'PIN must be 4-6 digits.' });
      return;
    }
    if (!['OWNER', 'MANAGER', 'CASHIER'].includes(role)) {
      res
        .status(400)
        .json({ error: 'Role must be OWNER, MANAGER, or CASHIER.' });
      return;
    }

    await assertStoreLimit(storeId, 'staff');

    const hashedPin = await bcrypt.hash(pin, 10);
    const staff = await prisma.staff.create({
      data: {
        storeId,
        name,
        pin: hashedPin,
        pinLocalHash: createLocalPinHash(pin),
        role,
      },
    });

    await prisma.activityLog.create({
      data: {
        userId: req.userId,
        storeId,
        action: 'CREATE_STAFF',
        details: { staffName: name, role },
      },
    });

    broadcastToStore(storeId, 'staff.created', {
      staffId: staff.id,
      name: staff.name,
      role: staff.role,
    });

    res.status(201).json({
      id: staff.id,
      name: staff.name,
      role: staff.role,
      isActive: staff.isActive,
      createdAt: staff.createdAt,
      updatedAt: staff.updatedAt,
    });
  } catch (error) {
    if (error instanceof Error && error.name === 'StoreLimitError') {
      res.status(409).json({ error: error.message });
      return;
    }
    res.status(500).json({ error: 'Failed to create staff.' });
  }
});

staffRouter.post('/verify-pin', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const { pin } = req.body;
    if (!pin) {
      res.status(400).json({ error: 'PIN is required.' });
      return;
    }

    const staffMembers = await prisma.staff.findMany({
      where: { storeId, isActive: true },
    });

    for (const staff of staffMembers) {
      const match = await bcrypt.compare(pin, staff.pin);
      if (match) {
        await prisma.activityLog.create({
          data: {
            storeId,
            staffId: staff.id,
            action: 'PIN_UNLOCK',
            details: { staffName: staff.name },
          },
        });
        res.json({ staffId: staff.id, name: staff.name, role: staff.role });
        return;
      }
    }

    res.status(401).json({ error: 'Invalid PIN.' });
  } catch {
    res.status(500).json({ error: 'PIN verification failed.' });
  }
});

staffRouter.patch('/:staffId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { staffId } = req.params;
    const { name, pin, role, isActive } = req.body;
    const data: Record<string, unknown> = {};

    if (name) {
      data.name = name;
    }
    if (role) {
      data.role = role;
    }
    if (isActive !== undefined) {
      data.isActive = isActive;
    }
    if (pin) {
      data.pin = await bcrypt.hash(pin, 10);
      data.pinLocalHash = createLocalPinHash(pin);
    }

    const updated = await prisma.staff.update({ where: { id: staffId }, data });
    if (req.storeId) {
      broadcastToStore(req.storeId, 'staff.updated', {
        staffId: updated.id,
        name: updated.name,
        role: updated.role,
        isActive: updated.isActive,
      });
    }
    res.json({
      id: updated.id,
      name: updated.name,
      role: updated.role,
      isActive: updated.isActive,
    });
  } catch {
    res.status(500).json({ error: 'Failed to update staff.' });
  }
});

staffRouter.delete('/:staffId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    const deleted = await prisma.staff.update({
      where: { id: req.params.staffId },
      data: { isActive: false },
    });

    if (storeId) {
      await prisma.tombstone.create({
        data: {
          storeId,
          entityType: 'STAFF',
          entityId: deleted.id,
        },
      });
      await prisma.activityLog.create({
        data: {
          userId: req.userId,
          storeId,
          action: 'DELETE_STAFF',
          details: { staffId: deleted.id, staffName: deleted.name },
        },
      });
      broadcastToStore(storeId, 'staff.deleted', {
        staffId: deleted.id,
      });
    }

    res.json({ message: 'Staff deactivated.' });
  } catch {
    res.status(500).json({ error: 'Failed to delete staff.' });
  }
});
