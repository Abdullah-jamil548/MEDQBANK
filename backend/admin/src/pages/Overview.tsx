import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { api, cacheGet, formatPkt, type Activity, type Stats } from "../api";

export function OverviewPage() {
  const [stats, setStats] = useState<Stats | null>(() => cacheGet<Stats>("stats"));
  const [activity, setActivity] = useState<Activity | null>(() => cacheGet<Activity>("activity"));
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    Promise.all([api.stats(), api.activity()])
      .then(([nextStats, nextActivity]) => {
        if (!alive) return;
        setStats(nextStats);
        setActivity(nextActivity);
      })
      .catch((err: Error) => {
        if (alive) setError(err.message);
      });
    return () => {
      alive = false;
    };
  }, []);

  const peak = activity?.hours.reduce((max, h) => Math.max(max, h.unique_users), 0) ?? 0;

  return (
    <>
      <div className="page-head">
        <div>
          <p>Overview</p>
          <h1>Operations</h1>
        </div>
      </div>
      {error ? <div className="error">{error}</div> : null}
      <div className="metrics">
        <div className="metric">
          <span>Users</span>
          <strong>{stats?.users_total ?? "—"}</strong>
        </div>
        <div className="metric">
          <span>Live now</span>
          <strong>{activity?.live_count ?? stats?.live_now ?? "—"}</strong>
        </div>
        <div className="metric">
          <span>Books</span>
          <strong>{stats?.books_total ?? "—"}</strong>
        </div>
        <div className="metric">
          <span>Past papers</span>
          <strong>{stats?.past_papers_total ?? "—"}</strong>
        </div>
      </div>
      <div className="split-2">
        <div className="panel" style={{ padding: 24 }}>
          <p style={{ margin: 0, fontFamily: "var(--mono)", fontSize: 11, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--muted)" }}>
            Peak activity · last 24h · PKT
          </p>
          <h2 style={{ margin: "8px 0 16px", letterSpacing: "-0.04em" }}>Unique users by hour</h2>
          {activity && peak === 0 ? (
            <div className="empty" style={{ padding: 24 }}>
              No hourly activity yet. Counts grow as students heartbeat or chat.
            </div>
          ) : (
            <div className="chart" aria-label="Peak activity by hour PKT">
              {(activity?.hours ?? []).map((hour) => {
                const pct = peak > 0 ? Math.max(8, (hour.unique_users / peak) * 100) : 8;
                return (
                  <div className="chart-bar" key={hour.hour_iso} title={`${hour.hour_label}: ${hour.unique_users} users`}>
                    <span className="fill" style={{ height: `${pct}%`, opacity: hour.unique_users ? 1 : 0.25 }} />
                    <small>{hour.hour_label.replace(" ", "")}</small>
                  </div>
                );
              })}
            </div>
          )}
        </div>
        <div className="panel" style={{ padding: 24 }}>
          <p style={{ margin: 0, fontFamily: "var(--mono)", fontSize: 11, letterSpacing: "0.12em", textTransform: "uppercase", color: "var(--muted)" }}>
            Currently in the app
          </p>
          <h2 style={{ margin: "8px 0 8px", letterSpacing: "-0.04em" }}>
            {activity?.live_count ?? 0} live
          </h2>
          {!activity?.live_users.length ? (
            <div className="empty" style={{ padding: 16 }}>Nobody is online right now.</div>
          ) : (
            activity.live_users.map((user) => (
              <div className="live-row" key={user.user_id}>
                <div>
                  <div style={{ fontWeight: 700 }}>{user.full_name}</div>
                  <div className="mono" style={{ color: "var(--muted)", fontSize: 12 }}>{user.email}</div>
                </div>
                <div style={{ textAlign: "right" }}>
                  <span className="pill pill-ok">{user.socket_online ? "Socket" : "Heartbeat"}</span>
                  <div style={{ color: "var(--muted)", fontSize: 12, marginTop: 6 }}>{formatPkt(user.last_seen_at)}</div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>
      <div className="panel" style={{ padding: 24, marginTop: 16 }}>
        <p style={{ marginTop: 0, color: "var(--muted)" }}>
          Add students, set access until, and upload PDFs. Deleting a book or past paper removes the database row and the
          Cloudflare R2 objects.
        </p>
        <div className="row-actions">
          <Link className="btn btn-primary" to="/users">
            Manage users
          </Link>
          <Link className="btn btn-ghost" to="/books">
            Manage books
          </Link>
          <Link className="btn btn-ghost" to="/past-papers">
            Manage past papers
          </Link>
        </div>
      </div>
    </>
  );
}
