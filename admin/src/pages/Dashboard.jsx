import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useLive } from '../live.js';
import { timeAgo, ALERT_LABEL } from '../format.js';
import { ErrorBox, PageHeader, Stat } from '../components/ui.jsx';

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [alerts, setAlerts] = useState([]);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      const [s, a] = await Promise.all([api('/api/admin/stats'), api('/api/admin/alerts', { query: { status: 'open' } })]);
      setStats(s);
      setAlerts(a.alerts.slice(0, 8));
      setError(null);
    } catch (e) {
      setError(e);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);
  useLive('alert', load);
  useLive('device:status', load);

  return (
    <>
      <PageHeader title="Dashboard" />
      <ErrorBox error={error} />
      <section className="stats">
        <Stat label="Purifiers" value={stats?.devices} />
        <Stat label="Online" value={stats?.online} tone="ok" />
        <Stat label="Offline" value={stats?.offline} tone={stats?.offline ? 'bad' : ''} />
        <Stat label="High TDS now" value={stats?.openAlerts.highTds} tone={stats?.openAlerts.highTds ? 'warn' : ''} />
        <Stat label="Customers" value={stats?.users} />
      </section>

      <section className="card">
        <div className="card-head">
          <h2>Open alerts</h2>
          <Link to="/alerts">See all</Link>
        </div>
        {alerts.length === 0 ? (
          <p className="muted">No open alerts. All purifiers are within range and online.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Type</th>
                <th>Purifier</th>
                <th>Customer</th>
                <th>Value</th>
                <th>Since</th>
              </tr>
            </thead>
            <tbody>
              {alerts.map((a) => (
                <tr key={a._id}>
                  <td><span className={`badge ${a.type === 'high_tds' ? 'warn' : 'bad'}`}>{ALERT_LABEL[a.type]}</span></td>
                  <td><Link to={`/devices/${a.device?._id || a.deviceId}`}>{a.device?.name || a.deviceId}</Link><div className="muted small">{a.deviceId}</div></td>
                  <td>{a.owner ? <>{a.owner.name}<div className="muted small">{a.owner.phone}</div></> : '—'}</td>
                  <td>{a.type === 'high_tds' ? `${a.peak ?? a.value} ppm (limit ${a.limit})` : '—'}</td>
                  <td>{timeAgo(a.openedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </>
  );
}
