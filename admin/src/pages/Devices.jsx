import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useLive } from '../live.js';
import { timeAgo, fmtNum } from '../format.js';
import { AlertBadges, ErrorBox, PageHeader, StatusBadge } from '../components/ui.jsx';
import RegisterDeviceDialog from '../components/RegisterDeviceDialog.jsx';

const FILTERS = [
  { value: '', label: 'All' },
  { value: 'online', label: 'Online' },
  { value: 'offline', label: 'Offline' },
  { value: 'alert', label: 'With alerts' },
  { value: 'unclaimed', label: 'Not set up' },
];

export default function Devices() {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [data, setData] = useState({ devices: [], total: 0, limit: 50 });
  const [error, setError] = useState(null);
  const [registering, setRegistering] = useState(false);

  const load = useCallback(async () => {
    try {
      setData(await api('/api/admin/devices', { query: { search, status, page } }));
      setError(null);
    } catch (e) {
      setError(e);
    }
  }, [search, status, page]);

  useEffect(() => {
    const t = setTimeout(load, 250);
    return () => clearTimeout(t);
  }, [load]);

  // Live values without refetching the whole list.
  useLive('reading', (r) => {
    setData((d) => ({
      ...d,
      devices: d.devices.map((dev) =>
        dev.deviceId === r.deviceId
          ? { ...dev, online: true, lastSeen: r.at, lastReading: { tds: r.tds, tdsIn: r.tdsIn, temp: r.temp, at: r.at } }
          : dev,
      ),
    }));
  });
  useLive('device:status', load);
  useLive('alert', load);

  const pages = Math.max(1, Math.ceil(data.total / data.limit));

  return (
    <>
      <PageHeader title="Purifiers">
        <button type="button" className="btn primary" onClick={() => setRegistering(true)}>
          + Register purifier
        </button>
      </PageHeader>

      <div className="toolbar">
        <label className="sr-only" htmlFor="search">Search</label>
        <input
          id="search"
          type="search"
          placeholder="Search device ID, name, customer or phone"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value);
            setPage(1);
          }}
        />
        <div className="segmented" role="group" aria-label="Status filter">
          {FILTERS.map((f) => (
            <button
              key={f.value}
              type="button"
              aria-pressed={status === f.value}
              className={status === f.value ? 'on' : ''}
              onClick={() => {
                setStatus(f.value);
                setPage(1);
              }}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      <ErrorBox error={error} />

      <section className="card flush">
        <table>
          <thead>
            <tr>
              <th>Purifier</th>
              <th>Customer</th>
              <th>Status</th>
              <th className="num">TDS</th>
              <th className="num">Input TDS</th>
              <th className="num">Temp</th>
              <th>Last seen</th>
            </tr>
          </thead>
          <tbody>
            {data.devices.map((d) => (
              <tr key={d.id}>
                <td>
                  <Link to={`/devices/${d.id}`}>{d.name}</Link>
                  <div className="muted small mono">{d.deviceId}{d.room ? ` · ${d.room}` : ''}</div>
                </td>
                <td>{d.owner ? <>{d.owner.name}<div className="muted small">{d.owner.phone}</div></> : <span className="muted">—</span>}</td>
                <td><div className="badges"><StatusBadge device={d} /><AlertBadges types={d.openAlerts.filter((t) => t !== 'offline')} /></div></td>
                <td className={`num strong ${d.openAlerts?.includes('high_tds') ? 'warn-text' : ''}`}>{fmtNum(d.lastReading?.tds, ' ppm')}</td>
                <td className="num">{fmtNum(d.lastReading?.tdsIn, ' ppm')}</td>
                <td className="num">{fmtNum(d.lastReading?.temp, ' °C')}</td>
                <td>{timeAgo(d.lastSeen)}</td>
              </tr>
            ))}
            {data.devices.length === 0 && (
              <tr>
                <td colSpan={7} className="muted center-text">No purifiers match.</td>
              </tr>
            )}
          </tbody>
        </table>
      </section>

      {pages > 1 && (
        <div className="pager">
          <button type="button" className="btn ghost small" disabled={page <= 1} onClick={() => setPage(page - 1)}>Previous</button>
          <span className="muted">Page {page} of {pages}</span>
          <button type="button" className="btn ghost small" disabled={page >= pages} onClick={() => setPage(page + 1)}>Next</button>
        </div>
      )}

      {registering && (
        <RegisterDeviceDialog
          onClose={() => {
            setRegistering(false);
            load();
          }}
        />
      )}
    </>
  );
}
