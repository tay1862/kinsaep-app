'use client';

import { useEffect } from 'react';

import { getSession, getWebSocketUrl } from './api';

export function useRealtime(onMessage: (data: { event: string; payload: unknown }) => void) {
  useEffect(() => {
    const session = getSession();
    if (!session) {
      return;
    }

    const wsUrl = getWebSocketUrl();
    if (!wsUrl) {
      return;
    }

    const socket = new WebSocket(wsUrl);
    socket.addEventListener('open', () => {
      socket.send(
        JSON.stringify({
          type: 'subscribe',
          storeId: session.storeId || undefined,
          role: session.role,
        }),
      );
    });
    socket.addEventListener('message', (event) => {
      try {
        onMessage(JSON.parse(event.data));
      } catch {
        // Ignore malformed realtime messages.
      }
    });

    return () => {
      socket.close();
    };
  }, [onMessage]);
}
