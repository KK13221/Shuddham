export function timeAgo(date) {
  if (!date) return '—';
  const s = Math.round((Date.now() - new Date(date).getTime()) / 1000);
  if (s < 10) return 'just now';
  if (s < 60) return `${s}s ago`;
  const m = Math.round(s / 60);
  if (m < 60) return `${m} min ago`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} h ago`;
  return `${Math.round(h / 24)} d ago`;
}

export function fmtDateTime(date) {
  if (!date) return '—';
  return new Date(date).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export const fmtNum = (v, unit = '') => (typeof v === 'number' ? `${v}${unit}` : '—');

export const ALERT_LABEL = { high_tds: 'High TDS', offline: 'Offline' };
