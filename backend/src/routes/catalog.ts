import { Router, Response } from 'express';

import { prisma } from '../lib/prisma';
import { broadcastToStore } from '../lib/realtime';
import { AuthRequest } from '../middleware/auth';

export const catalogRouter = Router();

catalogRouter.get('/categories', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const categories = await prisma.category.findMany({
      where: { storeId: req.storeId },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });

    res.json(categories);
  } catch {
    res.status(500).json({ error: 'Failed to load categories.' });
  }
});

catalogRouter.post('/categories', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const category = await prisma.category.create({
      data: {
        storeId: req.storeId,
        name: req.body.name,
        color: Number(req.body.color) || 4282155766,
        sortOrder: Number(req.body.sortOrder) || 0,
      },
    });

    broadcastToStore(req.storeId, 'catalog.category.created', { category });
    res.status(201).json(category);
  } catch {
    res.status(500).json({ error: 'Failed to create category.' });
  }
});

catalogRouter.patch('/categories/:categoryId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.category.update({
      where: { id: req.params.categoryId },
      data: {
        ...(req.body.name && { name: req.body.name }),
        ...(req.body.color !== undefined && { color: Number(req.body.color) || 0 }),
        ...(req.body.sortOrder !== undefined && {
          sortOrder: Number(req.body.sortOrder) || 0,
        }),
      },
    });
    if (req.storeId) {
      broadcastToStore(req.storeId, 'catalog.category.updated', { category: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update category.' });
  }
});

catalogRouter.delete('/categories/:categoryId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    await prisma.category.delete({ where: { id: req.params.categoryId } });
    await prisma.tombstone.create({
      data: {
        storeId: req.storeId,
        entityType: 'CATEGORY',
        entityId: req.params.categoryId,
      },
    });
    broadcastToStore(req.storeId, 'catalog.category.deleted', {
      categoryId: req.params.categoryId,
    });
    res.json({ message: 'Category deleted.' });
  } catch {
    res.status(500).json({ error: 'Failed to delete category.' });
  }
});

catalogRouter.get('/items', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const items = await prisma.item.findMany({
      where: { storeId: req.storeId },
      include: {
        category: true,
        kitchenStation: true,
        mediaAssets: true,
      },
      orderBy: [{ name: 'asc' }],
    });

    res.json(
      items.map((item) => ({
        ...item,
        imageUrl: item.mediaAssets[0]?.thumbnailPath ?? null,
      })),
    );
  } catch {
    res.status(500).json({ error: 'Failed to load items.' });
  }
});

catalogRouter.post('/items', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const item = await prisma.item.create({
      data: {
        storeId: req.storeId,
        name: req.body.name,
        price: Number(req.body.price) || 0,
        cost: Number(req.body.cost) || 0,
        categoryId: req.body.categoryId || null,
        kitchenStationId: req.body.kitchenStationId || null,
        barcode: req.body.barcode || null,
        sku: req.body.sku || null,
        trackStock: Boolean(req.body.trackStock),
        stockQty: Number(req.body.stockQuantity) || 0,
        lowStockAt: Number(req.body.lowStockThreshold) || 5,
        modifiers: req.body.modifiers || [],
        isActive: req.body.isActive !== undefined ? Boolean(req.body.isActive) : true,
      },
      include: {
        category: true,
        kitchenStation: true,
        mediaAssets: true,
      },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'catalog.item.created', { item });
    }

    res.status(201).json({
      ...item,
      imageUrl: item.mediaAssets[0]?.thumbnailPath ?? null,
    });
  } catch {
    res.status(500).json({ error: 'Failed to create item.' });
  }
});

catalogRouter.patch('/items/:itemId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.item.update({
      where: { id: req.params.itemId },
      data: {
        ...(req.body.name && { name: req.body.name }),
        ...(req.body.price !== undefined && { price: Number(req.body.price) || 0 }),
        ...(req.body.cost !== undefined && { cost: Number(req.body.cost) || 0 }),
        ...(req.body.categoryId !== undefined && { categoryId: req.body.categoryId || null }),
        ...(req.body.kitchenStationId !== undefined && {
          kitchenStationId: req.body.kitchenStationId || null,
        }),
        ...(req.body.barcode !== undefined && { barcode: req.body.barcode || null }),
        ...(req.body.sku !== undefined && { sku: req.body.sku || null }),
        ...(req.body.trackStock !== undefined && {
          trackStock: Boolean(req.body.trackStock),
        }),
        ...(req.body.stockQuantity !== undefined && {
          stockQty: Number(req.body.stockQuantity) || 0,
        }),
        ...(req.body.lowStockThreshold !== undefined && {
          lowStockAt: Number(req.body.lowStockThreshold) || 5,
        }),
        ...(req.body.modifiers !== undefined && { modifiers: req.body.modifiers || [] }),
        ...(req.body.isActive !== undefined && { isActive: Boolean(req.body.isActive) }),
      },
      include: {
        category: true,
        kitchenStation: true,
        mediaAssets: true,
      },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'catalog.item.updated', { item: updated });
    }

    res.json({
      ...updated,
      imageUrl: updated.mediaAssets[0]?.thumbnailPath ?? null,
    });
  } catch {
    res.status(500).json({ error: 'Failed to update item.' });
  }
});

catalogRouter.delete('/items/:itemId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    await prisma.item.update({
      where: { id: req.params.itemId },
      data: { isActive: false },
    });
    await prisma.tombstone.create({
      data: {
        storeId: req.storeId,
        entityType: 'ITEM',
        entityId: req.params.itemId,
      },
    });
    broadcastToStore(req.storeId, 'catalog.item.deleted', { itemId: req.params.itemId });
    res.json({ message: 'Item deleted.' });
  } catch {
    res.status(500).json({ error: 'Failed to delete item.' });
  }
});
