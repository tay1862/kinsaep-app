import bcrypt from 'bcryptjs';

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

  console.log('Super Admin:', admin.email, '/ admin123');
  console.log('Store Owner:', owner.email, '/ demo123');
  console.log('Owner PIN: 0000');
  console.log('Cashier PIN: 1234');
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
