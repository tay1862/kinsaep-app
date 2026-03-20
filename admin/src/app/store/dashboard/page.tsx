'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type SyncStatusResponse = {
  accessMode: string;
  entitlement: {
    packageCode: string;
    maxStaff: number;
    maxDevices: number;
    maxKitchenScreens: number;
    maxSyncProfile: string;
  };
  lastJob: {
    status: string;
    progress: number;
    createdAt: string;
    error: string | null;
  } | null;
};

export default function StoreDashboardPage() {
  const [syncStatus, setSyncStatus] = useState<SyncStatusResponse | null>(null);
  const [staffCount, setStaffCount] = useState(0);
  const [deviceCount, setDeviceCount] = useState(0);
  const [stationCount, setStationCount] = useState(0);

  useEffect(() => {
    async function load() {
      const [status, staff, devices, stations] = await Promise.all([
        fetchApi<SyncStatusResponse>('/sync/status'),
        fetchApi<Array<unknown>>('/staff'),
        fetchApi<Array<unknown>>('/devices'),
        fetchApi<Array<unknown>>('/kitchen/stations'),
      ]);

      setSyncStatus(status);
      setStaffCount(staff.length);
      setDeviceCount(devices.length);
      setStationCount(stations.length);
    }

    void load();
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
          Store Dashboard
        </h1>
        <p className="text-gray-500 mt-1">
          Manage limits, staff, devices, kitchen, and the current cloud state.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <Card label="Access Mode" value={syncStatus?.accessMode || '-'} />
        <Card
          label="Package"
          value={syncStatus?.entitlement.packageCode || '-'}
        />
        <Card
          label="Staff Usage"
          value={`${staffCount}/${syncStatus?.entitlement.maxStaff || 0}`}
        />
        <Card
          label="Device Usage"
          value={`${deviceCount}/${syncStatus?.entitlement.maxDevices || 0}`}
        />
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_420px] gap-6">
        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Current Limits</h2>
          <div className="grid grid-cols-2 gap-4 text-sm text-gray-600">
            <div>Kitchen Screens: {syncStatus?.entitlement.maxKitchenScreens || 0}</div>
            <div>Stations: {stationCount}</div>
            <div>Max Sync Profile: {syncStatus?.entitlement.maxSyncProfile || '-'}</div>
            <div>Devices: {deviceCount}</div>
          </div>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Last Sync Job</h2>
          {syncStatus?.lastJob ? (
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-500">{syncStatus.lastJob.status}</span>
                <span className="text-sm font-semibold text-[#1E1E2C]">
                  {syncStatus.lastJob.progress}%
                </span>
              </div>
              <div className="h-2 rounded-full bg-gray-100 overflow-hidden">
                <div
                  className="h-full bg-[#FF7B54]"
                  style={{ width: `${syncStatus.lastJob.progress}%` }}
                />
              </div>
              <p className="text-xs text-gray-400">
                {new Date(syncStatus.lastJob.createdAt).toLocaleString()}
              </p>
              {syncStatus.lastJob.error ? (
                <p className="text-xs text-red-500">{syncStatus.lastJob.error}</p>
              ) : null}
            </div>
          ) : (
            <p className="text-sm text-gray-500">No sync jobs yet.</p>
          )}
        </div>
      </div>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div className="glass-panel p-6 rounded-2xl">
      <p className="text-gray-500 font-medium">{label}</p>
      <p className="mt-4 text-3xl font-bold text-[#1E1E2C]">{value}</p>
    </div>
  );
}
