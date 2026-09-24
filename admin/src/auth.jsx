import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, getToken, setToken } from './api.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setTok] = useState(getToken());
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(!!getToken());

  const logout = useCallback(() => {
    setToken(null);
    setTok(null);
    setUser(null);
  }, []);

  useEffect(() => {
    const onLogout = () => logout();
    window.addEventListener('shuddham:logout', onLogout);
    return () => window.removeEventListener('shuddham:logout', onLogout);
  }, [logout]);

  useEffect(() => {
    if (!token) return;
    api('/api/me')
      .then(({ user }) => {
        if (user.role !== 'admin') logout();
        else setUser(user);
      })
      .catch(() => logout())
      .finally(() => setLoading(false));
  }, [token, logout]);

  const login = useCallback(async (email, password) => {
    const { token, user } = await api('/api/auth/admin/login', { method: 'POST', body: { email, password } });
    setToken(token);
    setTok(token);
    setUser(user);
  }, []);

  const value = useMemo(() => ({ token, user, loading, login, logout }), [token, user, loading, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  return useContext(AuthContext);
}
