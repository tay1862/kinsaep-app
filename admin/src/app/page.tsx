'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Store } from 'lucide-react';
import { fetchApi } from '@/lib/api';

type LoginResponse = {
  accessToken: string;
  user: {
    role: string;
  };
};

export default function AdminLogin() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const data = await fetchApi<LoginResponse>('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });

      if (data.user.role !== 'SUPER_ADMIN') {
        throw new Error('Access denied. Super Admin privileges required.');
      }

      localStorage.setItem('admin_token', data.accessToken);
      router.replace('/dashboard');
    } catch (error: unknown) {
      setError(error instanceof Error ? error.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#F8F9FE]">
      <div className="w-full max-w-md p-8 glass-panel rounded-2xl">
        <div className="flex flex-col items-center mb-8">
          <div className="w-16 h-16 bg-gradient-to-br from-[#FF7B54] to-[#FF6231] rounded-2xl flex items-center justify-center shadow-lg mb-4">
            <Store className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-[#1E1E2C]">Kinsaep Super Admin</h1>
          <p className="text-gray-500 mt-2 text-center text-sm">Control center for SaaS tenants and multi-branch POS management.</p>
        </div>

        {error && (
          <div className="bg-red-50 text-red-500 p-3 rounded-lg text-sm mb-6 border border-red-100">
            {error}
          </div>
        )}

        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full p-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-[#FF7B54] focus:border-[#FF7B54] outline-none transition-all"
              placeholder="admin@kinsaeppos.com"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full p-3 border border-gray-200 rounded-xl focus:ring-2 focus:ring-[#FF7B54] focus:border-[#FF7B54] outline-none transition-all"
              placeholder="••••••••"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="w-full bg-[#FF7B54] hover:bg-[#FF6231] text-white font-bold py-3 rounded-xl shadow-md transition-colors disabled:opacity-70 mt-4"
          >
            {loading ? 'Authenticating...' : 'Sign In'}
          </button>
        </form>
      </div>
    </div>
  );
}
