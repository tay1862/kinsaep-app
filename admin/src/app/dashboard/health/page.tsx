'use client';

import { useCallback, useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';
import { useRealtime } from '@/lib/use-realtime';

type DeviceRecord = {
  id: string;
  name: string;
  type: string;
  platform: string;
  status: string;
  syncProfile: string;
  lastSeenAt: string | null;
  store: { name: string };
};

type SyncJobRecord = {
  id: string;
  status: string;
  progress: number;
  direction: string;
  syncProfile: string;
  createdAt: string;
  error: string | null;
  store: { name: string };
  device: { name: string; type: string } | null;
};

export default function HealthPage() {
  const [devices, setDevices] = useState<DeviceRecord[]>([]);
  const [jobs, setJobs] = useState<SyncJobRecord[]>([]);

  const load = useCallback(async () => {
    const data = await fetchApi<{ devices: DeviceRecord[]; syncJobs: SyncJobRecord[] }>(
      '/admin/health/devices-sync',
    );
    setDevices(data.devices);
    setJobs(data.syncJobs);
  }, []);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void load();
    }, 0);
    return () => window.clearTimeout(timer);
  }, [load]);

  useRealtime(
    useCallback(
      (message) => {
        if (
          message.event === 'sync.job.updated' ||
          message.event === 'sync.job.failed' ||
          message.event === 'device.created' ||
          message.event === 'device.updated' ||
          message.event === 'device.ping'
        ) {
          void load();
        }
      },
      [load],
    ),
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
          Device & Sync Health
        </h1>
        <p className="text-gray-500 mt-1">
          Live view of device heartbeat and recent sync jobs across all stores.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[minmax(0,1fr)_460px] gap-6">
        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Devices</h2>
          <div className="space-y-3">
            {devices.map((device) => (
              <div
                key={device.id}
                className="rounded-2xl border border-gray-100 bg-white p-4 flex items-center justify-between gap-4"
              >
                <div>
                  <p className="text-sm font-semibold text-[#1E1E2C]">{device.name}</p>
                  <p className="text-sm text-gray-500">
                    {device.store.name} · {device.type} · {device.platform}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-xs font-semibold text-gray-400">{device.syncProfile}</p>
                  <p
                    className={`text-sm font-semibold ${
                      device.status === 'ONLINE' ? 'text-green-600' : 'text-gray-500'
                    }`}
                  >
                    {device.status}
                  </p>
                  <p className="text-xs text-gray-400">
                    {device.lastSeenAt
                      ? new Date(device.lastSeenAt).toLocaleString()
                      : 'Never seen'}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Recent Sync Jobs</h2>
          <div className="space-y-3">
            {jobs.map((job) => (
              <div key={job.id} className="rounded-2xl border border-gray-100 bg-white p-4">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-sm font-semibold text-[#1E1E2C]">
                      {job.store.name}
                    </p>
                    <p className="text-xs text-gray-500">
                      {job.device?.name || 'Unknown device'} · {job.direction} ·{' '}
                      {job.syncProfile}
                    </p>
                  </div>
                  <p
                    className={`text-sm font-semibold ${
                      job.status === 'FAILED'
                        ? 'text-red-600'
                        : job.status === 'SUCCEEDED'
                          ? 'text-green-600'
                          : 'text-[#FF7B54]'
                    }`}
                  >
                    {job.status}
                  </p>
                </div>
                <div className="mt-3 h-2 rounded-full bg-gray-100 overflow-hidden">
                  <div
                    className="h-full bg-[#FF7B54]"
                    style={{ width: `${job.progress}%` }}
                  />
                </div>
                <p className="mt-2 text-xs text-gray-400">
                  {new Date(job.createdAt).toLocaleString()}
                </p>
                {job.error ? (
                  <p className="mt-2 text-xs text-red-500">{job.error}</p>
                ) : null}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
