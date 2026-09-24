import { Server } from 'socket.io';
import { config } from './config.js';
import { verifyToken } from './middleware/auth.js';

/**
 * Socket.IO for live updates. Clients connect with { auth: { token } }.
 * Users join "user:<id>", admins also join "admins".
 * Events: "reading", "device:status", "alert".
 */
export function createRealtime(httpServer, { logger = console } = {}) {
  const io = new Server(httpServer, { cors: { origin: config.corsOrigins } });

  io.use((socket, next) => {
    try {
      const payload = verifyToken(socket.handshake.auth?.token || '');
      socket.data.userId = payload.sub;
      socket.data.role = payload.role;
      next();
    } catch {
      next(new Error('unauthorized'));
    }
  });

  io.on('connection', (socket) => {
    socket.join(`user:${socket.data.userId}`);
    if (socket.data.role === 'admin') socket.join('admins');
  });

  logger.info('[realtime] socket.io ready');
  return realtimeEmitter(io);
}

export function realtimeEmitter(io) {
  return {
    io,
    /** Send to the device owner (if any) and all admins. */
    emitDevice(ownerId, event, data) {
      if (!io) return;
      let target = io.to('admins');
      if (ownerId) target = target.to(`user:${ownerId}`);
      target.emit(event, data);
    },
  };
}

/** No-op emitter for tests and scripts. */
export const nullRealtime = realtimeEmitter(null);
