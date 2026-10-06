import { Books, ChartLine, SignOut, Users } from "@phosphor-icons/react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import { setToken } from "../api";

const links = [
  { to: "/", label: "Overview", icon: ChartLine, end: true },
  { to: "/users", label: "Users", icon: Users },
  { to: "/books", label: "Books", icon: Books },
  { to: "/past-papers", label: "Past papers", icon: Books },
];

export function Shell() {
  const navigate = useNavigate();
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <small>Operations</small>
          <strong>MedQBank</strong>
        </div>
        <nav className="nav">
          {links.map((link) => (
            <NavLink key={link.to} to={link.to} end={link.end} className={({ isActive }) => (isActive ? "active" : "")}>
              <link.icon size={18} weight="light" />
              {link.label}
            </NavLink>
          ))}
        </nav>
        <div className="sidebar-foot">
          <button
            type="button"
            onClick={() => {
              setToken(null);
              navigate("/login");
            }}
          >
            <SignOut size={16} weight="light" /> Sign out
          </button>
        </div>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
