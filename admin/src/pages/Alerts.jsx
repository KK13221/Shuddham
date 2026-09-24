import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api.js';
import { useLive } from '../live.js';
import { fmtDateTime, timeAgo, ALERT_LABEL } from '../format.js';
import { ErrorBox, PageHeader } from '../components/ui.jsx';

export default function Alerts() {
  const [status, setStatus] = useState('open');
  const [type, setType] = useState('');
  const [page, setPage] = useState(1);
  const [data, setData] = useState({ alerts: [], total: 0, limit: 50 });
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      setData(await api('/api/admin/alerts', { query: { status, type, page } }));
      setError(null);
    } catch (e) {
      setError(e);
    }
  }, [status, type, page]);

  useEffect(() => {
    load();
  }, [load]);
  useLive('alert', load);

  async function ack(id) {
    try {
      await api(`/api/admin/alerts/${id}/ack`, { method: 'POST' });
      load();
    } catch (e) {
      setError(e);
    }
  }

  const pages = Math.max(1, Math.ceil(data.total / data.limit));

  return (
    <>
      <PageHeader title="Alerts" />
      <div className="toolbar">
        <div className="segmented" role="group" aria-label="Status">
          {[['open', 'Open'], ['resolved', 'Resolved'], ['', 'All']].map(([v, l]) => (
            <button key={l} type="button" aria-pressed={status === v} className={status === v ? 'on' : ''} onClick={() => { setStatus(v); setPage(1); }}>{l}</button>
          ))}
        </div>
        <div className="segmented" role="group" aria-label="Type">
          {[['', 'All types'], ['high_tds', 'High TDS'], ['offline', 'Offline']].map(([v, l]) => (
            <button key={l} type="button" aria-pressed={type === v} className={type === v ? 'on' : ''} onClick={() => { setType(v); setPage(1); }}>{l}</button>
          ))}
        </div>
      </div>
      <ErrorBox error={error} />

      <section className="card flush">
        <table>
          <thead>
            <tr>
              <th>Type</th>
              <th>Purifier</th>
              <th>Customer</th>
              <th>TDS</th>
              <th>Opened</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {data.alerts.map((a) => (
              <tr key={a._id}>
                <td><span className={`badge ${a.type === 'high_tds' ? 'warn' : 'bad'}`}>{ALERT_LABEL[a.type]}</span></td>
                <td>
                  {a.device ? <Link to={`/devices/${a.device._id}`}>{a.device.name}</Link> : a.deviceId}
                  <div className="muted small mono">{a.deviceId}</div>
                </td>
                <td>{a.owner ? <>{a.owner.name}<div className="muted small">{a.owner.phone}</div></> : '—'}</td>
                <td>{a.type === 'high_tds' ? `${a.peak ?? a.value} ppm / ${a.limit}` : '—'}</td>
                <td title={fmtDateTime(a.openedAt)}>{timeAgo(a.openedAt)}</td>
                <td>{a.status === 'open' ? 'Open' : `Resolved ${timeAgo(a.resolvedAt)}`}</td>
                <td className="right">
                  {a.acknowledged ? (
                    <span className="muted small">Acknowledged</span>
                  ) : (
                    <button type="button" className="btn ghost small" onClick={() => ack(a._id)}>Acknowledge</button>
                  )}
                </td>
              </tr>
            ))}
            {data.alerts.length === 0 && (
              <tr><td colSpan={7} className="muted center-text">No alerts.</td></tr>
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
    </>
  );
}
