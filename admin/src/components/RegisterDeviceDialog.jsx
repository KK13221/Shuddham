import { useEffect, useRef, useState } from 'react';
import { api } from '../api.js';

/** Factory registration: creates the device and shows its secret + setup code once. */
export default function RegisterDeviceDialog({ onClose }) {
  const ref = useRef(null);
  const [deviceId, setDeviceId] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    ref.current?.showModal();
  }, []);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setError('');
    try {
      setResult(await api('/api/admin/devices', { method: 'POST', body: { deviceId } }));
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <dialog ref={ref} className="dialog" onClose={onClose}>
      {!result ? (
        <form onSubmit={submit}>
          <h2>Register purifier</h2>
          <p className="muted">Use the ID the firmware advertises over Bluetooth (for example SHD-A4F2C1).</p>
          <label htmlFor="deviceId">Device ID</label>
          <input
            id="deviceId"
            className="mono"
            required
            pattern="[A-Za-z0-9-]{4,32}"
            value={deviceId}
            onChange={(e) => setDeviceId(e.target.value.toUpperCase())}
            autoFocus
          />
          {error && <div className="error-box" role="alert">{error}</div>}
          <div className="dialog-actions">
            <button type="button" className="btn ghost" onClick={() => ref.current.close()}>Cancel</button>
            <button type="submit" className="btn primary" disabled={busy}>{busy ? 'Registering…' : 'Register'}</button>
          </div>
        </form>
      ) : (
        <div>
          <h2>{result.device.deviceId} registered</h2>
          <p className="warn-text">Copy these now. They are shown only once.</p>
          <dl className="secrets">
            <dt>MQTT secret (flash into firmware)</dt>
            <dd className="mono">{result.secret}</dd>
            <dt>Setup code (print on the label / QR)</dt>
            <dd className="mono big">{result.setupCode}</dd>
          </dl>
          <div className="dialog-actions">
            <button
              type="button"
              className="btn ghost"
              onClick={() => navigator.clipboard?.writeText(JSON.stringify({ deviceId: result.device.deviceId, secret: result.secret, setupCode: result.setupCode }))}
            >
              Copy as JSON
            </button>
            <button type="button" className="btn primary" onClick={() => ref.current.close()}>Done</button>
          </div>
        </div>
      )}
    </dialog>
  );
}
