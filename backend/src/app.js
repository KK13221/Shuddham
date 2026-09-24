import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import mongoose from 'mongoose';
import { config } from './config.js';
import { authRouter } from './routes/auth.js';
import { meRouter } from './routes/me.js';
import { devicesRouter } from './routes/devices.js';
import { adminRouter } from './routes/admin.js';
import { HttpError } from './lib/http.js';

export function createApp({ logger = console } = {}) {
  const app = express();
  app.set('trust proxy', 1);
  app.use(helmet());
  app.use(cors({ origin: config.corsOrigins }));
  app.use(express.json({ limit: '100kb' }));
  if (!config.isProd) app.use(morgan('dev'));

  app.get('/health', (_req, res) => {
    res.json({ ok: true, db: mongoose.connection.readyState === 1 ? 'up' : 'down' });
  });

  app.use('/api/auth', authRouter);
  app.use('/api/me', meRouter);
  app.use('/api/devices', devicesRouter);
  app.use('/api/admin', adminRouter);

  app.use((_req, _res, next) => next(new HttpError(404, 'NOT_FOUND')));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err instanceof HttpError) {
      return res.status(err.status).json({ error: { code: err.code, message: err.message } });
    }
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ error: { code: 'INVALID_JSON', message: 'Invalid JSON body' } });
    }
    if (err.name === 'ValidationError') {
      return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: err.message } });
    }
    logger.error(err);
    res.status(500).json({ error: { code: 'SERVER_ERROR', message: 'Something went wrong' } });
  });

  return app;
}
