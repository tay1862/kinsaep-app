import type { Server as HttpServer } from 'http';

import { WebSocketServer, type WebSocket } from 'ws';

type ClientContext = {
  socket: WebSocket;
  storeId?: string;
  role?: string;
};

const clients = new Set<ClientContext>();
let wss: WebSocketServer | null = null;

export function initRealtime(server: HttpServer): void {
  if (wss) {
    return;
  }

  wss = new WebSocketServer({ server, path: '/ws' });
  wss.on('connection', (socket) => {
    const client: ClientContext = { socket };
    clients.add(client);

    socket.on('message', (raw) => {
      try {
        const message = JSON.parse(raw.toString()) as {
          type?: string;
          storeId?: string;
          role?: string;
        };
        if (message.type === 'subscribe') {
          client.storeId = message.storeId;
          client.role = message.role;
        }
      } catch {
        // Ignore invalid realtime payloads.
      }
    });

    socket.on('close', () => {
      clients.delete(client);
    });
  });
}

export function broadcastToStore(
  storeId: string,
  event: string,
  payload: Record<string, unknown>,
): void {
  const message = JSON.stringify({ event, payload, storeId });
  for (const client of clients) {
    if (
      client.socket.readyState === client.socket.OPEN &&
      client.storeId === storeId
    ) {
      client.socket.send(message);
    }
  }
}

export function broadcastToAdmins(
  event: string,
  payload: Record<string, unknown>,
): void {
  const message = JSON.stringify({ event, payload });
  for (const client of clients) {
    if (
      client.socket.readyState === client.socket.OPEN &&
      client.role === 'SUPER_ADMIN'
    ) {
      client.socket.send(message);
    }
  }
}
