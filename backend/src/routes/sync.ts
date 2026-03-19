import { Router, Response } from 'express';

import { prisma } from '../lib/prisma';
import { AuthRequest } from '../middleware/auth';

export const syncRouter = Router();

syncRouter.post('/push', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'Store ID not found in token.' });
      return;
    }

    const subscriptionStatus = await ensureActiveSubscription(storeId);
    if (subscriptionStatus !== 'ACTIVE') {
      res.status(403).json({
        error: 'Subscription inactive. Cloud sync is disabled.',
        subscriptionStatus,
      });
      return;
    }

    const { store, categories, items, sales, saleItems, shifts } = req.body;

    await prisma.$transaction(async (tx) => {
      if (store) {
        await tx.store.update({
          where: { id: storeId },
          data: {
            ...(store.name && { name: store.name }),
            ...(store.address !== undefined && { address: store.address || null }),
            ...(store.phone !== undefined && { phone: store.phone || null }),
            ...(store.businessType && { businessType: store.businessType }),
            ...(store.currency && { currency: store.currency }),
            ...(store.locale && { locale: store.locale }),
            ...(store.taxEnabled !== undefined && {
              taxEnabled: Boolean(store.taxEnabled),
            }),
            ...(store.taxRate !== undefined && { taxRate: Number(store.taxRate) || 0 }),
            ...(store.receiptHeader !== undefined && {
              receiptHeader: store.receiptHeader || null,
            }),
            ...(store.receiptFooter !== undefined && {
              receiptFooter: store.receiptFooter || null,
            }),
          },
        });
      }

      if (categories?.length) {
        for (const category of categories) {
          await tx.category.upsert({
            where: { id: category.id },
            update: {
              name: category.name,
              color: Number(category.color) || 0,
              sortOrder: Number(category.sortOrder) || 0,
              updatedAt: new Date(),
            },
            create: {
              id: category.id,
              storeId,
              name: category.name,
              color: Number(category.color) || 0,
              sortOrder: Number(category.sortOrder) || 0,
            },
          });
        }
      }

      if (items?.length) {
        for (const item of items) {
          await tx.item.upsert({
            where: { id: item.id },
            update: {
              name: item.name,
              price: Number(item.price) || 0,
              cost: Number(item.cost) || 0,
              barcode: item.barcode || null,
              trackStock: toBool(item.trackStock),
              stockQty: Number(item.stockQuantity) || 0,
              lowStockAt: Number(item.lowStockThreshold) || 5,
              modifiers: item.modifiers || [],
              categoryId: item.categoryId || null,
              isActive: toBool(item.isActive ?? true),
              updatedAt: new Date(),
            },
            create: {
              id: item.id,
              storeId,
              name: item.name,
              price: Number(item.price) || 0,
              cost: Number(item.cost) || 0,
              barcode: item.barcode || null,
              trackStock: toBool(item.trackStock),
              stockQty: Number(item.stockQuantity) || 0,
              lowStockAt: Number(item.lowStockThreshold) || 5,
              modifiers: item.modifiers || [],
              categoryId: item.categoryId || null,
              isActive: toBool(item.isActive ?? true),
            },
          });
        }
      }

      if (sales?.length) {
        for (const sale of sales) {
          await tx.sale.upsert({
            where: { id: sale.id },
            update: {
              receiptNumber: sale.receiptNumber,
              subtotal: Number(sale.subtotal) || 0,
              discountAmount: Number(sale.discountAmount) || 0,
              discountPercent: Number(sale.discountPercent) || 0,
              taxAmount: Number(sale.taxAmount) || 0,
              totalAmount: Number(sale.totalAmount) || 0,
              amountPaid: Number(sale.amountPaid) || 0,
              changeAmount: Number(sale.changeAmount) || 0,
              paymentMethod: sale.paymentMethod,
              status: sale.status,
              ticketName: sale.ticketName || null,
              updatedAt: sale.updatedAt ? new Date(sale.updatedAt) : new Date(),
            },
            create: {
              id: sale.id,
              storeId,
              receiptNumber: sale.receiptNumber,
              subtotal: Number(sale.subtotal) || 0,
              discountAmount: Number(sale.discountAmount) || 0,
              discountPercent: Number(sale.discountPercent) || 0,
              taxAmount: Number(sale.taxAmount) || 0,
              totalAmount: Number(sale.totalAmount) || 0,
              amountPaid: Number(sale.amountPaid) || 0,
              changeAmount: Number(sale.changeAmount) || 0,
              paymentMethod: sale.paymentMethod,
              status: sale.status,
              ticketName: sale.ticketName || null,
              createdAt: sale.createdAt ? new Date(sale.createdAt) : new Date(),
            },
          });
        }
      }

      if (saleItems?.length) {
        for (const saleItem of saleItems) {
          await tx.saleItem.upsert({
            where: { id: saleItem.id },
            update: {
              quantity: Number(saleItem.quantity) || 0,
              unitPrice: Number(saleItem.unitPrice) || 0,
              totalPrice: Number(saleItem.totalPrice) || 0,
              itemName: saleItem.itemName,
            },
            create: {
              id: saleItem.id,
              saleId: saleItem.saleId,
              itemId: saleItem.itemId,
              itemName: saleItem.itemName,
              quantity: Number(saleItem.quantity) || 0,
              unitPrice: Number(saleItem.unitPrice) || 0,
              totalPrice: Number(saleItem.totalPrice) || 0,
            },
          });
        }
      }

      if (shifts?.length) {
        for (const shift of shifts) {
          await tx.shift.upsert({
            where: { id: shift.id },
            update: {
              openedAt: shift.openedAt ? new Date(shift.openedAt) : new Date(),
              closedAt: shift.closedAt ? new Date(shift.closedAt) : null,
              startingCash: Number(shift.startingCash) || 0,
              cashAdded: Number(shift.cashAdded) || 0,
              cashRemoved: Number(shift.cashRemoved) || 0,
              expectedCash: toNullableNumber(shift.expectedCash),
              actualCash: toNullableNumber(shift.actualCash),
              difference: toNullableNumber(shift.difference),
              status: shift.status,
            },
            create: {
              id: shift.id,
              storeId,
              openedAt: shift.openedAt ? new Date(shift.openedAt) : new Date(),
              closedAt: shift.closedAt ? new Date(shift.closedAt) : null,
              startingCash: Number(shift.startingCash) || 0,
              cashAdded: Number(shift.cashAdded) || 0,
              cashRemoved: Number(shift.cashRemoved) || 0,
              expectedCash: toNullableNumber(shift.expectedCash),
              actualCash: toNullableNumber(shift.actualCash),
              difference: toNullableNumber(shift.difference),
              status: shift.status,
            },
          });
        }
      }
    });

    await prisma.activityLog.create({
      data: {
        userId: req.userId,
        storeId,
        action: 'SYNC_PUSH',
        details: {
          categories: categories?.length || 0,
          items: items?.length || 0,
          sales: sales?.length || 0,
          saleItems: saleItems?.length || 0,
          shifts: shifts?.length || 0,
        },
      },
    });

    res.json({
      message: 'Sync push successful',
      serverTime: new Date().toISOString(),
    });
  } catch (error) {
    console.error('Sync push error:', error);
    res.status(500).json({ error: 'Sync push failed.' });
  }
});

syncRouter.get('/pull', async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const storeId = req.storeId;
    if (!storeId) {
      res.status(400).json({ error: 'Store ID not found.' });
      return;
    }

    const subscriptionStatus = await ensureActiveSubscription(storeId);
    if (subscriptionStatus !== 'ACTIVE') {
      res.status(403).json({
        error: 'Subscription inactive.',
        subscriptionStatus,
      });
      return;
    }

    const since = req.query.since as string | undefined;
    const sinceDate = since ? new Date(since) : new Date(0);

    const [store, categories, items, staff, sales, shifts] = await Promise.all([
      prisma.store.findUnique({
        where: { id: storeId },
        include: { subscription: true },
      }),
      prisma.category.findMany({
        where: { storeId, updatedAt: { gte: sinceDate } },
      }),
      prisma.item.findMany({
        where: { storeId, updatedAt: { gte: sinceDate } },
      }),
      prisma.staff.findMany({
        where: { storeId, isActive: true },
        orderBy: { createdAt: 'asc' },
      }),
      prisma.sale.findMany({
        where: { storeId, updatedAt: { gte: sinceDate } },
        orderBy: { createdAt: 'desc' },
        take: 500,
      }),
      prisma.shift.findMany({
        where: { storeId, openedAt: { gte: sinceDate } },
        orderBy: { openedAt: 'desc' },
        take: 200,
      }),
    ]);

    const saleItems = sales.length
      ? await prisma.saleItem.findMany({
          where: { saleId: { in: sales.map((sale) => sale.id) } },
        })
      : [];

    res.json({
      serverTime: new Date().toISOString(),
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
        barcode: item.barcode,
        trackStock: item.trackStock,
        stockQuantity: item.stockQty,
        lowStockThreshold: item.lowStockAt,
        modifiers: item.modifiers,
        isActive: item.isActive,
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
        createdAt: sale.createdAt.toISOString(),
        updatedAt: sale.updatedAt.toISOString(),
      })),
      saleItems: saleItems.map((saleItem) => ({
        id: saleItem.id,
        saleId: saleItem.saleId,
        itemId: saleItem.itemId,
        itemName: saleItem.itemName,
        quantity: saleItem.quantity,
        unitPrice: saleItem.unitPrice,
        totalPrice: saleItem.totalPrice,
      })),
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
    });
  } catch (error) {
    console.error('Sync pull error:', error);
    res.status(500).json({ error: 'Sync pull failed.' });
  }
});

async function ensureActiveSubscription(storeId: string): Promise<string> {
  const subscription = await prisma.subscription.findUnique({ where: { storeId } });
  if (!subscription) {
    return 'NONE';
  }

  if (subscription.status === 'BLOCKED' || subscription.status === 'CANCELLED') {
    return 'BLOCKED';
  }

  const now = new Date();
  if (subscription.status === 'ACTIVE' && now > subscription.validUntil) {
    await prisma.subscription.update({
      where: { id: subscription.id },
      data: { status: 'EXPIRED' },
    });
    return 'EXPIRED';
  }

  return subscription.status;
}

function toBool(value: unknown): boolean {
  return value === true || value === 1 || value === '1';
}

function toNullableNumber(value: unknown): number | null {
  if (value === null || value === undefined || value == '') {
    return null;
  }
  const parsed = Number(value);
  return Number.isNaN(parsed) ? null : parsed;
}
