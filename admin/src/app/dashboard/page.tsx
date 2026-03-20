'use client';

import { useEffect, useState } from 'react';
import { Activity, ShieldAlert, Store, TrendingUp } from 'lucide-react';

import { fetchApi } from '@/lib/api';

type DashboardStats = {
  totalStores: number;
  activeStores: number;
  totalUsers: number;
  activeSyncJobs: number;
  statusBreakdown: Record<string, number>;
  packages: Array<{
    id: string;
    code: string;
    name: string;
    isActive: boolean;
  }>;
};

export default function DashboardOverview() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadStats() {
      try {
        const data = await fetchApi<DashboardStats>('/admin/dashboard');
        setStats(data);
      } catch (error) {
        console.error('Failed to load stats:', error);
      } finally {
        setLoading(false);
      }
    }

    void loadStats();
  }, []);

  if (loading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF7B54]" />
      </div>
    );
  }

  const breakdown = stats?.statusBreakdown || {};

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
            Kinsaep SaaS Overview
          </h1>
          <p className="text-gray-500 mt-1">
            Monitor tenant access modes and platform health here.
          </p>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Stores"
          value={stats?.totalStores || 0}
          icon={<Store className="w-5 h-5 text-blue-500" />}
          iconBg="bg-blue-50"
        />
        <StatCard
          title="Cloud Active"
          value={stats?.activeStores || 0}
          icon={<TrendingUp className="w-5 h-5 text-green-500" />}
          iconBg="bg-green-50"
        />
        <StatCard
          title="Offline Only"
          value={breakdown.OFFLINE_ONLY || 0}
          icon={<Activity className="w-5 h-5 text-[#FF7B54]" />}
          iconBg="bg-[#FF7B54]/10"
        />
        <StatCard
          title="Blocked / Expired"
          value={(breakdown.BLOCKED || 0) + (breakdown.EXPIRED || 0)}
          icon={<ShieldAlert className="w-5 h-5 text-red-500" />}
          iconBg="bg-red-50"
        />
        <StatCard
          title="Running Sync Jobs"
          value={stats?.activeSyncJobs || 0}
          icon={<Activity className="w-5 h-5 text-indigo-500" />}
          iconBg="bg-indigo-50"
        />
      </div>

      <div className="glass-panel p-8 rounded-2xl">
        <h2 className="text-xl font-bold text-[#1E1E2C] mb-6">Access Mode Breakdown</h2>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <ModeCard label="ACTIVE" value={breakdown.ACTIVE || 0} tone="green" />
          <ModeCard label="OFFLINE_ONLY" value={breakdown.OFFLINE_ONLY || 0} tone="orange" />
          <ModeCard label="BLOCKED" value={breakdown.BLOCKED || 0} tone="red" />
          <ModeCard label="EXPIRED" value={breakdown.EXPIRED || 0} tone="slate" />
        </div>
      </div>

      <div className="glass-panel p-8 rounded-2xl">
        <h2 className="text-xl font-bold text-[#1E1E2C] mb-6">Package Templates</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {(stats?.packages || []).map((pkg) => (
            <div
              key={pkg.id}
              className="rounded-2xl border border-gray-100 bg-white p-4"
            >
              <p className="text-xs font-semibold tracking-[0.16em] text-gray-400">
                {pkg.code}
              </p>
              <p className="mt-2 text-lg font-bold text-[#1E1E2C]">{pkg.name}</p>
              <p
                className={`mt-4 text-xs font-semibold ${
                  pkg.isActive ? 'text-green-600' : 'text-gray-400'
                }`}
              >
                {pkg.isActive ? 'ACTIVE TEMPLATE' : 'INACTIVE TEMPLATE'}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function StatCard({
  title,
  value,
  icon,
  iconBg,
}: {
  title: string;
  value: number;
  icon: React.ReactNode;
  iconBg: string;
}) {
  return (
    <div className="glass-panel p-6 rounded-2xl">
      <div className="flex justify-between items-start">
        <h3 className="text-gray-500 font-medium">{title}</h3>
        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${iconBg}`}>
          {icon}
        </div>
      </div>
      <div className="mt-4 flex items-baseline gap-2">
        <span className="text-4xl font-bold text-[#1E1E2C]">{value}</span>
      </div>
    </div>
  );
}

function ModeCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: number;
  tone: 'green' | 'orange' | 'red' | 'slate';
}) {
  const toneClasses = {
    green: 'bg-green-50 text-green-700 border-green-100',
    orange: 'bg-orange-50 text-orange-700 border-orange-100',
    red: 'bg-red-50 text-red-700 border-red-100',
    slate: 'bg-slate-50 text-slate-700 border-slate-100',
  }[tone];

  return (
    <div className={`rounded-2xl border p-4 ${toneClasses}`}>
      <p className="text-xs font-semibold tracking-[0.16em]">{label}</p>
      <p className="text-3xl font-bold mt-3">{value}</p>
    </div>
  );
}
