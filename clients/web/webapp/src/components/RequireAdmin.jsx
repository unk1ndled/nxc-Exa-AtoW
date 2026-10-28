import { useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";

export default function RequireAdmin({ children }) {
  const { isAdmin, checking } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    if (!checking && !isAdmin) {
      navigate(`/login?next=${encodeURIComponent(location.pathname)}`, {
        replace: true,
      });
    }
  }, [checking, isAdmin, navigate, location.pathname]);

  if (checking)
    return (
      <div className="bg-paper text-ink min-h-screen font-mono flex items-center justify-center">
        <span className="text-[11px] text-muted tracking-wider animate-pulse">
          verifying…
        </span>
      </div>
    );

  return isAdmin ? children : null;
}
