'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  Activity,
  LayoutDashboard,
  Logs,
  Package,
  Store,
} from 'lucide-react';

import { AppShell } from '@/components/app-shell';
import { getSession } from '@/lib/api';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();

  useEffect(() => {
    const session = getSession();
    if (!session) {
      router.replace('/');
      return;
    }
    if (session.role !== 'SUPER_ADMIN') {
      router.replace('/store/dashboard');
    }
  }, [router]);

  if (typeof window === 'undefined') {
    return null;
  }

  const session = getSession();
  if (!session || session.role !== 'SUPER_ADMIN') {
    return null;
  }

  return (
    <AppShell
      title="Kinsaep Admin"
      subtitle="SUPER ADMIN"
      navItems={[
        { href: '/dashboard', label: 'Overview', icon: LayoutDashboard },
        { href: '/dashboard/stores', label: 'Stores', icon: Store },
        { href: '/dashboard/packages', label: 'Packages', icon: Package },
        { href: '/dashboard/health', label: 'Device & Sync', icon: Activity },
        { href: '/dashboard/logs', label: 'Activity Logs', icon: Logs },
      ]}
    >
      {children}
    </AppShell>
  );
}
