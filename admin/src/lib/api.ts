export const API_URL = process.env.NEXT_PUBLIC_API_URL || '/api';

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
