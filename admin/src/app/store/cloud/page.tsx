'use client';

import { useCallback, useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';
import { useRealtime } from '@/lib/use-realtime';

type SyncStatusResponse = {
  accessMode: string;
  entitlement: {
    packageCode: string;
    maxSyncProfile: string;
    allowRawSalesSync: boolean;
    allowMediaUpload: boolean;
    retainRawSalesDays: number;
  };
  lastJob: {
    id: string;
    status: string;
    progress: number;
    createdAt: string;
    error: string | null;
    counts?: Record<string, number>;
  } | null;
};

type JobRecord = {
  id: string;
  direction: string;
  syncProfile: string;
  status: string;
  progress: number;
  createdAt: string;
  error: string | null;
};

export default function StoreCloudPage() {
  const [status, setStatus] = useState<SyncStatusResponse | null>(null);
  const [jobs, setJobs] = useState<JobRecord[]>([]);

  const load = useCallback(async () => {
    const [statusData, jobsData] = await Promise.all([
      fetchApi<SyncStatusResponse>('/sync/status'),
      fetchApi<{ jobs: JobRecord[] }>('/sync/jobs'),
    ]);
    setStatus(statusData);
    setJobs(jobsData.jobs);
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
        if (message.event === 'sync.job.updated' || message.event === 'sync.job.failed') {
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
          Cloud & Sync
        </h1>
        <p className="text-gray-500 mt-1">
          Track entitlement-driven sync capability, media policy, and recent sync history.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-6">
        <StatCard label="Access Mode" value={status?.accessMode || '-'} />
        <StatCard label="Package" value={status?.entitlement.packageCode || '-'} />
        <StatCard
          label="Max Sync"
          value={status?.entitlement.maxSyncProfile || '-'}
        />
        <StatCard
          label="Raw Sales"
          value={status?.entitlement.allowRawSalesSync ? 'ENABLED' : 'DISABLED'}
        />
      </div>

      <div className="glass-panel rounded-2xl p-6">
        <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Recent Jobs</h2>
        <div className="space-y-3">
          {jobs.map((job) => (
            <div key={job.id} className="rounded-2xl border border-gray-100 bg-white p-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="font-semibold text-[#1E1E2C]">
                    {job.direction} · {job.syncProfile}
                  </p>
                  <p className="text-xs text-gray-400">
                    {new Date(job.createdAt).toLocaleString()}
                  </p>
                </div>
                <p className="text-sm font-semibold text-[#FF7B54]">{job.status}</p>
              </div>
              <div className="mt-3 h-2 rounded-full bg-gray-100 overflow-hidden">
                <div
                  className="h-full bg-[#FF7B54]"
                  style={{ width: `${job.progress}%` }}
                />
              </div>
              {job.error ? <p className="mt-2 text-xs text-red-500">{job.error}</p> : null}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="glass-panel p-6 rounded-2xl">
      <p className="text-gray-500 font-medium">{label}</p>
      <p className="mt-4 text-3xl font-bold text-[#1E1E2C]">{value}</p>
    </div>
  );
}
