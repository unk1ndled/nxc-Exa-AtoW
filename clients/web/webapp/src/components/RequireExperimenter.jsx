import { useEffect } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { useAuth } from "../hooks/useAuth";

// Gate for the notebook. Admins are accepted too — they can use it to drive
// any session as the owner. Anyone without a valid token is bounced to
// /login?mode=experimenter so the form defaults to token-paste.
export default function RequireExperimenter({ children }) {
  const { isExperimenter, checking } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  useEffect(() => {
    if (!checking && !isExperimenter) {
      navigate(
        `/login?mode=experimenter&next=${encodeURIComponent(location.pathname)}`,
        { replace: true },
      );
    }
  }, [checking, isExperimenter, navigate, location.pathname]);

  if (checking)
    return (
      <div className="bg-paper text-ink min-h-screen font-mono flex items-center justify-center">
        <span className="text-[11px] text-muted tracking-wider animate-pulse">
          verifying…
        </span>
      </div>
    );

  return isExperimenter ? children : null;
}
