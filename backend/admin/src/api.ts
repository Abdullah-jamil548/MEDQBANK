const TOKEN_KEY = "medqbank_admin_token";
const CACHE_PREFIX = "mq_admin_cache_v1_";

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string | null): void {
  if (token) localStorage.setItem(TOKEN_KEY, token);
  else {
    localStorage.removeItem(TOKEN_KEY);
    clearAdminCache();
  }
}

export function cacheGet<T>(key: string): T | null {
  try {
    const raw = localStorage.getItem(CACHE_PREFIX + key);
    if (!raw) return null;
    return (JSON.parse(raw) as { data: T }).data;
  } catch {
    return null;
  }
}

export function cacheSet<T>(key: string, data: T): void {
  localStorage.setItem(CACHE_PREFIX + key, JSON.stringify({ at: Date.now(), data }));
}

export function clearAdminCache(prefix = ""): void {
  const keys: string[] = [];
  for (let i = 0; i < localStorage.length; i += 1) {
    const key = localStorage.key(i);
    if (key && key.startsWith(CACHE_PREFIX + prefix)) keys.push(key);
  }
  keys.forEach((key) => localStorage.removeItem(key));
}

async function cachedFetch<T>(key: string, fetcher: () => Promise<T>, force = false): Promise<T> {
  if (!force) {
    const hit = cacheGet<T>(key);
    if (hit !== null) return hit;
  }
  const data = await fetcher();
  cacheSet(key, data);
  return data;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  const token = getToken();
  if (token) headers.set("Authorization", `Bearer ${token}`);
  if (!(init.body instanceof FormData) && !headers.has("Content-Type") && init.body) {
    headers.set("Content-Type", "application/json");
  }
  const res = await fetch(path, { ...init, headers });
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  let data: unknown = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = { detail: text };
    }
  }
  if (!res.ok) {
    const detail =
      typeof data === "object" && data && "detail" in data
        ? String((data as { detail: unknown }).detail)
        : `Request failed (${res.status})`;
    if (res.status === 401) setToken(null);
    throw new Error(detail);
  }
  return data as T;
}

export type User = {
  user_id: string;
  full_name: string;
  email: string;
  phone: string | null;
  is_active: boolean;
  subscription_expires_at: string | null;
  last_seen_at: string | null;
  created_at?: string;
};

export type CatalogItem = {
  book_id: string;
  title: string | null;
  author: string | null;
  subject: string | null;
  year_label: string | null;
  blurb: string | null;
  size_bytes: number | null;
  content_kind: string | null;
  is_active: boolean | null;
  r2_key: string | null;
};

export type Stats = {
  users_total: number;
  users_active: number;
  books_total: number;
  past_papers_total: number;
  live_now: number;
};

export type LiveUser = {
  user_id: string;
  full_name: string;
  email: string;
  last_seen_at: string | null;
  socket_online: boolean;
};

export type HourPoint = {
  hour_label: string;
  hour_iso: string;
  unique_users: number;
};

export type Activity = {
  live_count: number;
  live_users: LiveUser[];
  hours: HourPoint[];
};

export const api = {
  login: (email: string, password: string) =>
    request<{ access_token: string; email: string }>("/api/v1/admin/login", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    }),
  stats: (force = false) => cachedFetch("stats", () => request<Stats>("/api/v1/admin/stats"), force),
  activity: (force = false) =>
    cachedFetch("activity", () => request<Activity>("/api/v1/admin/activity"), force),
  users: (q = "", active?: boolean, force = false) => {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (active !== undefined) params.set("active", String(active));
    const qs = params.toString();
    const path = `/api/v1/admin/users${qs ? `?${qs}` : ""}`;
    if (q || active !== undefined) return request<User[]>(path);
    return cachedFetch("users", () => request<User[]>(path), force);
  },
  createUser: async (body: Record<string, unknown>) => {
    const row = await request<User>("/api/v1/admin/users", { method: "POST", body: JSON.stringify(body) });
    clearAdminCache();
    return row;
  },
  updateUser: async (id: string, body: Record<string, unknown>) => {
    const row = await request<User>(`/api/v1/admin/users/${id}`, { method: "PATCH", body: JSON.stringify(body) });
    clearAdminCache();
    return row;
  },
  deleteUser: async (id: string) => {
    await request<void>(`/api/v1/admin/users/${id}`, { method: "DELETE" });
    clearAdminCache();
  },
  catalog: (kind: "book" | "past_paper" | "all", q = "", force = false) => {
    const params = new URLSearchParams({ kind });
    if (q) params.set("q", q);
    const path = `/api/v1/admin/catalog?${params}`;
    if (q) return request<CatalogItem[]>(path);
    return cachedFetch(`catalog_${kind}`, () => request<CatalogItem[]>(path), force);
  },
  createCatalog: async (form: FormData) => {
    const row = await request<CatalogItem>("/api/v1/admin/catalog", { method: "POST", body: form });
    clearAdminCache();
    return row;
  },
  updateCatalog: async (id: string, form: FormData) => {
    const row = await request<CatalogItem>(`/api/v1/admin/catalog/${encodeURIComponent(id)}`, {
      method: "PATCH",
      body: form,
    });
    clearAdminCache();
    return row;
  },
  deleteCatalog: async (id: string) => {
    await request<void>(`/api/v1/admin/catalog/${encodeURIComponent(id)}`, { method: "DELETE" });
    clearAdminCache();
  },
};

export function toPktInput(iso?: string | null): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const pkt = new Date(d.getTime() + 5 * 60 * 60 * 1000);
  return pkt.toISOString().slice(0, 16);
}

export function fromPktInput(value: string): string | null {
  if (!value) return null;
  const d = new Date(`${value}:00+05:00`);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

export function formatPkt(iso?: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  const pkt = new Date(d.getTime() + 5 * 60 * 60 * 1000);
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  const day = pkt.getUTCDate();
  const mon = months[pkt.getUTCMonth()];
  const year = pkt.getUTCFullYear();
  let hours = pkt.getUTCHours();
  const mins = String(pkt.getUTCMinutes()).padStart(2, "0");
  const ampm = hours >= 12 ? "PM" : "AM";
  hours = hours % 12 || 12;
  return `${day} ${mon} ${year}, ${hours}:${mins} ${ampm} PKT`;
}

export function sizeLabel(bytes?: number | null): string {
  if (!bytes || bytes <= 0) return "—";
  if (bytes < 1024 * 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
