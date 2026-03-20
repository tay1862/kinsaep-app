'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import {
  Cloud,
  CookingPot,
  LayoutDashboard,
  MonitorSmartphone,
  PackageSearch,
  Users,
} from 'lucide-react';

import { AppShell } from '@/components/app-shell';
import { getSession } from '@/lib/api';

export default function StoreLayout({
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
    if (session.role === 'SUPER_ADMIN') {
      router.replace('/dashboard');
    }
  }, [router]);

  if (typeof window === 'undefined') {
    return null;
  }

  const session = getSession();
  if (!session || session.role === 'SUPER_ADMIN') {
    return null;
  }

  return (
    <AppShell
      title="Kinsaep Store"
      subtitle="OWNER PORTAL"
      navItems={[
        { href: '/store/dashboard', label: 'Dashboard', icon: LayoutDashboard },
        { href: '/store/staff', label: 'Staff', icon: Users },
        { href: '/store/devices', label: 'Devices', icon: MonitorSmartphone },
        { href: '/store/catalog', label: 'Catalog', icon: PackageSearch },
        { href: '/store/kitchen', label: 'Kitchen', icon: CookingPot },
        { href: '/store/cloud', label: 'Cloud & Sync', icon: Cloud },
      ]}
    >
      {children}
    </AppShell>
  );
}
