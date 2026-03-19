import { Request, Response, NextFunction } from 'express';

export const errorHandler = (err: Error, _req: Request, res: Response, _next: NextFunction): void => {
    console.error('❌ Server Error:', err.message);
    res.status(500).json({
        error: 'Internal server error',
        ...(process.env.NODE_ENV === 'development' && { details: err.message }),
    });
};
