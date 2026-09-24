# Shuddham admin panel

React (Vite) panel for the Shuddham team.

- **Dashboard:** purifier counts (online / offline / high TDS) and open alerts, updating live.
- **Purifiers:** search by device ID, name, customer or phone; filter by status; live TDS, input TDS and temperature; **Register purifier** (factory registration shows the MQTT secret and setup code once).
- **Purifier detail:** TDS / temperature chart (24 h, 7 d, 30 d) with the alert limit line, details, alert history.
- **Alerts:** open/resolved, High TDS / Offline, acknowledge.

```bash
cp .env.example .env     # VITE_API_URL=http://localhost:4000
npm install
npm run dev              # http://localhost:5173
npm run build            # static files in dist/
```

Create an admin account with `npm run seed:admin -- <email> <password>` in `backend/`.
