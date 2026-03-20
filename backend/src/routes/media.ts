import { Router, Response } from 'express';

import { prisma } from '../lib/prisma';
import { broadcastToStore } from '../lib/realtime';
import { getEffectiveEntitlement } from '../lib/storeAccess';
import { saveThumbnailData } from '../lib/media';
import { AuthRequest } from '../middleware/auth';

export const mediaRouter = Router();

mediaRouter.get('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const itemId = req.query.itemId as string | undefined;
    const media = await prisma.mediaAsset.findMany({
      where: {
        storeId: req.storeId,
        ...(itemId && { itemId }),
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json(media);
  } catch {
    res.status(500).json({ error: 'Failed to load media.' });
  }
});

mediaRouter.post('/', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const entitlement = await getEffectiveEntitlement(req.storeId);
    if (!entitlement.allowMediaUpload) {
      res.status(403).json({ error: 'This package does not allow media uploads.' });
      return;
    }

    const {
      itemId,
      deviceId,
      fileName,
      mimeType,
      thumbnailData,
      width,
      height,
      fileSize,
    } = req.body;

    if (!fileName || !mimeType || !thumbnailData) {
      res.status(400).json({ error: 'fileName, mimeType, and thumbnailData are required.' });
      return;
    }

    const resolvedItemId =
      itemId && req.storeId
        ? (
            await prisma.item.findFirst({
              where: { id: itemId, storeId: req.storeId },
              select: { id: true },
            })
          )?.id ?? null
        : null;
    const resolvedDeviceId =
      deviceId && req.storeId
        ? (
            await prisma.device.findFirst({
              where: { id: deviceId, storeId: req.storeId },
              select: { id: true },
            })
          )?.id ?? null
        : null;

    const thumbnailPath = await saveThumbnailData(
      req.storeId,
      `${Date.now()}-${fileName}`,
      thumbnailData,
    );

    const media = await prisma.mediaAsset.create({
      data: {
        storeId: req.storeId,
        itemId: resolvedItemId,
        deviceId: resolvedDeviceId,
        fileName,
        mimeType,
        thumbnailPath,
        width: width ? Number(width) : null,
        height: height ? Number(height) : null,
        fileSize: fileSize ? Number(fileSize) : null,
      },
    });

    await prisma.activityLog.create({
      data: {
        userId: req.userId,
        storeId: req.storeId,
        action: 'UPLOAD_MEDIA',
        details: { mediaId: media.id, itemId, fileName },
      },
    });

    broadcastToStore(req.storeId, 'media.created', { media });
    res.status(201).json(media);
  } catch (error) {
    console.error('Media upload error:', error);
    res.status(500).json({ error: 'Failed to upload media.' });
  }
});
