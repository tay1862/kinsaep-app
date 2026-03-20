import { Router, Response } from 'express';
import {
  SubscriptionStatus,
  SyncProfile,
} from '@prisma/client';

import { prisma } from '../lib/prisma';
import {
  createEntitlementSummary,
  getAccessMode,
  getEffectiveEntitlement,
} from '../lib/storeAccess';
import { AuthRequest, requireAdmin } from '../middleware/auth';

export const adminRouter = Router();

adminRouter.use(requireAdmin);

adminRouter.get('/dashboard', async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const [stores, totalUsers, recentActivity, activeSyncJobs, packages] =
      await Promise.all([
        prisma.store.findMany({
          include: { subscription: true, entitlement: { include: { packageTemplate: true } } },
        }),
        prisma.user.count(),
        prisma.activityLog.findMany({
          orderBy: { createdAt: 'desc' },
          take: 20,
          include: {
            user: { select: { name: true, email: true } },
            store: { select: { name: true } },
          },
        }),
        prisma.syncJob.count({ where: { status: 'RUNNING' } }),
        prisma.packageTemplate.findMany({
          orderBy: { name: 'asc' },
          select: { id: true, code: true, name: true, isActive: true },
        }),
      ]);

    const statusBreakdown = stores.reduce<Record<string, number>>((acc, store) => {
      const accessMode = getAccessMode(store.subscription);
      acc[accessMode] = (acc[accessMode] ?? 0) + 1;
      return acc;
    }, {});

    res.json({
      totalStores: stores.length,
      activeStores: statusBreakdown.ACTIVE ?? 0,
      totalUsers,
      activeSyncJobs,
      statusBreakdown,
      packages,
      recentActivity,
    });
  } catch (error) {
    console.error('Admin dashboard error:', error);
    res.status(500).json({ error: 'Failed to load dashboard.' });
  }
});

adminRouter.get('/packages', async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const packages = await prisma.packageTemplate.findMany({
      include: { _count: { select: { entitlements: true } } },
      orderBy: { name: 'asc' },
    });
    res.json({
      packages: packages.map((pkg) => ({
        ...pkg,
        assignedStores: pkg._count.entitlements,
      })),
    });
  } catch {
    res.status(500).json({ error: 'Failed to load packages.' });
  }
});

adminRouter.post('/packages', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const {
      code,
      name,
      description,
      maxStaff,
      maxDevices,
      maxKitchenScreens,
      maxStations,
      allowMediaUpload,
      maxSyncProfile,
      retainRawSalesDays,
      allowRawSalesSync,
    } = req.body;

    if (!code || !name) {
      res.status(400).json({ error: 'Package code and name are required.' });
      return;
    }

    const created = await prisma.packageTemplate.create({
      data: {
        code,
        name,
        description: description || null,
        maxStaff: Number(maxStaff) || 1,
        maxDevices: Number(maxDevices) || 1,
        maxKitchenScreens: Number(maxKitchenScreens) || 0,
        maxStations: Number(maxStations) || 0,
        allowMediaUpload: Boolean(allowMediaUpload),
        maxSyncProfile:
          maxSyncProfile === SyncProfile.FULL
            ? SyncProfile.FULL
            : maxSyncProfile === SyncProfile.LIGHT
              ? SyncProfile.LIGHT
              : SyncProfile.OFF,
        retainRawSalesDays: Number(retainRawSalesDays) || 0,
        allowRawSalesSync: Boolean(allowRawSalesSync),
      },
    });

    res.status(201).json(created);
  } catch {
    res.status(500).json({ error: 'Failed to create package.' });
  }
});

adminRouter.patch('/packages/:packageId', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { packageId } = req.params;
    const updated = await prisma.packageTemplate.update({
      where: { id: packageId },
      data: {
        ...(req.body.code && { code: req.body.code }),
        ...(req.body.name && { name: req.body.name }),
        ...(req.body.description !== undefined && {
          description: req.body.description || null,
        }),
        ...(req.body.maxStaff !== undefined && {
          maxStaff: Number(req.body.maxStaff) || 1,
        }),
        ...(req.body.maxDevices !== undefined && {
          maxDevices: Number(req.body.maxDevices) || 1,
        }),
        ...(req.body.maxKitchenScreens !== undefined && {
          maxKitchenScreens: Number(req.body.maxKitchenScreens) || 0,
        }),
        ...(req.body.maxStations !== undefined && {
          maxStations: Number(req.body.maxStations) || 0,
        }),
        ...(req.body.allowMediaUpload !== undefined && {
          allowMediaUpload: Boolean(req.body.allowMediaUpload),
        }),
        ...(req.body.maxSyncProfile && {
          maxSyncProfile: req.body.maxSyncProfile,
        }),
        ...(req.body.retainRawSalesDays !== undefined && {
          retainRawSalesDays: Number(req.body.retainRawSalesDays) || 0,
        }),
        ...(req.body.allowRawSalesSync !== undefined && {
          allowRawSalesSync: Boolean(req.body.allowRawSalesSync),
        }),
        ...(req.body.isActive !== undefined && {
          isActive: Boolean(req.body.isActive),
        }),
      },
    });
    res.json(updated);
  } catch {
    res.status(500).json({ error: 'Failed to update package.' });
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
          entitlement: { include: { packageTemplate: true } },
          _count: {
            select: {
              sales: true,
              items: true,
              staff: true,
              devices: true,
              kitchenScreens: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
      }),
      prisma.store.count(),
    ]);

    const enriched = await Promise.all(
      stores.map(async (store) => {
        const entitlement = await getEffectiveEntitlement(store.id);
        return {
          id: store.id,
          name: store.name,
          owner: store.owner,
          subscription: store.subscription,
          accessMode: entitlement.accessMode,
          entitlement: createEntitlementSummary(entitlement),
          packageTemplate: store.entitlement?.packageTemplate
            ? {
                id: store.entitlement.packageTemplate.id,
                code: store.entitlement.packageTemplate.code,
                name: store.entitlement.packageTemplate.name,
              }
            : null,
          counts: {
            sales: store._count.sales,
            items: store._count.items,
            staff: store._count.staff,
            devices: store._count.devices,
            kitchenScreens: store._count.kitchenScreens,
          },
        };
      }),
    );

    res.json({
      stores: enriched,
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
        entitlement: { include: { packageTemplate: true } },
        staff: {
          select: { id: true, name: true, role: true, isActive: true, createdAt: true },
        },
        devices: true,
        kitchenStations: true,
        kitchenScreens: { include: { station: true, device: true } },
        syncJobs: { orderBy: { createdAt: 'desc' }, take: 20 },
        _count: {
          select: {
            sales: true,
            items: true,
            categories: true,
            shifts: true,
            devices: true,
            kitchenScreens: true,
          },
        },
      },
    });

    if (!store) {
      res.status(404).json({ error: 'Store not found.' });
      return;
    }

    const entitlement = await getEffectiveEntitlement(store.id);

    res.json({
      ...store,
      accessMode: entitlement.accessMode,
      entitlement: createEntitlementSummary(entitlement),
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
        status === SubscriptionStatus.ACTIVE
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
          action:
            status === SubscriptionStatus.BLOCKED
              ? 'ADMIN_BLOCK_STORE'
              : 'ADMIN_UPDATE_SUBSCRIPTION',
          details: {
            oldStatus: subscription.status,
            newStatus: status,
            plan,
            validUntil: nextValidUntil,
          },
        },
      });

      const entitlement = await getEffectiveEntitlement(storeId);

      res.json({
        message: 'Subscription updated.',
        subscription: updated,
        accessMode: entitlement.accessMode,
        entitlement: createEntitlementSummary(entitlement),
      });
    } catch {
      res.status(500).json({ error: 'Failed to update subscription.' });
    }
  },
);

adminRouter.patch(
  '/stores/:storeId/entitlements',
  async (req: AuthRequest, res: Response): Promise<void> => {
    try {
      const { storeId } = req.params;
      const {
        packageTemplateId,
        maxStaff,
        maxDevices,
        maxKitchenScreens,
        maxStations,
        allowMediaUpload,
        maxSyncProfile,
        retainRawSalesDays,
        allowRawSalesSync,
        overrideReason,
      } = req.body;

      const updated = await prisma.storeEntitlement.upsert({
        where: { storeId },
        update: {
          ...(packageTemplateId !== undefined && { packageTemplateId }),
          ...(maxStaff !== undefined && { maxStaff: Number(maxStaff) }),
          ...(maxDevices !== undefined && { maxDevices: Number(maxDevices) }),
          ...(maxKitchenScreens !== undefined && {
            maxKitchenScreens: Number(maxKitchenScreens),
          }),
          ...(maxStations !== undefined && { maxStations: Number(maxStations) }),
          ...(allowMediaUpload !== undefined && {
            allowMediaUpload: Boolean(allowMediaUpload),
          }),
          ...(maxSyncProfile && { maxSyncProfile }),
          ...(retainRawSalesDays !== undefined && {
            retainRawSalesDays: Number(retainRawSalesDays),
          }),
          ...(allowRawSalesSync !== undefined && {
            allowRawSalesSync: Boolean(allowRawSalesSync),
          }),
          ...(overrideReason !== undefined && { overrideReason }),
        },
        create: {
          storeId,
          packageTemplateId: packageTemplateId || null,
          maxStaff: maxStaff !== undefined ? Number(maxStaff) : null,
          maxDevices: maxDevices !== undefined ? Number(maxDevices) : null,
          maxKitchenScreens:
            maxKitchenScreens !== undefined ? Number(maxKitchenScreens) : null,
          maxStations: maxStations !== undefined ? Number(maxStations) : null,
          allowMediaUpload:
            allowMediaUpload !== undefined ? Boolean(allowMediaUpload) : null,
          maxSyncProfile: maxSyncProfile || null,
          retainRawSalesDays:
            retainRawSalesDays !== undefined ? Number(retainRawSalesDays) : null,
          allowRawSalesSync: Boolean(allowRawSalesSync),
          overrideReason: overrideReason || null,
        },
        include: { packageTemplate: true },
      });

      const entitlement = await getEffectiveEntitlement(storeId);

      await prisma.activityLog.create({
        data: {
          userId: req.userId,
          storeId,
          action: 'ADMIN_UPDATE_ENTITLEMENT',
          details: {
            entitlementId: updated.id,
            packageTemplateId: updated.packageTemplateId,
            entitlement: createEntitlementSummary(entitlement),
          },
        },
      });

      res.json({
        entitlement: updated,
        effective: createEntitlementSummary(entitlement),
      });
    } catch {
      res.status(500).json({ error: 'Failed to update entitlement.' });
    }
  },
);

adminRouter.get('/health/devices-sync', async (_req: AuthRequest, res: Response): Promise<void> => {
  try {
    const [devices, syncJobs] = await Promise.all([
      prisma.device.findMany({
        orderBy: [{ storeId: 'asc' }, { updatedAt: 'desc' }],
        include: { store: { select: { name: true } } },
      }),
      prisma.syncJob.findMany({
        orderBy: { createdAt: 'desc' },
        take: 100,
        include: {
          store: { select: { name: true } },
          device: { select: { name: true, type: true } },
        },
      }),
    ]);

    res.json({ devices, syncJobs });
  } catch {
    res.status(500).json({ error: 'Failed to load device and sync health.' });
  }
});

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
