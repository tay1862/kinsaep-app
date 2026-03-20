'use client';

import { useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';

type StaffRecord = {
  id: string;
  name: string;
  role: 'OWNER' | 'MANAGER' | 'CASHIER';
  isActive: boolean;
};

export default function StoreStaffPage() {
  const [staff, setStaff] = useState<StaffRecord[]>([]);
  const [form, setForm] = useState({ name: '', pin: '', role: 'CASHIER' as StaffRecord['role'] });

  async function loadStaff() {
    const data = await fetchApi<StaffRecord[]>('/staff');
    setStaff(data);
  }

  useEffect(() => {
    const timer = window.setTimeout(() => {
      void loadStaff();
    }, 0);
    return () => window.clearTimeout(timer);
  }, []);

  async function createStaff() {
    await fetchApi('/staff', {
      method: 'POST',
      body: JSON.stringify(form),
    });
    setForm({ name: '', pin: '', role: 'CASHIER' });
    await loadStaff();
  }

  async function toggleStaff(member: StaffRecord) {
    await fetchApi(`/staff/${member.id}`, {
      method: 'PATCH',
      body: JSON.stringify({ isActive: !member.isActive }),
    });
    await loadStaff();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">Staff</h1>
        <p className="text-gray-500 mt-1">
          Create, update, and deactivate store staff with package-limit enforcement.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_minmax(0,1fr)] gap-6">
        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Add Staff</h2>
          <input
            value={form.name}
            onChange={(event) => setForm((prev) => ({ ...prev, name: event.target.value }))}
            placeholder="Staff name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <input
            value={form.pin}
            onChange={(event) => setForm((prev) => ({ ...prev, pin: event.target.value }))}
            placeholder="PIN"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <select
            value={form.role}
            onChange={(event) =>
              setForm((prev) => ({
                ...prev,
                role: event.target.value as StaffRecord['role'],
              }))
            }
            className="w-full rounded-xl border border-gray-200 px-4 py-3 bg-white outline-none"
          >
            <option value="OWNER">OWNER</option>
            <option value="MANAGER">MANAGER</option>
            <option value="CASHIER">CASHIER</option>
          </select>
          <button
            onClick={() => void createStaff()}
            disabled={!form.name || !form.pin}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            Create Staff
          </button>
        </div>

        <div className="glass-panel rounded-2xl p-6">
          <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Current Staff</h2>
          <div className="space-y-3">
            {staff.map((member) => (
              <div
                key={member.id}
                className="rounded-2xl border border-gray-100 bg-white p-4 flex items-center justify-between gap-4"
              >
                <div>
                  <p className="font-semibold text-[#1E1E2C]">{member.name}</p>
                  <p className="text-sm text-gray-500">{member.role}</p>
                </div>
                <button
                  onClick={() => void toggleStaff(member)}
                  className={`rounded-full px-3 py-1 text-xs font-semibold ${
                    member.isActive
                      ? 'bg-green-50 text-green-700'
                      : 'bg-gray-100 text-gray-500'
                  }`}
                >
                  {member.isActive ? 'ACTIVE' : 'INACTIVE'}
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
