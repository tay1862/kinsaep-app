'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type DeviceRecord = {
  id: string;
  name: string;
  type: 'POS' | 'KITCHEN' | 'MANAGER';
  platform: 'ANDROID' | 'IOS' | 'WEB';
  scannerMode: 'AUTO' | 'CAMERA' | 'HID' | 'SUNMI' | 'ZEBRA';
  syncProfile: 'OFF' | 'LIGHT' | 'FULL';
  status: string;
  isActive: boolean;
};

export default function StoreDevicesPage() {
  const [devices, setDevices] = useState<DeviceRecord[]>([]);
  const [form, setForm] = useState({
    id: '',
    name: '',
    type: 'POS' as DeviceRecord['type'],
    platform: 'ANDROID' as DeviceRecord['platform'],
    scannerMode: 'AUTO' as DeviceRecord['scannerMode'],
    syncProfile: 'LIGHT' as DeviceRecord['syncProfile'],
  });

  async function loadDevices() {
    const data = await fetchApi<DeviceRecord[]>('/devices');
    setDevices(data);
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadDevices();
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  async function createDevice() {
    await fetchApi('/devices', {
      method: 'POST',
      body: JSON.stringify(form),
    });
    setForm({
      id: '',
      name: '',
      type: 'POS',
      platform: 'ANDROID',
      scannerMode: 'AUTO',
      syncProfile: 'LIGHT',
    });
    await loadDevices();
  }

  async function toggleDevice(device: DeviceRecord) {
    await fetchApi(`/devices/${device.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive: !device.isActive }),
    });
    await loadDevices();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">Devices</h1>
        <p className="text-gray-500 mt-1">
          Register POS, kitchen, and manager devices with scanner and sync profiles.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[380px_minmax(0,1fr)] gap-6">
        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Register Device</h2>
          <input
            value={form.id}
            onChange={(event) => setForm((prev) => ({ ...prev, id: event.target.value }))}
            placeholder="Device ID"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            value={form.name}
            onChange={(event) => setForm((prev) => ({ ...prev, name: event.target.value }))}
            placeholder="Device name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <Select
            label="Type"
            value={form.type}
            options={['POS', 'KITCHEN', 'MANAGER']}
            onChange={(value) => setForm((prev) => ({ ...prev, type: value as DeviceRecord['type'] }))}
          />
          <Select
            label="Platform"
            value={form.platform}
            options={['ANDROID', 'IOS', 'WEB']}
            onChange={(value) => setForm((prev) => ({ ...prev, platform: value as DeviceRecord['platform'] }))}
          />
          <Select
            label="Scanner"
            value={form.scannerMode}
            options={['AUTO', 'CAMERA', 'HID', 'SUNMI', 'ZEBRA']}
            onChange={(value) => setForm((prev) => ({ ...prev, scannerMode: value as DeviceRecord['scannerMode'] }))}
          />
          <Select
            label="Sync Profile"
            value={form.syncProfile}
            options={['OFF', 'LIGHT', 'FULL']}
            onChange={(value) => setForm((prev) => ({ ...prev, syncProfile: value as DeviceRecord['syncProfile'] }))}
          />
          <button
            onClick={() => void createDevice()}
            disabled={!form.id || !form.name}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            Register Device
          </button>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Current Devices</h2>
          <div className="space-y-3">
            {devices.map((device) => (
              <div
                key={device.id}
                className="rounded-2xl border border-gray-100 bg-white p-4 flex items-center justify-between gap-4"
              >
                <div>
                  <p className="font-semibold text-[#1E1E2C]">{device.name}</p>
                  <p className="text-sm text-gray-500">
                    {device.type} · {device.platform} · {device.scannerMode} ·{' '}
                    {device.syncProfile}
                  </p>
                </div>
                <button
                  onClick={() => void toggleDevice(device)}
                  className={`rounded-full px-3 py-1 text-xs font-semibold ${
                    device.isActive
                      ? 'bg-green-50 text-green-700'
                      : 'bg-gray-100 text-gray-500'
                  }`}
                >
                  {device.status}
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function Select({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
}) {
  return (
    <label className="text-sm font-semibold text-gray-600">
      {label}
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        className="mt-2 w-full rounded-xl border border-gray-200 px-4 py-3 bg-white outline-none"
      >
        {options.map((option) => (
          <option key={option} value={option}>
            {option}
          </option>
        ))}
      </select>
    </label>
  );
}
