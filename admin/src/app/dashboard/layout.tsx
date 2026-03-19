'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { LayoutDashboard, LogOut, Store } from 'lucide-react';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (typeof window !== 'undefined' && !localStorage.getItem('admin_token')) {
      router.replace('/');
    }
  }, [router]);

  if (typeof window === 'undefined') {
    return null;
  }

  const token = localStorage.getItem('admin_token');
  if (!token) {
    return null;
  }

  const navItems = [
    { href: '/dashboard', label: 'Overview', icon: LayoutDashboard },
    { href: '/dashboard/stores', label: 'Stores & Tenants', icon: Store },
  ];

  const handleLogout = () => {
    localStorage.removeItem('admin_token');
    router.replace('/');
  };

  return (
    <div className="min-h-screen bg-[#F8F9FE] flex">
      <aside className="w-64 bg-white border-r border-gray-200 flex flex-col fixed h-full z-10">
        <div className="p-6 flex items-center gap-3">
          <div className="w-10 h-10 bg-gradient-to-br from-[#FF7B54] to-[#FF6231] rounded-xl flex items-center justify-center shadow-md">
            <Store className="w-5 h-5 text-white" />
          </div>
          <div>
            <h2 className="font-bold text-[#1E1E2C] leading-tight">Kinsaep Admin</h2>
            <p className="text-xs text-gray-500 font-medium tracking-wide uppercase">
              SUPER USER
            </p>
          </div>
        </div>

        <nav className="flex-1 px-4 py-4 space-y-1">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
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
          <button
            onClick={handleLogout}
            className="flex items-center gap-3 px-4 py-3 w-full rounded-xl text-sm font-semibold text-gray-500 hover:bg-red-50 hover:text-red-600 transition-all"
          >
            <LogOut className="w-5 h-5 text-gray-400" />
            Sign Out
          </button>
        </div>
      </aside>

      <main className="flex-1 ml-64 p-8">
        <div className="max-w-7xl mx-auto">{children}</div>
      </main>
    </div>
  );
}
