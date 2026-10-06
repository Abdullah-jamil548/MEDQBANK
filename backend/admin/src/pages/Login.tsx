import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { api, setToken } from "../api";

export function LoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError("");
    try {
      const res = await api.login(email, password);
      setToken(res.access_token);
      navigate("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Login failed");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="login-wrap">
      <section className="login-panel">
        <div>
          <div className="login-kicker">MedQBank console</div>
          <h1>Catalog and access control.</h1>
          <p>Provision students, extend subscriptions, and publish books or past papers to Cloudflare R2.</p>
        </div>
        <div className="login-kicker">Internal use only</div>
      </section>
      <form className="login-form" onSubmit={onSubmit}>
        <h2>Sign in</h2>
        <p style={{ color: "var(--muted)", marginTop: 0 }}>Use the admin credentials from the server environment.</p>
        <label className="field">
          <span>Email</span>
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required autoComplete="username" />
        </label>
        <label className="field">
          <span>Password</span>
          <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required autoComplete="current-password" />
        </label>
        {error ? <div className="error">{error}</div> : null}
        <button className="btn btn-primary btn-wide" disabled={busy} type="submit">
          {busy ? "Signing in…" : "Continue"}
        </button>
      </form>
    </div>
  );
}
