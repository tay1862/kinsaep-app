import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import http from 'http';
import path from 'path';
import { authRouter } from './routes/auth';
import { syncRouter } from './routes/sync';
import { adminRouter } from './routes/admin';
import { staffRouter } from './routes/staff';
import { devicesRouter } from './routes/devices';
import { kitchenRouter } from './routes/kitchen';
import { mediaRouter } from './routes/media';
import { catalogRouter } from './routes/catalog';
import { getUploadsRoot } from './lib/media';
import { initRealtime } from './lib/realtime';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';
import { rateLimiter } from './middleware/rateLimiter';

dotenv.config();

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 4000;

// ─── Global Middleware ───
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(rateLimiter);
app.use('/media', express.static(path.resolve(getUploadsRoot())));

// ─── Health Check ───
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', version: '1.0.0', timestamp: new Date().toISOString() });
});

// ─── Public Routes ───
app.use('/api/auth', authRouter);

// ─── Protected Routes (JWT Required) ───
app.use('/api/sync', authMiddleware, syncRouter);
app.use('/api/staff', authMiddleware, staffRouter);
app.use('/api/devices', authMiddleware, devicesRouter);
app.use('/api/kitchen', authMiddleware, kitchenRouter);
app.use('/api/media', authMiddleware, mediaRouter);
app.use('/api/catalog', authMiddleware, catalogRouter);

// ─── Admin Routes (SUPER_ADMIN Only) ───
app.use('/api/admin', authMiddleware, adminRouter);

// ─── Error Handler ───
app.use(errorHandler);

initRealtime(server);

server.listen(PORT, () => {
  console.log(`🚀 Kinsaep POS API running on port ${PORT}`);
});

export default app;
