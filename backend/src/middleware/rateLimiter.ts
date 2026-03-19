import { Request, Response, NextFunction } from 'express';

const requestCounts = new Map<string, { count: number; resetAt: number }>();

const WINDOW_MS = 60 * 1000; // 1 minute
const MAX_REQUESTS = 100;    // 100 requests per minute per IP

export const rateLimiter = (req: Request, res: Response, next: NextFunction): void => {
    const ip = req.ip || req.socket.remoteAddress || 'unknown';
    const now = Date.now();
    const record = requestCounts.get(ip);

    if (!record || now > record.resetAt) {
        requestCounts.set(ip, { count: 1, resetAt: now + WINDOW_MS });
        next();
        return;
    }

    record.count++;
    if (record.count > MAX_REQUESTS) {
        res.status(429).json({ error: 'Too many requests. Please try again later.' });
        return;
    }

    next();
};
