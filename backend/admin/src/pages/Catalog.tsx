import { FormEvent, useEffect, useState } from "react";
import { api, cacheGet, sizeLabel, type CatalogItem } from "../api";

export function CatalogPage({ kind, title }: { kind: "book" | "past_paper"; title: string }) {
  const [rows, setRows] = useState<CatalogItem[]>(() => cacheGet<CatalogItem[]>(`catalog_${kind}`) ?? []);
  const [q, setQ] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [editing, setEditing] = useState<CatalogItem | "new" | null>(null);
  const [confirm, setConfirm] = useState<CatalogItem | null>(null);

  async function load(search = q, force = false) {
    setError("");
    try {
      setRows(await api.catalog(kind, search, force));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load catalog");
    }
  }

  useEffect(() => {
    setQ("");
    const cached = cacheGet<CatalogItem[]>(`catalog_${kind}`);
    if (cached) setRows(cached);
    void load("", false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [kind]);

  return (
    <>
      <div className="page-head">
        <div>
          <p>Library</p>
          <h1>{title}</h1>
        </div>
        <div className="toolbar">
          <input
            placeholder="Search title, subject, id"
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
            Upload
          </button>
        </div>
      </div>
      {error ? <div className="error">{error}</div> : null}
      <div className="panel">
        {rows.length === 0 ? (
          <div className="empty">Nothing in this catalog yet. Upload a PDF to publish it to R2 and the app.</div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Title</th>
                <th>Subject</th>
                <th>Size</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((item) => (
                <tr key={item.book_id}>
                  <td>
                    <div>{item.title}</div>
                    <div className="mono" style={{ color: "var(--muted)", marginTop: 4 }}>
                      {item.book_id}
                    </div>
                  </td>
                  <td>{item.subject || "—"}</td>
                  <td>{sizeLabel(item.size_bytes)}</td>
                  <td>
                    <span className={item.is_active ? "pill pill-ok" : "pill pill-off"}>
                      {item.is_active ? "Published" : "Hidden"}
                    </span>
                  </td>
                  <td className="row-actions">
                    <button className="btn btn-ghost" type="button" onClick={() => setEditing(item)}>
                      Edit
                    </button>
                    <button className="btn btn-ghost" type="button" onClick={() => setConfirm(item)}>
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
        <CatalogDrawer
          kind={kind}
          item={editing === "new" ? null : editing}
          busy={busy}
          onClose={() => setEditing(null)}
          onSave={async (form) => {
            setBusy(true);
            try {
              if (editing === "new") await api.createCatalog(form);
              else await api.updateCatalog(editing.book_id, form);
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
        <div className="overlay" onClick={() => setConfirm(null)}>
          <div className="drawer" onClick={(e) => e.stopPropagation()}>
            <h2>Delete {kind === "past_paper" ? "past paper" : "book"}</h2>
            <p style={{ color: "var(--muted)" }}>
              This removes <strong>{confirm.title}</strong> from the database and deletes the PDF from Cloudflare R2.
            </p>
            <div className="drawer-actions">
              <button className="btn btn-ghost" type="button" onClick={() => setConfirm(null)}>
                Cancel
              </button>
              <button
                className="btn btn-danger"
                type="button"
                onClick={async () => {
                  try {
                    await api.deleteCatalog(confirm.book_id);
                    setConfirm(null);
                    await load();
                  } catch (err) {
                    setError(err instanceof Error ? err.message : "Delete failed");
                  }
                }}
              >
                Delete from DB and R2
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

function CatalogDrawer({
  kind,
  item,
  busy,
  onClose,
  onSave,
}: {
  kind: "book" | "past_paper";
  item: CatalogItem | null;
  busy: boolean;
  onClose: () => void;
  onSave: (form: FormData) => Promise<void>;
}) {
  const [title, setTitle] = useState(item?.title ?? "");
  const [author, setAuthor] = useState(item?.author ?? "");
  const [subject, setSubject] = useState(item?.subject ?? "");
  const [yearLabel, setYearLabel] = useState(item?.year_label ?? "");
  const [blurb, setBlurb] = useState(item?.blurb ?? "");
  const [isActive, setIsActive] = useState(item?.is_active ?? true);
  const [file, setFile] = useState<File | null>(null);

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!item && !file) return;
    const form = new FormData();
    form.set("title", title);
    form.set("author", author);
    form.set("subject", subject);
    form.set("year_label", yearLabel);
    form.set("blurb", blurb);
    form.set("content_kind", kind);
    form.set("is_active", String(isActive));
    if (file) form.set("file", file);
    await onSave(form);
  }

  return (
    <div className="overlay" onClick={onClose}>
      <form className="drawer" onClick={(e) => e.stopPropagation()} onSubmit={submit}>
        <h2>{item ? "Edit item" : "Upload PDF"}</h2>
        <label className="field">
          <span>Title</span>
          <input value={title} onChange={(e) => setTitle(e.target.value)} required />
        </label>
        <label className="field">
          <span>Author</span>
          <input value={author} onChange={(e) => setAuthor(e.target.value)} />
        </label>
        <label className="field">
          <span>Subject</span>
          <input value={subject} onChange={(e) => setSubject(e.target.value)} />
        </label>
        <label className="field">
          <span>Year / series</span>
          <input value={yearLabel} onChange={(e) => setYearLabel(e.target.value)} />
        </label>
        <label className="field">
          <span>Blurb</span>
          <textarea value={blurb} onChange={(e) => setBlurb(e.target.value)} rows={3} />
        </label>
        <label className="field">
          <span>{item ? "Replace PDF (optional)" : "PDF file"}</span>
          <div className="drop">
            <input
              type="file"
              accept="application/pdf,.pdf"
              required={!item}
              onChange={(e) => setFile(e.target.files?.[0] ?? null)}
            />
            {file ? <div style={{ marginTop: 8 }}>{file.name}</div> : null}
          </div>
        </label>
        <label className="field" style={{ gridAutoFlow: "column", alignItems: "center", justifyContent: "start" }}>
          <input checked={isActive} onChange={(e) => setIsActive(e.target.checked)} type="checkbox" />
          <span>Published in the app</span>
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
