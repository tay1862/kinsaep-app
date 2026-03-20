'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type CategoryRecord = { id: string; name: string; color: number };
type StationRecord = { id: string; name: string; type: string };
type ItemRecord = {
  id: string;
  name: string;
  price: number;
  sku: string | null;
  barcode: string | null;
  categoryId: string | null;
  kitchenStationId: string | null;
  imageUrl: string | null;
};

export default function StoreCatalogPage() {
  const [categories, setCategories] = useState<CategoryRecord[]>([]);
  const [stations, setStations] = useState<StationRecord[]>([]);
  const [items, setItems] = useState<ItemRecord[]>([]);
  const [categoryName, setCategoryName] = useState('');
  const [itemForm, setItemForm] = useState({
    name: '',
    price: 0,
    sku: '',
    barcode: '',
    categoryId: '',
    kitchenStationId: '',
  });

  async function load() {
    const [categoryRows, stationRows, itemRows] = await Promise.all([
      fetchApi<CategoryRecord[]>('/catalog/categories'),
      fetchApi<StationRecord[]>('/kitchen/stations'),
      fetchApi<ItemRecord[]>('/catalog/items'),
    ]);
    setCategories(categoryRows);
    setStations(stationRows);
    setItems(itemRows);
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void load();
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  async function createCategory() {
    await fetchApi('/catalog/categories', {
      method: 'POST',
      body: JSON.stringify({ name: categoryName }),
    });
    setCategoryName('');
    await load();
  }

  async function createItem() {
    await fetchApi('/catalog/items', {
      method: 'POST',
      body: JSON.stringify({
        ...itemForm,
        price: Number(itemForm.price) || 0,
        categoryId: itemForm.categoryId || null,
        kitchenStationId: itemForm.kitchenStationId || null,
      }),
    });
    setItemForm({
      name: '',
      price: 0,
      sku: '',
      barcode: '',
      categoryId: '',
      kitchenStationId: '',
    });
    await load();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">Catalog</h1>
        <p className="text-gray-500 mt-1">
          Manage categories, items, barcodes, SKU codes, and kitchen station routing.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_420px_minmax(0,1fr)] gap-6">
        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Add Category</h2>
          <input
            value={categoryName}
            onChange={(event) => setCategoryName(event.target.value)}
            placeholder="Category name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <button
            onClick={() => void createCategory()}
            disabled={!categoryName}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            Add Category
          </button>
          <div className="space-y-2">
            {categories.map((category) => (
              <div key={category.id} className="rounded-xl border border-gray-100 bg-white px-4 py-3">
                {category.name}
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Add Item</h2>
          <input
            value={itemForm.name}
            onChange={(event) => setItemForm((prev) => ({ ...prev, name: event.target.value }))}
            placeholder="Item name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            type="number"
            value={itemForm.price}
            onChange={(event) => setItemForm((prev) => ({ ...prev, price: Number(event.target.value) || 0 }))}
            placeholder="Price"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            value={itemForm.sku}
            onChange={(event) => setItemForm((prev) => ({ ...prev, sku: event.target.value }))}
            placeholder="SKU"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            value={itemForm.barcode}
            onChange={(event) => setItemForm((prev) => ({ ...prev, barcode: event.target.value }))}
            placeholder="Barcode"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <select
            value={itemForm.categoryId}
            onChange={(event) => setItemForm((prev) => ({ ...prev, categoryId: event.target.value }))}
            className="w-full rounded-xl border border-gray-200 px-4 py-3 bg-white outline-none"
          >
            <option value="">No category</option>
            {categories.map((category) => (
              <option key={category.id} value={category.id}>
                {category.name}
              </option>
            ))}
          </select>
          <select
            value={itemForm.kitchenStationId}
            onChange={(event) =>
              setItemForm((prev) => ({ ...prev, kitchenStationId: event.target.value }))
            }
            className="w-full rounded-xl border border-gray-200 px-4 py-3 bg-white outline-none"
          >
            <option value="">No station</option>
            {stations.map((station) => (
              <option key={station.id} value={station.id}>
                {station.name} ({station.type})
              </option>
            ))}
          </select>
          <button
            onClick={() => void createItem()}
            disabled={!itemForm.name}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            Add Item
          </button>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Items</h2>
          <div className="space-y-3">
            {items.map((item) => (
              <div key={item.id} className="rounded-2xl border border-gray-100 bg-white p-4">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="font-semibold text-[#1E1E2C]">{item.name}</p>
                    <p className="text-sm text-gray-500">
                      SKU {item.sku || '-'} · Barcode {item.barcode || '-'}
                    </p>
                  </div>
                  <p className="font-semibold text-[#1E1E2C]">{item.price}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
