import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter, Routes, Route } from "react-router-dom";
import "./index.css";
import LandingPage from "./pages/LandingPage.jsx";
import NotebookPage from "./pages/NotebookPage.jsx";
import MaintainerPage from "./pages/MaintainerPage.jsx";
import LoginPage from "./pages/LoginPage.jsx";
import RequireAdmin from "./components/RequireAdmin.jsx";
import RequireExperimenter from "./components/RequireExperimenter.jsx";

createRoot(document.getElementById("root")).render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<LandingPage />} />
      <Route
        path="/notebook"
        element={
          <RequireExperimenter>
            <NotebookPage />
          </RequireExperimenter>
        }
      />
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/maintainer"
        element={
          <RequireAdmin>
            <MaintainerPage />
          </RequireAdmin>
        }
      />
    </Routes>
  </BrowserRouter>,
);
