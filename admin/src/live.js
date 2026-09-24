import { useEffect, useRef } from 'react';
import { io } from 'socket.io-client';
import { API_URL, getToken } from './api.js';

let socket = null;

function getSocket() {
  const token = getToken();
  if (!token) return null;
  if (!socket) {
    socket = io(API_URL, { auth: { token }, transports: ['websocket'] });
  }
  return socket;
}

export function closeSocket() {
  socket?.disconnect();
  socket = null;
}

/**
 * Subscribe to live events from the backend: "reading", "device:status", "alert".
 * The handler always sees the latest closure.
 */
export function useLive(event, handler) {
  const ref = useRef(handler);
  useEffect(() => {
    ref.current = handler;
  });
  useEffect(() => {
    const s = getSocket();
    if (!s) return;
    const fn = (data) => ref.current(data);
    s.on(event, fn);
    return () => s.off(event, fn);
  }, [event]);
}
