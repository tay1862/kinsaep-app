'use client';

import { useCallback, useEffect, useState } from 'react';

import { fetchApi } from '@/lib/api';
import { useRealtime } from '@/lib/use-realtime';

type StationRecord = {
  id: string;
  name: string;
  type: 'HOT' | 'COLD' | 'DRINK';
};

type ScreenRecord = {
  id: string;
  label: string;
  station: StationRecord;
  device: { id: string; name: string };
};

type TicketRecord = {
  id: string;
  status: 'NEW' | 'PREPARING' | 'READY' | 'SERVED' | 'CANCELLED';
  items: Array<{ id: string; itemName: string; quantity: number; status: string }>;
};

export default function StoreKitchenPage() {
  const [stations, setStations] = useState<StationRecord[]>([]);
  const [screens, setScreens] = useState<ScreenRecord[]>([]);
  const [tickets, setTickets] = useState<TicketRecord[]>([]);
  const [stationName, setStationName] = useState('');
  const [stationType, setStationType] = useState<'HOT' | 'COLD' | 'DRINK'>('HOT');

  const load = useCallback(async () => {
    const [stationRows, screenRows, ticketRows] = await Promise.all([
      fetchApi<StationRecord[]>('/kitchen/stations'),
      fetchApi<ScreenRecord[]>('/kitchen/screens'),
      fetchApi<TicketRecord[]>('/kitchen/tickets'),
    ]);
    setStations(stationRows);
    setScreens(screenRows);
    setTickets(ticketRows);
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
        if (message.event.startsWith('kitchen.')) {
          void load();
        }
      },
      [load],
    ),
  );

  async function createStation() {
    await fetchApi('/kitchen/stations', {
      method: 'POST',
      body: JSON.stringify({ name: stationName, type: stationType }),
    });
    setStationName('');
    await load();
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold tracking-tight text-[#1E1E2C]">Kitchen</h1>
        <p className="text-gray-500 mt-1">
          Preset station routing with realtime ticket updates for hot, cold, and drink lines.
        </p>
      </div>

      <div className="grid grid-cols-1 xl:grid-cols-[360px_minmax(0,1fr)] gap-6">
        <div className="glass-panel rounded-2xl p-6 space-y-4">
          <h2 className="text-lg font-bold text-[#1E1E2C]">Add Station</h2>
          <input
            value={stationName}
            onChange={(event) => setStationName(event.target.value)}
            placeholder="Station name"
            className="w-full rounded-xl border border-gray-200 px-4 py-3 outline-none"
          />
          <select
            value={stationType}
            onChange={(event) => setStationType(event.target.value as 'HOT' | 'COLD' | 'DRINK')}
            className="w-full rounded-xl border border-gray-200 px-4 py-3 bg-white outline-none"
          >
            <option value="HOT">HOT</option>
            <option value="COLD">COLD</option>
            <option value="DRINK">DRINK</option>
          </select>
          <button
            onClick={() => void createStation()}
            disabled={!stationName}
            className="w-full rounded-xl bg-[#FF7B54] px-4 py-3 text-white font-semibold disabled:opacity-60"
          >
            Create Station
          </button>
          <div className="space-y-2">
            {stations.map((station) => (
              <div key={station.id} className="rounded-xl border border-gray-100 bg-white px-4 py-3">
                {station.name} ({station.type})
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="glass-panel rounded-2xl p-6">
            <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Kitchen Screens</h2>
            <div className="space-y-3">
              {screens.map((screen) => (
                <div
                  key={screen.id}
                  className="rounded-2xl border border-gray-100 bg-white p-4"
                >
                  <p className="font-semibold text-[#1E1E2C]">{screen.label}</p>
                  <p className="text-sm text-gray-500">
                    {screen.station.name} · Device {screen.device.name}
                  </p>
                </div>
              ))}
            </div>
          </div>

          <div className="glass-panel rounded-2xl p-6">
            <h2 className="text-lg font-bold text-[#1E1E2C] mb-4">Live Tickets</h2>
            <div className="space-y-3">
              {tickets.map((ticket) => (
                <div key={ticket.id} className="rounded-2xl border border-gray-100 bg-white p-4">
                  <div className="flex items-center justify-between">
                    <p className="font-semibold text-[#1E1E2C]">{ticket.id}</p>
                    <p className="text-sm font-semibold text-[#FF7B54]">{ticket.status}</p>
                  </div>
                  <div className="mt-3 space-y-1 text-sm text-gray-500">
                    {ticket.items.map((item) => (
                      <div key={item.id}>
                        {item.itemName} x{item.quantity} · {item.status}
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
