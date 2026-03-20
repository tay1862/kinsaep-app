'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type LogRecord = {
  id: string;
  action: string;
  createdAt: string;
  store: { name: string } | null;
  user: { name: string; email: string } | null;
  staff: { name: string; role: string } | null;
};

export default function LogsPage() {
  const [logs, setLogs] = useState<LogRecord[]>([]);

  useEffect(() => {
    async function load() {
      const data = await fetchApi<{ logs: LogRecord[] }>('/admin/logs');
      setLogs(data.logs);
    }

    void load();
  }, []);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">
          Activity Logs
        </h1>
        <p className="text-gray-500 mt-1">
          Audit actions from super-admin, stores, staff, and sync operations.
        </p>
      </div>

      <div className="glass-panel rounded-2xl overflow-hidden">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-100 text-gray-500 font-medium text-sm">
              <th className="py-4 px-6">Action</th>
              <th className="py-4 px-6">Store</th>
              <th className="py-4 px-6">Actor</th>
              <th className="py-4 px-6">When</th>
            </tr>
          </thead>
          <tbody>
            {logs.map((log) => (
              <tr key={log.id} className="border-b border-gray-50">
                <td className="py-4 px-6 font-semibold text-[#1E1E2C]">{log.action}</td>
                <td className="py-4 px-6 text-gray-600">{log.store?.name || '-'}</td>
                <td className="py-4 px-6 text-gray-600">
                  {log.user?.email || log.staff?.name || '-'}
                </td>
                <td className="py-4 px-6 text-gray-500">
                  {new Date(log.createdAt).toLocaleString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
