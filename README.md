# CarePulse HMS — Frontend

React + Vite frontend. It now calls the Express microservice backend (see `../README.md`) through the
Vite dev proxy (`/api` → `http://localhost:5000`). Start the backend first, then:

```bash
npm install
npm run dev     # http://localhost:5173
```

Set `VITE_API_BASE` to use a different API URL. Login uses JWT (token kept in `localStorage`).
Page access per role is enforced both in `src/App.jsx` (route guard) and on the server (RBAC).
