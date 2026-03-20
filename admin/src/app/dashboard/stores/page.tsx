'use client';

import { useEffect, useState } from 'react';
import { CheckCircle2, Search, ShieldAlert, XCircle } from 'lucide-react';

import { fetchApi } from '@/lib/api';

type StoreRecord = {
  id: string;
  name: string;
  owner: {
    email: string;
    name: string;
    phone: string | null;
  };
  accessMode: 'OFFLINE_ONLY' | 'ACTIVE' | 'BLOCKED' | 'EXPIRED';
  subscription: {
    plan: string;
    status: string;
    validUntil: string;
  } | null;
  entitlement: {
    packageCode: string;
    maxDevices: number;
    maxStaff: number;
    maxSyncProfile: string;
  };
  counts: {
    devices: number;
    staff: number;
    kitchenScreens: number;
  };
};

type StoresResponse = {
  stores: StoreRecord[];
  total: number;
  page: number;
  totalPages: number;
};

export default function StoresPage() {
  const [stores, setStores] = useState<StoreRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | StoreRecord['accessMode']>('ALL');

  useEffect(() => {
    void loadStores();
  }, []);

  async function loadStores() {
    setLoading(true);
    try {
      const data = await fetchApi<StoresResponse>('/admin/stores');
      setStores(data.stores);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  }

  async function handleUpdateStatus(storeId: string, status: 'ACTIVE' | 'BLOCKED') {
    setActionLoading(storeId);
    try {
      await fetchApi(`/admin/stores/${storeId}/subscription`, {
        method: 'PATCH',
        body: JSON.stringify({ status }),
      });
      await loadStores();
    } catch (error) {
      alert(error instanceof Error ? error.message : 'Failed to update subscription');
    } finally {
      setActionLoading(null);
    }
  }

  const filteredStores = stores.filter((store) => {
    const matchesSearch =
      store.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      store.owner.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesStatus = statusFilter === 'ALL' || store.accessMode === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center mb-8">
        <div>
          <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
            Store Management
          </h1>
          <p className="text-gray-500 mt-1">
            Manage tenants, activation state, and cloud access from one place.
          </p>
        </div>
      </div>

      <div className="glass-panel p-4 rounded-2xl flex gap-4 items-center">
        <div className="relative flex-1">
          <Search className="w-5 h-5 text-gray-400 absolute left-4 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Search stores or owner email..."
            value={searchTerm}
            onChange={(event) => setSearchTerm(event.target.value)}
            className="w-full pl-12 pr-4 py-3 rounded-xl border border-gray-200 outline-none focus:ring-2 focus:ring-[#FF7B54] transition-all"
          />
        </div>
        <select
          value={statusFilter}
          onChange={(event) =>
            setStatusFilter(event.target.value as 'ALL' | StoreRecord['accessMode'])
          }
          className="border border-gray-200 rounded-xl px-4 py-3 outline-none focus:ring-2 focus:ring-[#FF7B54] bg-white"
        >
          <option value="ALL">All Access Modes</option>
          <option value="ACTIVE">ACTIVE</option>
          <option value="OFFLINE_ONLY">OFFLINE_ONLY</option>
          <option value="BLOCKED">BLOCKED</option>
          <option value="EXPIRED">EXPIRED</option>
        </select>
      </div>

      <div className="glass-panel rounded-2xl overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-gray-50 border-b border-gray-100 text-gray-500 font-medium text-sm">
                <th className="py-4 px-6">Store Name</th>
                <th className="py-4 px-6">Owner Email</th>
                <th className="py-4 px-6">Package</th>
                <th className="py-4 px-6">Access Mode</th>
                <th className="py-4 px-6">Usage</th>
                <th className="py-4 px-6 text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-gray-500">
                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#FF7B54] mx-auto mb-4" />
                    Loading stores...
                  </td>
                </tr>
              ) : filteredStores.length === 0 ? (
                <tr>
                  <td colSpan={6} className="py-8 text-center text-gray-500">
                    No stores found.
                  </td>
                </tr>
              ) : (
                filteredStores.map((store) => {
                  const canActivate =
                    store.accessMode === 'BLOCKED' ||
                    store.accessMode === 'OFFLINE_ONLY' ||
                    store.accessMode === 'EXPIRED';

                  return (
                    <tr
                      key={store.id}
                      className="border-b border-gray-50 hover:bg-gray-50/50 transition-colors"
                    >
                      <td className="py-4 px-6 font-semibold text-[#1E1E2C]">{store.name}</td>
                      <td className="py-4 px-6 text-gray-600">{store.owner.email}</td>
                      <td className="py-4 px-6">
                        <span className="px-3 py-1 bg-blue-50 text-blue-600 rounded-full text-xs font-bold font-mono">
                          {store.entitlement.packageCode}
                        </span>
                      </td>
                      <td className="py-4 px-6">
                        <AccessModeBadge mode={store.accessMode} />
                      </td>
                      <td className="py-4 px-6 text-sm text-gray-500">
                        <div>Staff {store.counts.staff}/{store.entitlement.maxStaff}</div>
                        <div>Devices {store.counts.devices}/{store.entitlement.maxDevices}</div>
                        <div>Sync {store.entitlement.maxSyncProfile}</div>
                      </td>
                      <td className="py-4 px-6 text-right">
                        {canActivate ? (
                          <button
                            disabled={actionLoading === store.id}
                            onClick={() => handleUpdateStatus(store.id, 'ACTIVE')}
                            className="text-sm font-semibold bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded-lg transition-colors shadow-sm disabled:opacity-50"
                          >
                            Activate
                          </button>
                        ) : (
                          <button
                            disabled={actionLoading === store.id}
                            onClick={() => handleUpdateStatus(store.id, 'BLOCKED')}
                            className="text-sm font-semibold bg-red-100 hover:bg-red-200 text-red-600 px-4 py-2 rounded-lg transition-colors flex items-center justify-end gap-1 ml-auto disabled:opacity-50"
                          >
                            <ShieldAlert className="w-4 h-4" /> Block
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

function AccessModeBadge({ mode }: { mode: StoreRecord['accessMode'] }) {
  const isActive = mode === 'ACTIVE';
  const isOfflineOnly = mode === 'OFFLINE_ONLY';
  const tone = isActive
    ? 'bg-green-50 text-green-600'
    : isOfflineOnly
      ? 'bg-orange-50 text-orange-600'
      : 'bg-red-50 text-red-600';

  return (
    <span className={`px-3 py-1 rounded-full text-xs font-bold flex w-max items-center gap-1 ${tone}`}>
      {isActive ? (
        <CheckCircle2 className="w-3 h-3" />
      ) : (
        <XCircle className="w-3 h-3" />
      )}
      {mode}
    </span>
  );
}
