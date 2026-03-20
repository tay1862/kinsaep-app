import { Router, Response } from 'express';
import { DeviceStatus, Prisma, SyncDirection, SyncJobStatus, SyncProfile } from '@prisma/client';

import { prisma } from '../lib/prisma';
import { broadcastToAdmins, broadcastToStore } from '../lib/realtime';
import {
  assertSyncProfileAllowed,
  createEntitlementSummary,
  getEffectiveEntitlement,
  normalizeSyncProfile,
  StoreAccessError,
} from '../lib/storeAccess';
import { AuthRequest } from '../middleware/auth';

export const syncRouter = Router();

syncRouter.get('/status', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'Store ID not found.' });
      return;
    }

    const entitlement = await getEffectiveEntitlement(req.storeId);
    const lastJob = await prisma.syncJob.findFirst({
      where: { storeId: req.storeId },
      orderBy: { createdAt: 'desc' },
    });

    res.json({
      accessMode: entitlement.accessMode,
      entitlement: createEntitlementSummary(entitlement),
      lastJob,
      serverTime: new Date().toISOString(),
    });
  } catch {
    res.status(500).json({ error: 'Failed to load sync status.' });
  }
});

syncRouter.get('/jobs', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    if (!req.storeId) {
      res.status(400).json({ error: 'Store ID not found.' });
      return;
    }

    const jobs = await prisma.syncJob.findMany({
      where: { storeId: req.storeId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });

    res.json({ jobs });
  } catch {
    res.status(500).json({ error: 'Failed to load sync jobs.' });
  }
});

syncRouter.post('/push', async (req: AuthRequest, res: Response): Promise<void> => {
  let jobId: string | undefined;

  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'Store ID not found in token.' });
      return;
    }

    const syncProfile = normalizeSyncProfile(req.body.syncProfile);
    const entitlement = await assertSyncProfileAllowed(storeId, syncProfile);
    const scopes = normalizeScopes(req.body.scopes, syncProfile);
    const deviceId = toOptionalString(req.body.deviceId);

    const job = await prisma.syncJob.create({
      data: {
        storeId,
        deviceId,
        direction: SyncDirection.PUSH,
        syncProfile,
        status: SyncJobStatus.QUEUED,
        progress: 0,
        scopes,
      },
    });
    jobId = job.id;
    await updateJob(job.id, 10, SyncJobStatus.RUNNING);

    if (deviceId) {
      await upsertDeviceHeartbeat(storeId, deviceId, req.body, syncProfile);
    }

    const counts = {
      categories: 0,
      items: 0,
      staff: 0,
      salesSummaries: 0,
      sales: 0,
      saleItems: 0,
      shifts: 0,
      kitchenTickets: 0,
      tombstones: 0,
    };

    await prisma.$transaction(async (tx) => {
      if (scopes.store && req.body.store) {
        const store = req.body.store as Record<string, unknown>;
        await tx.store.update({
          where: { id: storeId },
          data: {
            ...(store.name ? { name: String(store.name) } : {}),
            ...(store.address !== undefined
              ? { address: nullableString(store.address) }
              : {}),
            ...(store.phone !== undefined ? { phone: nullableString(store.phone) } : {}),
            ...(store.businessType
              ? { businessType: String(store.businessType) }
              : {}),
            ...(store.currency ? { currency: String(store.currency) } : {}),
            ...(store.locale ? { locale: String(store.locale) } : {}),
            ...(store.taxEnabled !== undefined && {
              taxEnabled: toBool(store.taxEnabled),
            }),
            ...(store.taxRate !== undefined && { taxRate: Number(store.taxRate) || 0 }),
            ...(store.receiptHeader !== undefined && {
              receiptHeader: nullableString(store.receiptHeader),
            }),
            ...(store.receiptFooter !== undefined && {
              receiptFooter: nullableString(store.receiptFooter),
            }),
          },
        });
      }

      if (scopes.tombstones) {
        counts.tombstones = await applyTombstones(tx, storeId, toList(req.body.tombstones));
      }

      if (scopes.catalog) {
        counts.categories = await upsertCategories(tx, storeId, toList(req.body.categories));
        counts.items = await upsertItems(tx, storeId, toList(req.body.items));
      }

      if (scopes.staff) {
        counts.staff = await upsertStaff(tx, storeId, toList(req.body.staff));
      }

      if (scopes.summary) {
        counts.salesSummaries = await upsertSalesSummaries(
          tx,
          storeId,
          toList(req.body.salesSummaries),
        );
      }

      if (scopes.rawSales && entitlement.allowRawSalesSync) {
        counts.sales = await upsertSales(tx, storeId, deviceId, toList(req.body.sales));
        counts.saleItems = await upsertSaleItems(tx, toList(req.body.saleItems));
        counts.shifts = await upsertShifts(tx, storeId, toList(req.body.shifts));
      }

      if (scopes.kitchen) {
        counts.kitchenTickets = await upsertKitchenTickets(
          tx,
          storeId,
          deviceId,
          toList(req.body.kitchenTickets),
        );
      }
    });

    await updateJob(job.id, 100, SyncJobStatus.SUCCEEDED, counts);

    await prisma.activityLog.create({
      data: {
        userId: req.userId,
        storeId,
        action: 'SYNC_PUSH',
        details: {
          deviceId,
          syncProfile,
          scopes,
          counts,
        },
      },
    });

    res.json({
      message: 'Sync push successful',
      serverTime: new Date().toISOString(),
      jobId: job.id,
      accessMode: entitlement.accessMode,
      entitlement: createEntitlementSummary(entitlement),
      counts,
    });
  } catch (error) {
    console.error('Sync push error:', error);
    if (jobId) {
      await failJob(jobId, error);
    }
    if (error instanceof StoreAccessError) {
      res.status(403).json({
        error: error.message,
        accessMode: error.accessMode,
      });
      return;
    }
    res.status(500).json({ error: 'Sync push failed.' });
  }
});

syncRouter.get('/pull', async (req: AuthRequest, res: Response): Promise<void> => {
  let jobId: string | undefined;

  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'Store ID not found.' });
      return;
    }

    const syncProfile = normalizeSyncProfile(req.query.syncProfile);
    const requestedProfile = syncProfile === SyncProfile.OFF ? SyncProfile.LIGHT : syncProfile;
    const entitlement = await assertSyncProfileAllowed(storeId, requestedProfile);
    const scopes = normalizeScopes(req.query.scopes, requestedProfile);
    const deviceId = toOptionalString(req.query.deviceId);
    const since = req.query.since as string | undefined;
    const sinceDate = since ? new Date(since) : new Date(0);

    const job = await prisma.syncJob.create({
      data: {
        storeId,
        deviceId,
        direction: SyncDirection.PULL,
        syncProfile: requestedProfile,
        status: SyncJobStatus.QUEUED,
        progress: 0,
        scopes,
      },
    });
    jobId = job.id;
    await updateJob(job.id, 15, SyncJobStatus.RUNNING);

    if (deviceId) {
      await upsertDeviceHeartbeat(storeId, deviceId, req.query, requestedProfile);
    }

    const [store, categories, items, staff, devices, stations, screens, mediaAssets, tombstones, salesSummaries] =
      await Promise.all([
        prisma.store.findUnique({
          where: { id: storeId },
        }),
        scopes.catalog
          ? prisma.category.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
            })
          : Promise.resolve([]),
        scopes.catalog
          ? prisma.item.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
              include: { mediaAssets: true },
            })
          : Promise.resolve([]),
        scopes.staff
          ? prisma.staff.findMany({
              where: { storeId },
              orderBy: { createdAt: 'asc' },
            })
          : Promise.resolve([]),
        scopes.devices
          ? prisma.device.findMany({
              where: { storeId },
              orderBy: { createdAt: 'asc' },
            })
          : Promise.resolve([]),
        scopes.kitchen
          ? prisma.kitchenStation.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
            })
          : Promise.resolve([]),
        scopes.kitchen
          ? prisma.kitchenScreen.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
            })
          : Promise.resolve([]),
        scopes.media && entitlement.allowMediaUpload
          ? prisma.mediaAsset.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
            })
          : Promise.resolve([]),
        scopes.tombstones
          ? prisma.tombstone.findMany({
              where: { storeId, deletedAt: { gte: sinceDate } },
              orderBy: { deletedAt: 'asc' },
            })
          : Promise.resolve([]),
        scopes.summary
          ? prisma.salesSummary.findMany({
              where: { storeId, updatedAt: { gte: sinceDate } },
              orderBy: { businessDay: 'desc' },
            })
          : Promise.resolve([]),
      ]);

    const [sales, shifts, kitchenTickets] = await Promise.all([
      scopes.rawSales && entitlement.allowRawSalesSync
        ? prisma.sale.findMany({
            where: { storeId, updatedAt: { gte: sinceDate } },
            orderBy: { createdAt: 'desc' },
            take: 1000,
            include: { items: true },
          })
        : Promise.resolve([]),
      scopes.rawSales && entitlement.allowRawSalesSync
        ? prisma.shift.findMany({
            where: { storeId, openedAt: { gte: sinceDate } },
            orderBy: { openedAt: 'desc' },
            take: 200,
          })
        : Promise.resolve([]),
      scopes.kitchen
        ? prisma.kitchenTicket.findMany({
            where: { storeId, updatedAt: { gte: sinceDate } },
            include: { items: true },
            orderBy: { createdAt: 'desc' },
            take: 500,
          })
        : Promise.resolve([]),
    ]);

    await updateJob(job.id, 85, SyncJobStatus.RUNNING, {
      categories: categories.length,
      items: items.length,
      staff: staff.length,
      devices: devices.length,
      stations: stations.length,
      screens: screens.length,
      mediaAssets: mediaAssets.length,
      tombstones: tombstones.length,
      salesSummaries: salesSummaries.length,
      sales: sales.length,
      shifts: shifts.length,
      kitchenTickets: kitchenTickets.length,
    });

    await updateJob(job.id, 100, SyncJobStatus.SUCCEEDED);

    res.json({
      serverTime: new Date().toISOString(),
      accessMode: entitlement.accessMode,
      entitlement: createEntitlementSummary(entitlement),
      syncProfile: requestedProfile,
      scopes,
      store: store
        ? {
            id: store.id,
            name: store.name,
            address: store.address,
            phone: store.phone,
            businessType: store.businessType,
            currency: store.currency,
            locale: store.locale,
            taxEnabled: store.taxEnabled,
            taxRate: store.taxRate,
            receiptHeader: store.receiptHeader,
            receiptFooter: store.receiptFooter,
          }
        : null,
      categories: categories.map((category) => ({
        id: category.id,
        name: category.name,
        color: category.color,
        sortOrder: category.sortOrder,
        createdAt: category.createdAt.toISOString(),
        updatedAt: category.updatedAt.toISOString(),
      })),
      items: items.map((item) => ({
        id: item.id,
        name: item.name,
        price: item.price,
        cost: item.cost,
        categoryId: item.categoryId,
        kitchenStationId: item.kitchenStationId,
        barcode: item.barcode,
        sku: item.sku,
        trackStock: item.trackStock,
        stockQuantity: item.stockQty,
        lowStockThreshold: item.lowStockAt,
        modifiers: item.modifiers,
        isActive: item.isActive,
        imageUrl: item.mediaAssets[0]?.thumbnailPath ?? null,
        createdAt: item.createdAt.toISOString(),
        updatedAt: item.updatedAt.toISOString(),
      })),
      staff: staff.map((member) => ({
        id: member.id,
        name: member.name,
        role: member.role,
        pinHash: member.pinLocalHash,
        isActive: member.isActive,
        createdAt: member.createdAt.toISOString(),
        updatedAt: member.updatedAt.toISOString(),
      })),
      devices,
      kitchenStations: stations,
      kitchenScreens: screens,
      mediaAssets,
      tombstones,
      salesSummaries,
      sales: sales.map((sale) => ({
        id: sale.id,
        receiptNumber: sale.receiptNumber,
        subtotal: sale.subtotal,
        discountAmount: sale.discountAmount,
        discountPercent: sale.discountPercent,
        taxAmount: sale.taxAmount,
        totalAmount: sale.totalAmount,
        amountPaid: sale.amountPaid,
        changeAmount: sale.changeAmount,
        paymentMethod: sale.paymentMethod,
        status: sale.status,
        ticketName: sale.ticketName,
        deviceId: sale.deviceId,
        createdAt: sale.createdAt.toISOString(),
        updatedAt: sale.updatedAt.toISOString(),
      })),
      saleItems: sales.flatMap((sale) =>
        sale.items.map((saleItem) => ({
          id: saleItem.id,
          saleId: saleItem.saleId,
          itemId: saleItem.itemId,
          itemName: saleItem.itemName,
          quantity: saleItem.quantity,
          unitPrice: saleItem.unitPrice,
          totalPrice: saleItem.totalPrice,
        })),
      ),
      shifts: shifts.map((shift) => ({
        id: shift.id,
        openedAt: shift.openedAt.toISOString(),
        closedAt: shift.closedAt?.toISOString(),
        startingCash: shift.startingCash,
        cashAdded: shift.cashAdded,
        cashRemoved: shift.cashRemoved,
        expectedCash: shift.expectedCash,
        actualCash: shift.actualCash,
        difference: shift.difference,
        status: shift.status,
      })),
      kitchenTickets: kitchenTickets.map((ticket) => ({
        id: ticket.id,
        saleId: ticket.saleId,
        sourceDeviceId: ticket.sourceDeviceId,
        status: ticket.status,
        note: ticket.note,
        createdAt: ticket.createdAt.toISOString(),
        updatedAt: ticket.updatedAt.toISOString(),
        items: ticket.items.map((item) => ({
          id: item.id,
          itemId: item.itemId,
          stationId: item.stationId,
          itemName: item.itemName,
          quantity: item.quantity,
          status: item.status,
          note: item.note,
          createdAt: item.createdAt.toISOString(),
          updatedAt: item.updatedAt.toISOString(),
        })),
      })),
    });
  } catch (error) {
    console.error('Sync pull error:', error);
    if (jobId) {
      await failJob(jobId, error);
    }
    if (error instanceof StoreAccessError) {
      res.status(403).json({
        error: error.message,
        accessMode: error.accessMode,
      });
      return;
    }
    res.status(500).json({ error: 'Sync pull failed.' });
  }
});

function toList(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value)
    ? value.filter((item): item is Record<string, unknown> => Boolean(item && typeof item === 'object'))
    : [];
}

function toOptionalString(value: unknown): string | undefined {
  if (typeof value !== 'string') {
    return undefined;
  }
  return value.trim() || undefined;
}

function nullableString(value: unknown): string | null {
  const output = toOptionalString(value);
  return output ?? null;
}

function toBool(value: unknown): boolean {
  return value === true || value === 1 || value === '1';
}

function normalizeScopes(value: unknown, syncProfile: SyncProfile) {
  const requested =
    typeof value === 'string'
      ? value.split(',').map((entry) => entry.trim()).filter(Boolean)
      : Array.isArray(value)
        ? value.filter((entry): entry is string => typeof entry === 'string')
        : [];

  const defaultScopes =
    syncProfile === SyncProfile.FULL
      ? ['store', 'catalog', 'staff', 'devices', 'kitchen', 'media', 'summary', 'rawSales', 'tombstones']
      : syncProfile === SyncProfile.LIGHT
        ? ['store', 'catalog', 'staff', 'devices', 'kitchen', 'media', 'summary', 'tombstones']
        : [];

  const source = requested.length ? requested : defaultScopes;
  return {
    store: source.includes('store'),
    catalog: source.includes('catalog'),
    staff: source.includes('staff'),
    devices: source.includes('devices'),
    kitchen: source.includes('kitchen'),
    media: source.includes('media'),
    summary: source.includes('summary'),
    rawSales: source.includes('rawSales'),
    tombstones: source.includes('tombstones'),
  };
}

async function upsertDeviceHeartbeat(
  storeId: string,
  deviceId: string,
  payload: Record<string, unknown>,
  syncProfile: SyncProfile,
): Promise<void> {
  await prisma.device.upsert({
    where: { id: deviceId },
    update: {
      ...(payload.deviceName ? { name: String(payload.deviceName) } : {}),
      ...(payload.deviceType ? { type: payload.deviceType as never } : {}),
      ...(payload.platform ? { platform: payload.platform as never } : {}),
      ...(payload.scannerMode ? { scannerMode: payload.scannerMode as never } : {}),
      syncProfile,
      status: DeviceStatus.ONLINE,
      isActive: true,
      lastSeenAt: new Date(),
    },
    create: {
      id: deviceId,
      storeId,
      name: typeof payload.deviceName === 'string' ? payload.deviceName : 'POS Device',
      type: payload.deviceType as never,
      platform: payload.platform as never,
      scannerMode: payload.scannerMode as never,
      syncProfile,
      status: DeviceStatus.ONLINE,
      lastSeenAt: new Date(),
    },
  });
}

async function applyTombstones(
  tx: Prisma.TransactionClient,
  storeId: string,
  tombstones: Array<Record<string, unknown>>,
): Promise<number> {
  for (const tombstone of tombstones) {
    const entityType = tombstone.entityType as never;
    const entityId = String(tombstone.entityId);
    await tx.tombstone.upsert({
      where: { id: String(tombstone.id) },
      update: {
        entityType,
        entityId,
        payload: (tombstone.payload as Prisma.JsonObject | undefined) ?? undefined,
        deletedAt: tombstone.deletedAt ? new Date(String(tombstone.deletedAt)) : new Date(),
      },
      create: {
        id: String(tombstone.id),
        storeId,
        entityType,
        entityId,
        payload: (tombstone.payload as Prisma.JsonObject | undefined) ?? undefined,
        deletedAt: tombstone.deletedAt ? new Date(String(tombstone.deletedAt)) : new Date(),
      },
    });

    switch (tombstone.entityType) {
      case 'CATEGORY':
        await tx.category.deleteMany({ where: { id: entityId, storeId } });
        break;
      case 'ITEM':
        await tx.item.updateMany({
          where: { id: entityId, storeId },
          data: { isActive: false },
        });
        break;
      case 'STAFF':
        await tx.staff.updateMany({
          where: { id: entityId, storeId },
          data: { isActive: false },
        });
        break;
      case 'DEVICE':
        await tx.device.updateMany({
          where: { id: entityId, storeId },
          data: { isActive: false, status: DeviceStatus.BLOCKED },
        });
        break;
    }
  }

  return tombstones.length;
}

async function upsertCategories(
  tx: Prisma.TransactionClient,
  storeId: string,
  categories: Array<Record<string, unknown>>,
): Promise<number> {
  for (const category of categories) {
    await tx.category.upsert({
      where: { id: String(category.id) },
      update: {
        name: String(category.name),
        color: Number(category.color) || 0,
        sortOrder: Number(category.sortOrder) || 0,
        updatedAt: category.updatedAt ? new Date(String(category.updatedAt)) : new Date(),
      },
      create: {
        id: String(category.id),
        storeId,
        name: String(category.name),
        color: Number(category.color) || 0,
        sortOrder: Number(category.sortOrder) || 0,
        createdAt: category.createdAt ? new Date(String(category.createdAt)) : new Date(),
        updatedAt: category.updatedAt ? new Date(String(category.updatedAt)) : new Date(),
      },
    });
  }

  return categories.length;
}

async function upsertItems(
  tx: Prisma.TransactionClient,
  storeId: string,
  items: Array<Record<string, unknown>>,
): Promise<number> {
  for (const item of items) {
    await tx.item.upsert({
      where: { id: String(item.id) },
      update: {
        name: String(item.name),
        price: Number(item.price) || 0,
        cost: Number(item.cost) || 0,
        categoryId: nullableString(item.categoryId),
        kitchenStationId: nullableString(item.kitchenStationId),
        barcode: nullableString(item.barcode),
        sku: nullableString(item.sku),
        trackStock: toBool(item.trackStock),
        stockQty: Number(item.stockQuantity) || 0,
        lowStockAt: Number(item.lowStockThreshold) || 5,
        modifiers: (item.modifiers as Prisma.JsonValue | undefined) ?? [],
        isActive: item.isActive !== undefined ? toBool(item.isActive) : true,
        updatedAt: item.updatedAt ? new Date(String(item.updatedAt)) : new Date(),
      },
      create: {
        id: String(item.id),
        storeId,
        name: String(item.name),
        price: Number(item.price) || 0,
        cost: Number(item.cost) || 0,
        categoryId: nullableString(item.categoryId),
        kitchenStationId: nullableString(item.kitchenStationId),
        barcode: nullableString(item.barcode),
        sku: nullableString(item.sku),
        trackStock: toBool(item.trackStock),
        stockQty: Number(item.stockQuantity) || 0,
        lowStockAt: Number(item.lowStockThreshold) || 5,
        modifiers: (item.modifiers as Prisma.JsonValue | undefined) ?? [],
        isActive: item.isActive !== undefined ? toBool(item.isActive) : true,
        createdAt: item.createdAt ? new Date(String(item.createdAt)) : new Date(),
        updatedAt: item.updatedAt ? new Date(String(item.updatedAt)) : new Date(),
      },
    });
  }

  return items.length;
}

async function upsertStaff(
  tx: Prisma.TransactionClient,
  storeId: string,
  staffRows: Array<Record<string, unknown>>,
): Promise<number> {
  for (const member of staffRows) {
    if (!member.id || !member.name || !member.role) {
      continue;
    }

    const existing = await tx.staff.findUnique({ where: { id: String(member.id) } });
    await tx.staff.upsert({
      where: { id: String(member.id) },
      update: {
        name: String(member.name),
        role: member.role as never,
        isActive: member.isActive !== undefined ? toBool(member.isActive) : true,
        ...(member.pinHash ? { pinLocalHash: String(member.pinHash) } : {}),
      },
      create: {
        id: String(member.id),
        storeId,
        name: String(member.name),
        role: member.role as never,
        isActive: member.isActive !== undefined ? toBool(member.isActive) : true,
        pin: existing?.pin ?? '$2a$10$offlinefallbackofflinefallbackoff',
        pinLocalHash: String(member.pinHash ?? existing?.pinLocalHash ?? ''),
        createdAt: member.createdAt ? new Date(String(member.createdAt)) : new Date(),
        updatedAt: member.updatedAt ? new Date(String(member.updatedAt)) : new Date(),
      },
    });
  }
  return staffRows.length;
}

async function upsertSalesSummaries(
  tx: Prisma.TransactionClient,
  storeId: string,
  summaries: Array<Record<string, unknown>>,
): Promise<number> {
  for (const summary of summaries) {
    if (!summary.businessDay) {
      continue;
    }
    await tx.salesSummary.upsert({
      where: {
        storeId_businessDay: {
          storeId,
          businessDay: String(summary.businessDay),
        },
      },
      update: {
        totalOrders: Number(summary.totalOrders) || 0,
        totalSales: Number(summary.totalSales) || 0,
        cashTotal: Number(summary.cashTotal) || 0,
        otherTotal: Number(summary.otherTotal) || 0,
      },
      create: {
        storeId,
        businessDay: String(summary.businessDay),
        totalOrders: Number(summary.totalOrders) || 0,
        totalSales: Number(summary.totalSales) || 0,
        cashTotal: Number(summary.cashTotal) || 0,
        otherTotal: Number(summary.otherTotal) || 0,
      },
    });
  }

  return summaries.length;
}

async function upsertSales(
  tx: Prisma.TransactionClient,
  storeId: string,
  deviceId: string | undefined,
  sales: Array<Record<string, unknown>>,
): Promise<number> {
  for (const sale of sales) {
    await tx.sale.upsert({
      where: { id: String(sale.id) },
      update: {
        receiptNumber: String(sale.receiptNumber),
        subtotal: Number(sale.subtotal) || 0,
        discountAmount: Number(sale.discountAmount) || 0,
        discountPercent: Number(sale.discountPercent) || 0,
        taxAmount: Number(sale.taxAmount) || 0,
        totalAmount: Number(sale.totalAmount) || 0,
        amountPaid: Number(sale.amountPaid) || 0,
        changeAmount: Number(sale.changeAmount) || 0,
        paymentMethod: String(sale.paymentMethod ?? 'cash'),
        status: String(sale.status ?? 'completed'),
        ticketName: nullableString(sale.ticketName),
        deviceId: nullableString(sale.deviceId) ?? deviceId ?? null,
        updatedAt: sale.updatedAt ? new Date(String(sale.updatedAt)) : new Date(),
      },
      create: {
        id: String(sale.id),
        storeId,
        receiptNumber: String(sale.receiptNumber),
        subtotal: Number(sale.subtotal) || 0,
        discountAmount: Number(sale.discountAmount) || 0,
        discountPercent: Number(sale.discountPercent) || 0,
        taxAmount: Number(sale.taxAmount) || 0,
        totalAmount: Number(sale.totalAmount) || 0,
        amountPaid: Number(sale.amountPaid) || 0,
        changeAmount: Number(sale.changeAmount) || 0,
        paymentMethod: String(sale.paymentMethod ?? 'cash'),
        status: String(sale.status ?? 'completed'),
        ticketName: nullableString(sale.ticketName),
        deviceId: nullableString(sale.deviceId) ?? deviceId ?? null,
        createdAt: sale.createdAt ? new Date(String(sale.createdAt)) : new Date(),
        updatedAt: sale.updatedAt ? new Date(String(sale.updatedAt)) : new Date(),
      },
    });
  }
  return sales.length;
}

async function upsertSaleItems(
  tx: Prisma.TransactionClient,
  saleItems: Array<Record<string, unknown>>,
): Promise<number> {
  for (const saleItem of saleItems) {
    await tx.saleItem.upsert({
      where: { id: String(saleItem.id) },
      update: {
        itemName: String(saleItem.itemName),
        quantity: Number(saleItem.quantity) || 0,
        unitPrice: Number(saleItem.unitPrice) || 0,
        totalPrice: Number(saleItem.totalPrice) || 0,
      },
      create: {
        id: String(saleItem.id),
        saleId: String(saleItem.saleId),
        itemId: String(saleItem.itemId),
        itemName: String(saleItem.itemName),
        quantity: Number(saleItem.quantity) || 0,
        unitPrice: Number(saleItem.unitPrice) || 0,
        totalPrice: Number(saleItem.totalPrice) || 0,
      },
    });
  }
  return saleItems.length;
}

async function upsertShifts(
  tx: Prisma.TransactionClient,
  storeId: string,
  shifts: Array<Record<string, unknown>>,
): Promise<number> {
  for (const shift of shifts) {
    await tx.shift.upsert({
      where: { id: String(shift.id) },
      update: {
        openedAt: shift.openedAt ? new Date(String(shift.openedAt)) : new Date(),
        closedAt: shift.closedAt ? new Date(String(shift.closedAt)) : null,
        startingCash: Number(shift.startingCash) || 0,
        cashAdded: Number(shift.cashAdded) || 0,
        cashRemoved: Number(shift.cashRemoved) || 0,
        expectedCash: nullableNumber(shift.expectedCash),
        actualCash: nullableNumber(shift.actualCash),
        difference: nullableNumber(shift.difference),
        status: String(shift.status ?? 'open'),
      },
      create: {
        id: String(shift.id),
        storeId,
        openedAt: shift.openedAt ? new Date(String(shift.openedAt)) : new Date(),
        closedAt: shift.closedAt ? new Date(String(shift.closedAt)) : null,
        startingCash: Number(shift.startingCash) || 0,
        cashAdded: Number(shift.cashAdded) || 0,
        cashRemoved: Number(shift.cashRemoved) || 0,
        expectedCash: nullableNumber(shift.expectedCash),
        actualCash: nullableNumber(shift.actualCash),
        difference: nullableNumber(shift.difference),
        status: String(shift.status ?? 'open'),
      },
    });
  }
  return shifts.length;
}

async function upsertKitchenTickets(
  tx: Prisma.TransactionClient,
  storeId: string,
  deviceId: string | undefined,
  kitchenTickets: Array<Record<string, unknown>>,
): Promise<number> {
  for (const ticket of kitchenTickets) {
    const ticketId = String(ticket.id);
    await tx.kitchenTicket.upsert({
      where: { id: ticketId },
      update: {
        saleId: nullableString(ticket.saleId),
        sourceDeviceId: nullableString(ticket.sourceDeviceId) ?? deviceId ?? null,
        status: (ticket.status as never) ?? 'NEW',
        note: nullableString(ticket.note),
      },
      create: {
        id: ticketId,
        storeId,
        saleId: nullableString(ticket.saleId),
        sourceDeviceId: nullableString(ticket.sourceDeviceId) ?? deviceId ?? null,
        status: (ticket.status as never) ?? 'NEW',
        note: nullableString(ticket.note),
      },
    });

    if (Array.isArray(ticket.items)) {
      await tx.kitchenTicketItem.deleteMany({ where: { ticketId } });
      for (const item of ticket.items as Array<Record<string, unknown>>) {
        await tx.kitchenTicketItem.create({
          data: {
            id: String(item.id ?? `${ticketId}-${item.itemId ?? item.itemName}`),
            ticketId,
            itemId: nullableString(item.itemId),
            stationId: nullableString(item.stationId),
            itemName: String(item.itemName),
            quantity: Number(item.quantity) || 1,
            status: (item.status as never) ?? 'NEW',
            note: nullableString(item.note),
          },
        });
      }
    }
  }

  return kitchenTickets.length;
}

function nullableNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}

async function updateJob(
  jobId: string,
  progress: number,
  status: SyncJobStatus,
  counts?: Record<string, number>,
): Promise<void> {
  const job = await prisma.syncJob.update({
    where: { id: jobId },
    data: {
      progress,
      status,
      ...(counts && { counts }),
      ...(status === SyncJobStatus.SUCCEEDED && { completedAt: new Date() }),
    },
  });

  broadcastToStore(job.storeId, 'sync.job.updated', { job });
  broadcastToAdmins('sync.job.updated', { job });
}

async function failJob(jobId: string, error: unknown): Promise<void> {
  const message = error instanceof Error ? error.message : 'Unknown sync error';
  const job = await prisma.syncJob.update({
    where: { id: jobId },
    data: {
      status: SyncJobStatus.FAILED,
      error: message,
      completedAt: new Date(),
    },
  });

  broadcastToStore(job.storeId, 'sync.job.failed', { job });
  broadcastToAdmins('sync.job.failed', { job });
}
