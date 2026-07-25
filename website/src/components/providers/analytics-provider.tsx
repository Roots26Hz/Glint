"use client";

import { useEffect } from "react";
import { usePathname } from "next/navigation";

export function AnalyticsProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  useEffect(() => {
    // Generate or get a simple session ID
    let sessionId = localStorage.getItem("glint_session_id");
    if (!sessionId) {
      sessionId = `anon_${Date.now()}_${Math.random().toString(36).substring(2, 15)}`;
      localStorage.setItem("glint_session_id", sessionId);
    }
    
    // Set a cookie so the download API route can access it easily too
    document.cookie = `glint_session=${sessionId}; path=/; max-age=31536000; SameSite=Lax`;

    // Ignore admin routes
    if (pathname?.startsWith("/admin")) return;

    fetch("/api/analytics/view", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: pathname || "/", sessionId })
    }).catch(console.error);
    
  }, [pathname]);

  return <>{children}</>;
}
