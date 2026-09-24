import { useCallback, useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import {
  CartesianGrid,
  Line,
  LineChart,
  ReferenceLine,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { api } from '../api.js';
import { useLive } from '../live.js';
import { fmtDateTime, fmtNum, timeAgo, ALERT_LABEL } from '../format.js';
import { ErrorBox, PageHeader, Stat, StatusBadge } from '../components/ui.jsx';

const RANGES = ['24h', '7d', '30d'];
const METRICS = [
  { key: 'tds', label: 'TDS (purified)', unit: 'ppm', color: '#1553B8' },
  { key: 'temp', label: 'Water temperature', unit: '°C', color: '#0F2A5C' },
];

function tickFormatter(range) {
  return (t) => {
    const d = new Date(t);
    return range === '24h'
      ? d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
      : d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
  };
}

export default function DeviceDetail() {
  const { id } = useParams();
  const [info, setInfo] = useState(null);
  const [history, setHistory] = useState(null);
  const [range, setRange] = useState('24h');
  const [metric, setMetric] = useState('tds');
  const [error, setError] = useState(null);

  const loadInfo = useCallback(async () => {
    try {
      setInfo(await api(`/api/admin/devices/${id}`));
    } catch (e) {
      setError(e);
    }
  }, [id]);

  const loadHistory = useCallback(async () => {
    try {
      setHistory(await api(`/api/admin/devices/${id}/readings`, { query: { range } }));
    } catch (e) {
      setError(e);
    }
  }, [id, range]);

  useEffect(() => {
    loadInfo();
  }, [loadInfo]);
  useEffect(() => {
    loadHistory();
  }, [loadHistory]);

  useLive('reading', (r) => {
    if (r.deviceId !== info?.device.deviceId) return;
    setInfo((cur) => cur && { ...cur, device: { ...cur.device, online: true, lastSeen: r.at, lastReading: { ...r } } });
  });
  useLive('alert', (e) => {
    if (e.alert?.deviceId === info?.device.deviceId) loadInfo();
  });

  if (!info) return error ? <ErrorBox error={error} /> : <p className="muted">Loading…</p>;
  const d = info.device;
  const limit = d.tdsLimit ?? info.defaultTdsLimit;
  const m = METRICS.find((x) => x.key === metric);
  const reading = d.lastReading;
  const rejection = reading?.tdsIn > 0 && typeof reading?.tds === 'number' ? Math.round((1 - reading.tds / reading.tdsIn) * 100) : null;

  return (
    <>
      <p className="crumbs"><Link to="/devices">Purifiers</Link> / {d.deviceId}</p>
      <PageHeader title={d.name}>
        <StatusBadge device={d} />
      </PageHeader>
      <ErrorBox error={error} />

      <section className="stats">
        <Stat label="TDS (purified)" value={fmtNum(reading?.tds, ' ppm')} tone={reading?.tds > limit ? 'warn' : ''} />
        <Stat label="Input TDS" value={fmtNum(reading?.tdsIn, ' ppm')} />
        <Stat label="Removed" value={rejection === null ? '—' : `${rejection}%`} />
        <Stat label="Water temp" value={fmtNum(reading?.temp, ' °C')} />
        <Stat label="Last seen" value={timeAgo(d.lastSeen)} />
      </section>

      <section className="card">
        <div className="card-head">
          <div className="segmented" role="group" aria-label="Metric">
            {METRICS.map((x) => (
              <button key={x.key} type="button" aria-pressed={metric === x.key} className={metric === x.key ? 'on' : ''} onClick={() => setMetric(x.key)}>
                {x.label}
              </button>
            ))}
          </div>
          <div className="segmented" role="group" aria-label="Range">
            {RANGES.map((r) => (
              <button key={r} type="button" aria-pressed={range === r} className={range === r ? 'on' : ''} onClick={() => setRange(r)}>
                {r}
              </button>
            ))}
          </div>
        </div>
        {history?.points.length ? (
          <div className="chart">
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={history.points} margin={{ top: 16, right: 24, bottom: 8, left: 0 }}>
                <CartesianGrid stroke="#E9EEF5" vertical={false} />
                <XAxis dataKey="t" tickFormatter={tickFormatter(range)} stroke="#56627A" fontSize={12} minTickGap={32} />
                <YAxis stroke="#56627A" fontSize={12} width={48} unit={metric === 'tds' ? '' : '°'} domain={metric === 'tds' ? [0, (max) => Math.ceil(Math.max(max, limit) * 1.1)] : ['auto', 'auto']} />
                <Tooltip
                  labelFormatter={(t) => fmtDateTime(t)}
                  formatter={(v) => [`${v} ${m.unit}`, m.label]}
                />
                {metric === 'tds' && (
                  <ReferenceLine y={limit} stroke="#D97706" strokeDasharray="6 4" label={{ value: `Alert ${limit} ppm`, position: 'insideTopRight', fill: '#9A4A0B', fontSize: 12 }} />
                )}
                <Line type="monotone" dataKey={metric} stroke={m.color} strokeWidth={2.5} dot={false} connectNulls />
              </LineChart>
            </ResponsiveContainer>
          </div>
        ) : (
          <p className="muted">No readings in this period.</p>
        )}
      </section>

      <div className="two-col">
        <section className="card">
          <h2>Details</h2>
          <dl className="details">
            <dt>Device ID</dt><dd className="mono">{d.deviceId}</dd>
            <dt>Customer</dt><dd>{d.owner ? `${d.owner.name} · ${d.owner.phone}` : 'Not set up'}</dd>
            <dt>Room</dt><dd>{d.room || '—'}</dd>
            <dt>TDS alert limit</dt><dd>{limit} ppm{d.tdsLimit ? '' : ' (default)'}</dd>
            <dt>Firmware</dt><dd>{d.firmware || '—'}</dd>
            <dt>Linked on</dt><dd>{fmtDateTime(d.claimedAt)}</dd>
            <dt>Registered</dt><dd>{fmtDateTime(d.createdAt)}</dd>
          </dl>
        </section>
        <section className="card">
          <h2>Recent alerts</h2>
          {info.alerts.length === 0 ? (
            <p className="muted">No alerts yet.</p>
          ) : (
            <ul className="alert-list">
              {info.alerts.map((a) => (
                <li key={a._id}>
                  <span className={`badge ${a.status === 'open' ? (a.type === 'high_tds' ? 'warn' : 'bad') : 'neutral'}`}>{ALERT_LABEL[a.type]}</span>
                  <span>{a.type === 'high_tds' ? `${a.peak ?? a.value} ppm` : ''}</span>
                  <span className="muted small">{fmtDateTime(a.openedAt)}{a.resolvedAt ? ` → ${fmtDateTime(a.resolvedAt)}` : ' · open'}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </>
  );
}
