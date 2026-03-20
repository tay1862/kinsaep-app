import bcrypt from 'bcryptjs';
import { DevicePlatform, DeviceStatus, DeviceType, KitchenStationType, ScannerMode, SyncProfile } from '@prisma/client';

import { prisma } from '../src/lib/prisma';
import { createLocalPinHash } from '../src/utils/pinHash';

async function main() {
  console.log('Seeding database...');

  const adminPassword = await bcrypt.hash('admin123', 12);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@kinsaeppos.com' },
    update: {},
    create: {
      email: 'admin@kinsaeppos.com',
      password: adminPassword,
      name: 'Super Admin',
      role: 'SUPER_ADMIN',
    },
  });

  const ownerPassword = await bcrypt.hash('demo123', 12);
  const owner = await prisma.user.upsert({
    where: { email: 'demo@kinsaeppos.com' },
    update: {},
    create: {
      email: 'demo@kinsaeppos.com',
      password: ownerPassword,
      name: 'Demo Store Owner',
      phone: '+856 20 1234 5678',
      role: 'OWNER',
    },
  });

  const store = await prisma.store.upsert({
    where: { id: 'demo-store-001' },
    update: {},
    create: {
      id: 'demo-store-001',
      name: 'Kinsaep Demo Shop',
      address: 'Vientiane, Laos',
      phone: '+856 20 1234 5678',
      businessType: 'restaurant',
      currency: 'LAK',
      locale: 'lo',
      ownerId: owner.id,
    },
  });

  const validUntil = new Date();
  validUntil.setDate(validUntil.getDate() + 30);

  const offlinePackage = await prisma.packageTemplate.upsert({
    where: { code: 'OFFLINE' },
    update: {
      name: 'Offline',
      maxStaff: 1,
      maxDevices: 1,
      maxKitchenScreens: 0,
      maxStations: 0,
      allowMediaUpload: false,
      maxSyncProfile: SyncProfile.OFF,
      retainRawSalesDays: 0,
      allowRawSalesSync: false,
      isActive: true,
    },
    create: {
      code: 'OFFLINE',
      name: 'Offline',
      description: 'Offline-only POS package',
      maxStaff: 1,
      maxDevices: 1,
      maxKitchenScreens: 0,
      maxStations: 0,
      allowMediaUpload: false,
      maxSyncProfile: SyncProfile.OFF,
      retainRawSalesDays: 0,
      allowRawSalesSync: false,
    },
  });

  const lightPackage = await prisma.packageTemplate.upsert({
    where: { code: 'LIGHT' },
    update: {
      name: 'Light Cloud',
      maxStaff: 5,
      maxDevices: 3,
      maxKitchenScreens: 2,
      maxStations: 3,
      allowMediaUpload: true,
      maxSyncProfile: SyncProfile.LIGHT,
      retainRawSalesDays: 0,
      allowRawSalesSync: false,
      isActive: true,
    },
    create: {
      code: 'LIGHT',
      name: 'Light Cloud',
      description: 'Catalog, staff, kitchen, media thumbnails, and sales summary sync',
      maxStaff: 5,
      maxDevices: 3,
      maxKitchenScreens: 2,
      maxStations: 3,
      allowMediaUpload: true,
      maxSyncProfile: SyncProfile.LIGHT,
      retainRawSalesDays: 0,
      allowRawSalesSync: false,
    },
  });

  await prisma.packageTemplate.upsert({
    where: { code: 'FULL' },
    update: {
      name: 'Full Cloud',
      maxStaff: 15,
      maxDevices: 8,
      maxKitchenScreens: 4,
      maxStations: 3,
      allowMediaUpload: true,
      maxSyncProfile: SyncProfile.FULL,
      retainRawSalesDays: 90,
      allowRawSalesSync: true,
      isActive: true,
    },
    create: {
      code: 'FULL',
      name: 'Full Cloud',
      description: 'Full raw sales sync with kitchen, staff, devices, and media thumbnails',
      maxStaff: 15,
      maxDevices: 8,
      maxKitchenScreens: 4,
      maxStations: 3,
      allowMediaUpload: true,
      maxSyncProfile: SyncProfile.FULL,
      retainRawSalesDays: 90,
      allowRawSalesSync: true,
    },
  });

  await prisma.subscription.upsert({
    where: { storeId: store.id },
    update: {
      plan: 'PRO',
      status: 'ACTIVE',
      validUntil,
      trialEndsAt: null,
    },
    create: {
      storeId: store.id,
      plan: 'PRO',
      status: 'ACTIVE',
      validUntil,
    },
  });

  await prisma.storeEntitlement.upsert({
    where: { storeId: store.id },
    update: {
      packageTemplateId: lightPackage.id,
      maxSyncProfile: SyncProfile.LIGHT,
      allowMediaUpload: true,
      allowRawSalesSync: false,
      overrideReason: 'Demo light cloud store',
    },
    create: {
      storeId: store.id,
      packageTemplateId: lightPackage.id,
      maxSyncProfile: SyncProfile.LIGHT,
      allowMediaUpload: true,
      allowRawSalesSync: false,
      overrideReason: 'Demo light cloud store',
    },
  });

  await prisma.staff.upsert({
    where: { id: 'staff-owner-001' },
    update: {},
    create: {
      id: 'staff-owner-001',
      storeId: store.id,
      name: 'Demo Owner',
      pin: await bcrypt.hash('0000', 10),
      pinLocalHash: createLocalPinHash('0000'),
      role: 'OWNER',
    },
  });

  await prisma.staff.upsert({
    where: { id: 'staff-cashier-001' },
    update: {},
    create: {
      id: 'staff-cashier-001',
      storeId: store.id,
      name: 'Cashier 1',
      pin: await bcrypt.hash('1234', 10),
      pinLocalHash: createLocalPinHash('1234'),
      role: 'CASHIER',
    },
  });

  const hotStation = await prisma.kitchenStation.upsert({
    where: { id: 'station-hot-001' },
    update: {
      name: 'Hot Kitchen',
      type: KitchenStationType.HOT,
      isActive: true,
    },
    create: {
      id: 'station-hot-001',
      storeId: store.id,
      name: 'Hot Kitchen',
      type: KitchenStationType.HOT,
    },
  });

  const drinkStation = await prisma.kitchenStation.upsert({
    where: { id: 'station-drink-001' },
    update: {
      name: 'Drink Bar',
      type: KitchenStationType.DRINK,
      isActive: true,
    },
    create: {
      id: 'station-drink-001',
      storeId: store.id,
      name: 'Drink Bar',
      type: KitchenStationType.DRINK,
    },
  });

  await prisma.item.upsert({
    where: { id: 'item-fried-rice-001' },
    update: {
      name: 'Fried Rice',
      price: 35000,
      cost: 16000,
      barcode: '885000001',
      sku: 'FRIED-RICE',
      kitchenStationId: hotStation.id,
    },
    create: {
      id: 'item-fried-rice-001',
      storeId: store.id,
      name: 'Fried Rice',
      price: 35000,
      cost: 16000,
      barcode: '885000001',
      sku: 'FRIED-RICE',
      kitchenStationId: hotStation.id,
    },
  });

  await prisma.item.upsert({
    where: { id: 'item-iced-tea-001' },
    update: {
      name: 'Iced Tea',
      price: 18000,
      cost: 6000,
      barcode: '885000002',
      sku: 'ICED-TEA',
      kitchenStationId: drinkStation.id,
    },
    create: {
      id: 'item-iced-tea-001',
      storeId: store.id,
      name: 'Iced Tea',
      price: 18000,
      cost: 6000,
      barcode: '885000002',
      sku: 'ICED-TEA',
      kitchenStationId: drinkStation.id,
    },
  });

  const posDevice = await prisma.device.upsert({
    where: { id: 'device-pos-001' },
    update: {
      name: 'Front POS',
      type: DeviceType.POS,
      platform: DevicePlatform.ANDROID,
      scannerMode: ScannerMode.HID,
      syncProfile: SyncProfile.LIGHT,
      status: DeviceStatus.ONLINE,
      isActive: true,
      lastSeenAt: new Date(),
    },
    create: {
      id: 'device-pos-001',
      storeId: store.id,
      name: 'Front POS',
      type: DeviceType.POS,
      platform: DevicePlatform.ANDROID,
      scannerMode: ScannerMode.HID,
      syncProfile: SyncProfile.LIGHT,
      status: DeviceStatus.ONLINE,
      lastSeenAt: new Date(),
    },
  });

  const kitchenDevice = await prisma.device.upsert({
    where: { id: 'device-kitchen-001' },
    update: {
      name: 'Kitchen Screen',
      type: DeviceType.KITCHEN,
      platform: DevicePlatform.ANDROID,
      scannerMode: ScannerMode.AUTO,
      syncProfile: SyncProfile.LIGHT,
      status: DeviceStatus.ONLINE,
      isActive: true,
      lastSeenAt: new Date(),
    },
    create: {
      id: 'device-kitchen-001',
      storeId: store.id,
      name: 'Kitchen Screen',
      type: DeviceType.KITCHEN,
      platform: DevicePlatform.ANDROID,
      scannerMode: ScannerMode.AUTO,
      syncProfile: SyncProfile.LIGHT,
      status: DeviceStatus.ONLINE,
      lastSeenAt: new Date(),
    },
  });

  await prisma.kitchenScreen.upsert({
    where: { id: 'kitchen-screen-001' },
    update: {
      stationId: hotStation.id,
      deviceId: kitchenDevice.id,
      label: 'Hot Kitchen Screen',
      isActive: true,
    },
    create: {
      id: 'kitchen-screen-001',
      storeId: store.id,
      stationId: hotStation.id,
      deviceId: kitchenDevice.id,
      label: 'Hot Kitchen Screen',
    },
  });

  await prisma.syncJob.create({
    data: {
      storeId: store.id,
      deviceId: posDevice.id,
      direction: 'FULL_SYNC',
      syncProfile: SyncProfile.LIGHT,
      status: 'SUCCEEDED',
      progress: 100,
      scopes: {
        store: true,
        catalog: true,
        staff: true,
        devices: true,
        kitchen: true,
        media: true,
        summary: true,
        rawSales: false,
        tombstones: true,
      },
      counts: {
        categories: 0,
        items: 2,
        staff: 2,
        devices: 2,
        kitchenScreens: 1,
      },
      completedAt: new Date(),
    },
  });

  console.log('Super Admin:', admin.email, '/ admin123');
  console.log('Store Owner:', owner.email, '/ demo123');
  console.log('Owner PIN: 0000');
  console.log('Cashier PIN: 1234');
  console.log('Packages seeded:', offlinePackage.code, lightPackage.code, 'FULL');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
