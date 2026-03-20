import {
  DeviceStatus,
  Prisma,
  Subscription,
  SubscriptionStatus,
  SyncProfile,
} from '@prisma/client';

import { prisma } from './prisma';

export type AccessMode = 'OFFLINE_ONLY' | 'ACTIVE' | 'BLOCKED' | 'EXPIRED';

export interface EffectiveEntitlement {
  accessMode: AccessMode;
  packageCode: string;
  packageName: string;
  maxStaff: number;
  maxDevices: number;
  maxKitchenScreens: number;
  maxStations: number;
  allowMediaUpload: boolean;
  maxSyncProfile: SyncProfile;
  retainRawSalesDays: number;
  allowRawSalesSync: boolean;
}

export function getAccessMode(subscription: Subscription | null): AccessMode {
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

export function syncProfileRank(profile: SyncProfile): number {
  switch (profile) {
    case SyncProfile.OFF:
      return 0;
    case SyncProfile.LIGHT:
      return 1;
    case SyncProfile.FULL:
      return 2;
  }
}

export async function resolveSubscriptionStatus(
  subscriptionId: string | null,
): Promise<SubscriptionStatus | 'NONE'> {
  if (!subscriptionId) {
    return 'NONE';
  }

  const subscription = await prisma.subscription.findUnique({
    where: { id: subscriptionId },
  });
  if (!subscription) {
    return 'NONE';
  }

  if (
    subscription.status === SubscriptionStatus.BLOCKED ||
    subscription.status === SubscriptionStatus.CANCELLED
  ) {
    return SubscriptionStatus.BLOCKED;
  }

  if (
    subscription.status === SubscriptionStatus.ACTIVE &&
    new Date() > subscription.validUntil
  ) {
    await prisma.subscription.update({
      where: { id: subscription.id },
      data: { status: SubscriptionStatus.EXPIRED },
    });
    return SubscriptionStatus.EXPIRED;
  }

  return subscription.status;
}

export async function getEffectiveEntitlement(
  storeId: string,
): Promise<EffectiveEntitlement> {
  const store = await prisma.store.findUnique({
    where: { id: storeId },
    include: {
      subscription: true,
      entitlement: {
        include: { packageTemplate: true },
      },
    },
  });

  const accessMode = getAccessMode(store?.subscription ?? null);
  const pkg = store?.entitlement?.packageTemplate;
  const fallback = defaultEntitlement(accessMode);

  return {
    accessMode,
    packageCode: pkg?.code ?? fallback.packageCode,
    packageName: pkg?.name ?? fallback.packageName,
    maxStaff: store?.entitlement?.maxStaff ?? pkg?.maxStaff ?? fallback.maxStaff,
    maxDevices:
      store?.entitlement?.maxDevices ?? pkg?.maxDevices ?? fallback.maxDevices,
    maxKitchenScreens:
      store?.entitlement?.maxKitchenScreens ??
      pkg?.maxKitchenScreens ??
      fallback.maxKitchenScreens,
    maxStations:
      store?.entitlement?.maxStations ?? pkg?.maxStations ?? fallback.maxStations,
    allowMediaUpload:
      store?.entitlement?.allowMediaUpload ??
      pkg?.allowMediaUpload ??
      fallback.allowMediaUpload,
    maxSyncProfile:
      store?.entitlement?.maxSyncProfile ??
      pkg?.maxSyncProfile ??
      fallback.maxSyncProfile,
    retainRawSalesDays:
      store?.entitlement?.retainRawSalesDays ??
      pkg?.retainRawSalesDays ??
      fallback.retainRawSalesDays,
    allowRawSalesSync:
      store?.entitlement?.allowRawSalesSync ??
      pkg?.allowRawSalesSync ??
      fallback.allowRawSalesSync,
  };
}

export async function assertStoreLimit(
  storeId: string,
  limit:
    | 'staff'
    | 'devices'
    | 'kitchenScreens'
    | 'stations',
): Promise<void> {
  const entitlement = await getEffectiveEntitlement(storeId);

  const currentCount =
    limit === 'staff'
      ? await prisma.staff.count({ where: { storeId, isActive: true } })
      : limit === 'devices'
        ? await prisma.device.count({
            where: {
              storeId,
              isActive: true,
              status: { not: DeviceStatus.BLOCKED },
            },
          })
        : limit === 'kitchenScreens'
          ? await prisma.kitchenScreen.count({
              where: { storeId, isActive: true },
            })
          : await prisma.kitchenStation.count({
              where: { storeId, isActive: true },
            });

  const maxAllowed =
    limit === 'staff'
      ? entitlement.maxStaff
      : limit === 'devices'
        ? entitlement.maxDevices
        : limit === 'kitchenScreens'
          ? entitlement.maxKitchenScreens
          : entitlement.maxStations;

  if (currentCount >= maxAllowed) {
    throw new StoreLimitError(
      `This store reached its ${limit} limit of ${maxAllowed}.`,
      limit,
      maxAllowed,
      currentCount,
    );
  }
}

export async function assertSyncProfileAllowed(
  storeId: string,
  requested: SyncProfile,
): Promise<EffectiveEntitlement> {
  const entitlement = await getEffectiveEntitlement(storeId);

  if (entitlement.accessMode !== 'ACTIVE') {
    throw new StoreAccessError(
      'Cloud sync is unavailable because this store is not active.',
      entitlement.accessMode,
    );
  }

  if (syncProfileRank(requested) > syncProfileRank(entitlement.maxSyncProfile)) {
    throw new StoreAccessError(
      `This store package allows up to ${entitlement.maxSyncProfile} sync only.`,
      entitlement.accessMode,
    );
  }

  return entitlement;
}

export function normalizeSyncProfile(value: unknown): SyncProfile {
  if (value === SyncProfile.FULL || value === 'FULL') {
    return SyncProfile.FULL;
  }
  if (value === SyncProfile.LIGHT || value === 'LIGHT') {
    return SyncProfile.LIGHT;
  }
  return SyncProfile.OFF;
}

export class StoreLimitError extends Error {
  constructor(
    message: string,
    public readonly limit: string,
    public readonly maxAllowed: number,
    public readonly currentCount: number,
  ) {
    super(message);
  }
}

export class StoreAccessError extends Error {
  constructor(
    message: string,
    public readonly accessMode: AccessMode,
  ) {
    super(message);
  }
}

function defaultEntitlement(accessMode: AccessMode): EffectiveEntitlement {
  if (accessMode === 'ACTIVE') {
    return {
      accessMode,
      packageCode: 'LIGHT-DEFAULT',
      packageName: 'Light Default',
      maxStaff: 3,
      maxDevices: 2,
      maxKitchenScreens: 1,
      maxStations: 3,
      allowMediaUpload: true,
      maxSyncProfile: SyncProfile.LIGHT,
      retainRawSalesDays: 0,
      allowRawSalesSync: false,
    };
  }

  return {
    accessMode,
    packageCode: 'OFFLINE',
    packageName: 'Offline',
    maxStaff: 1,
    maxDevices: 1,
    maxKitchenScreens: 0,
    maxStations: 0,
    allowMediaUpload: false,
    maxSyncProfile: SyncProfile.OFF,
    retainRawSalesDays: 0,
    allowRawSalesSync: false,
  };
}

export function createEntitlementSummary(
  entitlement: EffectiveEntitlement,
): Prisma.JsonObject {
  return {
    accessMode: entitlement.accessMode,
    packageCode: entitlement.packageCode,
    packageName: entitlement.packageName,
    maxStaff: entitlement.maxStaff,
    maxDevices: entitlement.maxDevices,
    maxKitchenScreens: entitlement.maxKitchenScreens,
    maxStations: entitlement.maxStations,
    allowMediaUpload: entitlement.allowMediaUpload,
    maxSyncProfile: entitlement.maxSyncProfile,
    retainRawSalesDays: entitlement.retainRawSalesDays,
    allowRawSalesSync: entitlement.allowRawSalesSync,
  };
}
