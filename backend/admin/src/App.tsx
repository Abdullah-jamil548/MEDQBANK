import type { ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { getToken } from "./api";
import { Shell } from "./components/Shell";
import { CatalogPage } from "./pages/Catalog";
import { LoginPage } from "./pages/Login";
import { OverviewPage } from "./pages/Overview";
import { UsersPage } from "./pages/Users";

function RequireAuth({ children }: { children: ReactNode }) {
  if (!getToken()) return <Navigate to="/login" replace />;
  return children;
}

export default function App() {
  return (
    <BrowserRouter basename="/admin">
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          path="/"
          element={
            <RequireAuth>
              <Shell />
            </RequireAuth>
          }
        >
          <Route index element={<OverviewPage />} />
          <Route path="users" element={<UsersPage />} />
          <Route path="books" element={<CatalogPage kind="book" title="Books" />} />
          <Route path="past-papers" element={<CatalogPage kind="past_paper" title="Past papers" />} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
