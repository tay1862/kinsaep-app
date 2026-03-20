'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useMemo } from 'react';
import type { LucideIcon } from 'lucide-react';
import { LogOut, Store } from 'lucide-react';

import { clearSession } from '@/lib/api';

export type NavItem = {
  href: string;
  label: string;
  icon: LucideIcon;
};

export function AppShell({
  title,
  subtitle,
  navItems,
  children,
}: {
  title: string;
  subtitle: string;
  navItems: NavItem[];
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();
  const current = useMemo(
    () => navItems.find((item) => pathname.startsWith(item.href)) ?? navItems[0],
    [navItems, pathname],
  );

  const handleLogout = () => {
    clearSession();
    router.replace('/');
  };

  return (
    <div className="min-h-screen bg-[#F8F9FE] flex">
      <aside className="w-72 bg-white border-r border-gray-200 flex flex-col fixed h-full z-10">
        <div className="p-6 flex items-center gap-3">
          <div className="w-11 h-11 bg-gradient-to-br from-[#FF7B54] to-[#FF6231] rounded-xl flex items-center justify-center shadow-md">
            <Store className="w-5 h-5 text-white" />
          </div>
          <div>
            <h2 className="font-bold text-[#1E1E2C] leading-tight">{title}</h2>
            <p className="text-xs text-gray-500 font-medium tracking-wide uppercase">
              {subtitle}
            </p>
          </div>
        </div>

        <nav className="flex-1 px-4 py-4 space-y-1">
          {navItems.map((item) => {
            const isActive =
              pathname === item.href || pathname.startsWith(`${item.href}/`);
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold transition-all ${
                  isActive
                    ? 'bg-[#FF7B54]/10 text-[#FF7B54]'
                    : 'text-gray-500 hover:bg-gray-50 hover:text-gray-900'
                }`}
              >
                <item.icon
                  className={`w-5 h-5 ${
                    isActive ? 'text-[#FF7B54]' : 'text-gray-400'
                  }`}
                />
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-gray-100">
          <div className="px-4 pb-3">
            <p className="text-xs uppercase tracking-[0.16em] text-gray-400">Current</p>
            <p className="mt-2 text-sm font-semibold text-[#1E1E2C]">
              {current?.label}
            </p>
          </div>
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-4 py-3 w-full rounded-xl text-sm font-semibold text-gray-500 hover:bg-red-50 hover:text-red-600 transition-all"
          >
            <LogOut className="w-5 h-5 text-gray-400" />
            Sign Out
          </button>
        </div>
      </aside>

      <main className="flex-1 ml-72 p-8">
        <div className="max-w-7xl mx-auto">{children}</div>
      </main>
    </div>
  );
}
