import { Router, Response } from 'express';
import { DevicePlatform, DeviceStatus, DeviceType, ScannerMode, SyncProfile } from '@prisma/client';

import { prisma } from '../lib/prisma';
import { broadcastToStore } from '../lib/realtime';
import { assertStoreLimit } from '../lib/storeAccess';
import { AuthRequest } from '../middleware/auth';

export const devicesRouter = Router();

devicesRouter.get('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const devices = await prisma.device.findMany({
      where: { storeId: req.storeId },
      include: {
        kitchenScreens: {
          include: { station: true },
        },
      },
      orderBy: { createdAt: 'asc' },
    });

    res.json(devices);
  } catch {
    res.status(500).json({ error: 'Failed to load devices.' });
  }
});

devicesRouter.post('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const {
      id,
      name,
      type,
      platform,
      scannerMode,
      syncProfile,
    } = req.body;

    if (!id || !name) {
      res.status(400).json({ error: 'Device id and name are required.' });
      return;
    }

    await assertStoreLimit(req.storeId, 'devices');

    const device = await prisma.device.create({
      data: {
        id,
        storeId: req.storeId,
        name,
        type: Object.values(DeviceType).includes(type) ? type : DeviceType.POS,
        platform: Object.values(DevicePlatform).includes(platform)
          ? platform
          : DevicePlatform.ANDROID,
        scannerMode: Object.values(ScannerMode).includes(scannerMode)
          ? scannerMode
          : ScannerMode.AUTO,
        syncProfile: Object.values(SyncProfile).includes(syncProfile)
          ? syncProfile
          : SyncProfile.OFF,
        status: DeviceStatus.ONLINE,
        lastSeenAt: new Date(),
      },
    });

    broadcastToStore(req.storeId, 'device.created', { device });
    res.status(201).json(device);
  } catch (error) {
    if (error instanceof Error && error.name === 'StoreLimitError') {
      res.status(409).json({ error: error.message });
      return;
    }

    res.status(500).json({ error: 'Failed to create device.' });
  }
});

devicesRouter.patch('/:deviceId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.device.update({
      where: { id: req.params.deviceId },
      data: {
        ...(req.body.name && { name: req.body.name }),
        ...(req.body.type && { type: req.body.type }),
        ...(req.body.platform && { platform: req.body.platform }),
        ...(req.body.scannerMode && { scannerMode: req.body.scannerMode }),
        ...(req.body.syncProfile && { syncProfile: req.body.syncProfile }),
        ...(req.body.status && { status: req.body.status }),
        ...(req.body.isActive !== undefined && { isActive: Boolean(req.body.isActive) }),
        lastSeenAt: new Date(),
      },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'device.updated', { device: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update device.' });
  }
});

devicesRouter.post('/:deviceId/ping', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.device.update({
      where: { id: req.params.deviceId },
      data: {
        status: DeviceStatus.ONLINE,
        lastSeenAt: new Date(),
      },
    });
    if (req.storeId) {
      broadcastToStore(req.storeId, 'device.ping', { device: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to ping device.' });
  }
});

devicesRouter.delete('/:deviceId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.device.update({
      where: { id: req.params.deviceId },
      data: {
        isActive: false,
        status: DeviceStatus.BLOCKED,
      },
    });

    if (req.storeId) {
      await prisma.tombstone.create({
        data: {
          storeId: req.storeId,
          entityType: 'DEVICE',
          entityId: updated.id,
        },
      });
      broadcastToStore(req.storeId, 'device.deleted', { deviceId: updated.id });
    }

    res.json({ message: 'Device blocked.' });
  } catch {
    res.status(500).json({ error: 'Failed to delete device.' });
  }
});
