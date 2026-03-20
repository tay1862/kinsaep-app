'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type PackageRecord = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  maxStaff: number;
  maxDevices: number;
  maxKitchenScreens: number;
  maxStations: number;
  allowMediaUpload: boolean;
  maxSyncProfile: 'OFF' | 'LIGHT' | 'FULL';
  retainRawSalesDays: number;
  allowRawSalesSync: boolean;
  isActive: boolean;
  assignedStores: number;
};

export default function PackagesPage() {
  const [packages, setPackages] = useState<PackageRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [form, setForm] = useState({
    code: '',
    name: '',
    description: '',
    maxStaff: 1,
    maxDevices: 1,
    maxKitchenScreens: 0,
    maxStations: 0,
    allowMediaUpload: false,
    maxSyncProfile: 'OFF',
    retainRawSalesDays: 0,
    allowRawSalesSync: false,
  });

  useEffect(() => {
    void loadPackages();
  }, []);

  async function loadPackages() {
    setLoading(true);
    try {
      const data = await fetchApi<{ packages: PackageRecord[] }>('/admin/packages');
      setPackages(data.packages);
    } finally {
      setLoading(false);
    }
  }

  async function handleCreate() {
    setSaving(true);
    try {
      await fetchApi('/admin/packages', {
        method: 'POST',
        body: JSON.stringify(form),
      });
      setForm({
        code: '',
        name: '',
        description: '',
        maxStaff: 1,
        maxDevices: 1,
        maxKitchenScreens: 0,
        maxStations: 0,
        allowMediaUpload: false,
        maxSyncProfile: 'OFF',
        retainRawSalesDays: 0,
        allowRawSalesSync: false,
      });
      await loadPackages();
    } finally {
      setSaving(false);
    }
  }

  async function handleToggle(pkg: PackageRecord) {
    await fetchApi(`/admin/packages/${pkg.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive: !pkg.isActive }),
    });
    await loadPackages();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
          Package Templates
        </h1>
        <p className="text-gray-500 mt-1">
          Define store limits, sync profile ceilings, and raw-sales retention.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_minmax(0,1fr)] gap-6">
        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Create Package</h2>
          <input
            value={form.code}
            onChange={(event) => setForm((prev) => ({ ...prev, code: event.target.value }))}
            placeholder="Code"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            value={form.name}
            onChange={(event) => setForm((prev) => ({ ...prev, name: event.target.value }))}
            placeholder="Package name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <textarea
            value={form.description}
            onChange={(event) =>
              setForm((prev) => ({ ...prev, description: event.target.value }))
            }
            placeholder="Description"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none min-h-28"
          />
          <div className="grid grid-cols-2 gap-3">
            <NumberField label="Staff" value={form.maxStaff} onChange={(value) => setForm((prev) => ({ ...prev, maxStaff: value }))} />
            <NumberField label="Devices" value={form.maxDevices} onChange={(value) => setForm((prev) => ({ ...prev, maxDevices: value }))} />
            <NumberField label="Kitchen Screens" value={form.maxKitchenScreens} onChange={(value) => setForm((prev) => ({ ...prev, maxKitchenScreens: value }))} />
            <NumberField label="Stations" value={form.maxStations} onChange={(value) => setForm((prev) => ({ ...prev, maxStations: value }))} />
            <NumberField label="Raw Sales Days" value={form.retainRawSalesDays} onChange={(value) => setForm((prev) => ({ ...prev, retainRawSalesDays: value }))} />
            <label className="text-sm font-semibold text-gray-600">
              Sync Profile
              <select
                value={form.maxSyncProfile}
                onChange={(event) =>
                  setForm((prev) => ({
                    ...prev,
                    maxSyncProfile: event.target.value as 'OFF' | 'LIGHT' | 'FULL',
                  }))
                }
                className="mt-2 w-full rounded-xl border border-gray-200 px-3 py-2 bg-white"
              >
                <option value="OFF">OFF</option>
                <option value="LIGHT">LIGHT</option>
                <option value="FULL">FULL</option>
              </select>
            </label>
          </div>
          <label className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3">
            <span className="text-sm font-semibold text-gray-700">Allow Media Upload</span>
            <input
              type="checkbox"
              checked={form.allowMediaUpload}
              onChange={(event) =>
                setForm((prev) => ({ ...prev, allowMediaUpload: event.target.checked }))
              }
            />
          </label>
          <label className="flex items-center justify-between rounded-xl border border-gray-200 px-4 py-3">
            <span className="text-sm font-semibold text-gray-700">Allow Raw Sales Sync</span>
            <input
              type="checkbox"
              checked={form.allowRawSalesSync}
              onChange={(event) =>
                setForm((prev) => ({ ...prev, allowRawSalesSync: event.target.checked }))
              }
            />
          </label>
          <button
            onClick={() => void handleCreate()}
            disabled={saving || !form.code || !form.name}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            {saving ? 'Saving...' : 'Create Package'}
          </button>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Existing Packages</h2>
          {loading ? (
            <div className="py-10 text-center text-gray-500">Loading packages...</div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {packages.map((pkg) => (
                <div
                  key={pkg.id}
                  className="rounded-2xl border border-gray-100 bg-white p-5"
                >
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <p className="text-xs font-semibold tracking-[0.16em] text-gray-400">
                        {pkg.code}
                      </p>
                      <h3 className="mt-2 text-xl font-bold text-[#1E1E2C]">{pkg.name}</h3>
                    </div>
                    <button
                      onClick={() => void handleToggle(pkg)}
                      className={`rounded-full px-3 py-1 text-xs font-semibold ${
                        pkg.isActive
                          ? 'bg-green-50 text-green-700'
                          : 'bg-gray-100 text-gray-500'
                      }`}
                    >
                      {pkg.isActive ? 'ACTIVE' : 'INACTIVE'}
                    </button>
                  </div>
                  <p className="mt-3 text-sm text-gray-500">
                    {pkg.description || 'No description'}
                  </p>
                  <div className="mt-4 grid grid-cols-2 gap-3 text-sm text-gray-600">
                    <div>Staff: {pkg.maxStaff}</div>
                    <div>Devices: {pkg.maxDevices}</div>
                    <div>Screens: {pkg.maxKitchenScreens}</div>
                    <div>Stations: {pkg.maxStations}</div>
                    <div>Sync: {pkg.maxSyncProfile}</div>
                    <div>Assigned: {pkg.assignedStores}</div>
                    <div>Media: {pkg.allowMediaUpload ? 'Yes' : 'No'}</div>
                    <div>Raw Sales: {pkg.allowRawSalesSync ? 'Yes' : 'No'}</div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function NumberField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="text-sm font-semibold text-gray-600">
      {label}
      <input
        type="number"
        value={value}
        onChange={(event) => onChange(Number(event.target.value) || 0)}
        className="mt-2 w-full rounded-xl border border-gray-200 px-3 py-2 outline-none"
      />
    </label>
  );
}
