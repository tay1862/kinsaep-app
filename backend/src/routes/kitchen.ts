import { Router, Response } from 'express';
import { KitchenStationType, KitchenTicketStatus } from '@prisma/client';

import { prisma } from '../lib/prisma';
import { broadcastToStore } from '../lib/realtime';
import { assertStoreLimit } from '../lib/storeAccess';
import { AuthRequest } from '../middleware/auth';

export const kitchenRouter = Router();

kitchenRouter.get('/stations', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const stations = await prisma.kitchenStation.findMany({
      where: { storeId: req.storeId },
      include: { screens: true, items: { select: { id: true, name: true } } },
      orderBy: [{ type: 'asc' }, { name: 'asc' }],
    });

    res.json(stations);
  } catch {
    res.status(500).json({ error: 'Failed to load stations.' });
  }
});

kitchenRouter.post('/stations', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const { name, type } = req.body;
    if (!name || !Object.values(KitchenStationType).includes(type)) {
      res.status(400).json({ error: 'Station name and type are required.' });
      return;
    }

    await assertStoreLimit(req.storeId, 'stations');

    const station = await prisma.kitchenStation.create({
      data: {
        storeId: req.storeId,
        name,
        type,
      },
    });

    broadcastToStore(req.storeId, 'kitchen.station.created', { station });
    res.status(201).json(station);
  } catch (error) {
    if (error instanceof Error && error.name === 'StoreLimitError') {
      res.status(409).json({ error: error.message });
      return;
    }
    res.status(500).json({ error: 'Failed to create station.' });
  }
});

kitchenRouter.patch('/stations/:stationId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.kitchenStation.update({
      where: { id: req.params.stationId },
      data: {
        ...(req.body.name && { name: req.body.name }),
        ...(req.body.type && { type: req.body.type }),
        ...(req.body.isActive !== undefined && { isActive: Boolean(req.body.isActive) }),
      },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'kitchen.station.updated', { station: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update station.' });
  }
});

kitchenRouter.get('/screens', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const screens = await prisma.kitchenScreen.findMany({
      where: { storeId: req.storeId },
      include: { station: true, device: true },
      orderBy: { createdAt: 'asc' },
    });
    res.json(screens);
  } catch {
    res.status(500).json({ error: 'Failed to load kitchen screens.' });
  }
});

kitchenRouter.post('/screens', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const { stationId, deviceId, label } = req.body;
    if (!stationId || !deviceId || !label) {
      res.status(400).json({ error: 'Station, device, and label are required.' });
      return;
    }

    await assertStoreLimit(req.storeId, 'kitchenScreens');

    const screen = await prisma.kitchenScreen.create({
      data: {
        storeId: req.storeId,
        stationId,
        deviceId,
        label,
      },
      include: { station: true, device: true },
    });

    broadcastToStore(req.storeId, 'kitchen.screen.created', { screen });
    res.status(201).json(screen);
  } catch (error) {
    if (error instanceof Error && error.name === 'StoreLimitError') {
      res.status(409).json({ error: error.message });
      return;
    }
    res.status(500).json({ error: 'Failed to create kitchen screen.' });
  }
});

kitchenRouter.patch('/screens/:screenId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.kitchenScreen.update({
      where: { id: req.params.screenId },
      data: {
        ...(req.body.stationId && { stationId: req.body.stationId }),
        ...(req.body.label && { label: req.body.label }),
        ...(req.body.isActive !== undefined && { isActive: Boolean(req.body.isActive) }),
      },
      include: { station: true, device: true },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'kitchen.screen.updated', { screen: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update kitchen screen.' });
  }
});

kitchenRouter.get('/tickets', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const status = req.query.status as KitchenTicketStatus | undefined;
    const stationId = req.query.stationId as string | undefined;

    const tickets = await prisma.kitchenTicket.findMany({
      where: {
        storeId: req.storeId,
        ...(status && { status }),
        ...(stationId && { items: { some: { stationId } } }),
      },
      include: {
        items: {
          include: { station: true },
          orderBy: { createdAt: 'asc' },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    res.json(tickets);
  } catch {
    res.status(500).json({ error: 'Failed to load kitchen tickets.' });
  }
});

kitchenRouter.post('/tickets', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'No store context.' });
      return;
    }

    const { saleId, sourceDeviceId, note, items } = req.body as {
      saleId?: string;
      sourceDeviceId?: string;
      note?: string;
      items?: Array<{
        itemId?: string;
        stationId?: string;
        itemName: string;
        quantity: number;
        note?: string;
      }>;
    };

    if (!items?.length) {
      res.status(400).json({ error: 'Ticket items are required.' });
      return;
    }

    const ticket = await prisma.kitchenTicket.create({
      data: {
        storeId: req.storeId,
        saleId,
        sourceDeviceId,
        note: note || null,
        items: {
          create: items.map((item) => ({
            itemId: item.itemId || null,
            stationId: item.stationId || null,
            itemName: item.itemName,
            quantity: Number(item.quantity) || 1,
            note: item.note || null,
          })),
        },
      },
      include: {
        items: {
          include: { station: true },
        },
      },
    });

    broadcastToStore(req.storeId, 'kitchen.ticket.created', { ticket });
    res.status(201).json(ticket);
  } catch {
    res.status(500).json({ error: 'Failed to create kitchen ticket.' });
  }
});

kitchenRouter.patch('/tickets/:ticketId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const updated = await prisma.kitchenTicket.update({
      where: { id: req.params.ticketId },
      data: {
        ...(req.body.status && { status: req.body.status }),
        ...(req.body.note !== undefined && { note: req.body.note || null }),
      },
      include: {
        items: {
          include: { station: true },
        },
      },
    });

    if (req.storeId) {
      broadcastToStore(req.storeId, 'kitchen.ticket.updated', { ticket: updated });
    }
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update kitchen ticket.' });
  }
});
