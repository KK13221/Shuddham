import { ALERT_LABEL } from '../format.js';

export function StatusBadge({ device }) {
  if (!device.owner && !device.online) return <span className="badge neutral">Not set up</span>;
  return device.online ? (
    <span className="badge ok"><span className="dot" />Online</span>
  ) : (
    <span className="badge bad"><span className="dot" />Offline</span>
  );
}

export function AlertBadges({ types = [] }) {
  return types.map((t) => (
    <span key={t} className={`badge ${t === 'high_tds' ? 'warn' : 'bad'}`}>{ALERT_LABEL[t] || t}</span>
  ));
}

export function Stat({ label, value, tone }) {
  return (
    <div className={`stat ${tone || ''}`}>
      <span className="stat-label">{label}</span>
      <span className="stat-value">{value ?? '—'}</span>
    </div>
  );
}

export function PageHeader({ title, children }) {
  return (
    <header className="page-header">
      <h1>{title}</h1>
      <div className="page-actions">{children}</div>
    </header>
  );
}

export function ErrorBox({ error }) {
  if (!error) return null;
  return <div className="error-box" role="alert">{error.message || String(error)}</div>;
}
