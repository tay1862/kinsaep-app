export const API_URL = process.env.NEXT_PUBLIC_API_URL || '/api';

export type SessionUser = {
  accessToken: string;
  role: string;
  storeId?: string | null;
  name?: string | null;
  email?: string | null;
};

export function getSession(): SessionUser | null {
  if (typeof window === 'undefined') {
    return null;
  }

  const accessToken = localStorage.getItem('admin_token');
  const role = localStorage.getItem('admin_role');
  const storeId = localStorage.getItem('admin_store_id');
  const name = localStorage.getItem('admin_user_name');
  const email = localStorage.getItem('admin_user_email');

  if (!accessToken || !role) {
    return null;
  }

  return {
    accessToken,
    role,
    storeId,
    name,
    email,
  };
}

export function setSession(session: SessionUser): void {
  if (typeof window === 'undefined') {
    return;
  }

  localStorage.setItem('admin_token', session.accessToken);
  localStorage.setItem('admin_role', session.role);
  localStorage.setItem('admin_store_id', session.storeId || '');
  localStorage.setItem('admin_user_name', session.name || '');
  localStorage.setItem('admin_user_email', session.email || '');
}

export function clearSession(): void {
  if (typeof window === 'undefined') {
    return;
  }

  localStorage.removeItem('admin_token');
  localStorage.removeItem('admin_role');
  localStorage.removeItem('admin_store_id');
  localStorage.removeItem('admin_user_name');
  localStorage.removeItem('admin_user_email');
}

export function getWebSocketUrl(): string {
  if (typeof window === 'undefined') {
    return '';
  }

  const configured = process.env.NEXT_PUBLIC_API_URL;
  if (configured?.startsWith('http://') || configured?.startsWith('https://')) {
    const url = new URL(configured);
    url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
    url.pathname = '/ws';
    return url.toString();
  }

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${protocol}//${window.location.host}/ws`;
}

export async function fetchApi<T>(
  endpoint: string,
  options: RequestInit = {},
): Promise<T> {
  const token =
    typeof window !== 'undefined' ? localStorage.getItem('admin_token') || '' : '';

  const headers: HeadersInit = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  };

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers,
  });

  if (!response.ok) {
    let errorMessage = 'An error occurred';
    try {
      const errorData = (await response.json()) as { error?: string };
      errorMessage = errorData.error || errorMessage;
    } catch {}
    throw new Error(errorMessage);
  }

  return response.json() as Promise<T>;
}
