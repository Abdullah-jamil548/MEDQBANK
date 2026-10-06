import { FormEvent, useEffect, useMemo, useState } from "react";
import { api, cacheGet, formatPkt, fromPktInput, toPktInput, type User } from "../api";

export function UsersPage() {
  const [rows, setRows] = useState<User[]>(() => cacheGet<User[]>("users") ?? []);
  const [q, setQ] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState<User | "new" | null>(null);
  const [confirm, setConfirm] = useState<User | null>(null);

  async function load(search = q, force = false) {
    setError("");
    try {
      setRows(await api.users(search, undefined, force));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load users");
    }
  }

  useEffect(() => {
    void load("", false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <>
      <div className="page-head">
        <div>
          <p>Directory</p>
          <h1>Users</h1>
        </div>
        <div className="toolbar">
          <input
            placeholder="Search name or email"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") void load();
            }}
          />
          <button className="btn btn-ghost" type="button" onClick={() => void load(q, true)}>
            Search
          </button>
          <button className="btn btn-primary" type="button" onClick={() => setEditing("new")}>
            Add user
          </button>
        </div>
      </div>
      {error ? <div className="error">{error}</div> : null}
      <div className="panel">
        {rows.length === 0 ? (
          <div className="empty">No users yet. Add a student to grant app access.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Status</th>
                <th>Access until</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((user) => (
                <tr key={user.user_id}>
                  <td>{user.full_name}</td>
                  <td>{user.email}</td>
                  <td>
                    <span className={user.is_active ? "pill pill-ok" : "pill pill-off"}>
                      {user.is_active ? "Active" : "Disabled"}
                    </span>
                  </td>
                  <td>{formatPkt(user.subscription_expires_at)}</td>
                  <td className="row-actions">
                    <button className="btn btn-ghost" type="button" onClick={() => setEditing(user)}>
                      Edit
                    </button>
                    <button className="btn btn-ghost" type="button" onClick={() => setConfirm(user)}>
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
      {editing ? (
        <UserDrawer
          user={editing === "new" ? null : editing}
          busy={busy}
          onClose={() => setEditing(null)}
          onSave={async (payload) => {
            setBusy(true);
            try {
              if (editing === "new") await api.createUser(payload);
              else await api.updateUser(editing.user_id, payload);
              setEditing(null);
              await load();
            } catch (err) {
              setError(err instanceof Error ? err.message : "Save failed");
            } finally {
              setBusy(false);
            }
          }}
        />
      ) : null}
      {confirm ? (
        <ConfirmModal
          title="Delete user"
          body={`Remove ${confirm.full_name} from the database? This cannot be undone.`}
          onCancel={() => setConfirm(null)}
          onConfirm={async () => {
            try {
              await api.deleteUser(confirm.user_id);
              setConfirm(null);
              await load();
            } catch (err) {
              setError(err instanceof Error ? err.message : "Delete failed");
            }
          }}
        />
      ) : null}
    </>
  );
}

function ConfirmModal({
  title,
  body,
  onCancel,
  onConfirm,
}: {
  title: string;
  body: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <div className="overlay" onClick={onCancel}>
      <div className="drawer" onClick={(e) => e.stopPropagation()}>
        <h2>{title}</h2>
        <p style={{ color: "var(--muted)" }}>{body}</p>
        <div className="drawer-actions">
          <button className="btn btn-ghost" type="button" onClick={onCancel}>
            Cancel
          </button>
          <button className="btn btn-danger" type="button" onClick={onConfirm}>
            Delete
          </button>
        </div>
      </div>
    </div>
  );
}

function UserDrawer({
  user,
  busy,
  onClose,
  onSave,
}: {
  user: User | null;
  busy: boolean;
  onClose: () => void;
  onSave: (payload: Record<string, unknown>) => Promise<void>;
}) {
  const [fullName, setFullName] = useState(user?.full_name ?? "");
  const [email, setEmail] = useState(user?.email ?? "");
  const [phone, setPhone] = useState(user?.phone ?? "");
  const [password, setPassword] = useState("");
  const [isActive, setIsActive] = useState(user?.is_active ?? true);
  const [accessUntil, setAccessUntil] = useState(toPktInput(user?.subscription_expires_at));

  const title = useMemo(() => (user ? "Edit user" : "Add user"), [user]);

  async function submit(e: FormEvent) {
    e.preventDefault();
    const payload: Record<string, unknown> = {
      full_name: fullName,
      email,
      phone: phone || null,
      is_active: isActive,
      subscription_expires_at: fromPktInput(accessUntil),
    };
    if (!user || password) payload.password = password;
    await onSave(payload);
  }

  return (
    <div className="overlay" onClick={onClose}>
      <form className="drawer" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
        <h2>{title}</h2>
        <label className="field">
          <span>Full name</span>
          <input value={fullName} onChange={(e) => setFullName(e.target.value)} required />
        </label>
        <label className="field">
          <span>Email</span>
          <input value={email} onChange={(e) => setEmail(e.target.value)} type="email" required />
        </label>
        <label className="field">
          <span>Phone</span>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} />
        </label>
        <label className="field">
          <span>{user ? "New password (optional)" : "Password"}</span>
          <input value={password} onChange={(e) => setPassword(e.target.value)} type="password" required={!user} minLength={6} />
        </label>
        <label className="field">
          <span>Access until (PKT)</span>
          <input value={accessUntil} onChange={(e) => setAccessUntil(e.target.value)} type="datetime-local" />
        </label>
        <label className="field" style={{ gridAutoFlow: "column", alignItems: "center", justifyContent: "start" }}>
          <input checked={isActive} onChange={(e) => setIsActive(e.target.checked)} type="checkbox" />
          <span>Active account</span>
        </label>
        <div className="drawer-actions">
          <button className="btn btn-ghost" type="button" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn-primary" disabled={busy} type="submit">
            {busy ? "Saving…" : "Save"}
          </button>
        </div>
      </form>
    </div>
  );
}
