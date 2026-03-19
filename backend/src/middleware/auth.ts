import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface AuthRequest extends Request {
    userId?: string;
    userRole?: string;
    storeId?: string;
}

export const authMiddleware = (req: AuthRequest, res: Response, next: NextFunction): void => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Access denied. No token provided.' });
        return;
    }

    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET!) as {
            userId: string;
            role: string;
            storeId?: string;
        };
        req.userId = decoded.userId;
        req.userRole = decoded.role;
        req.storeId = decoded.storeId;
        next();
    } catch {
        res.status(401).json({ error: 'Invalid or expired token.' });
    }
};

export const requireAdmin = (req: AuthRequest, res: Response, next: NextFunction): void => {
    if (req.userRole !== 'SUPER_ADMIN') {
        res.status(403).json({ error: 'Access denied. Admin only.' });
        return;
    }
    next();
};
