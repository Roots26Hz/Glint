export const runtime = 'nodejs';
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { redirect } from "next/navigation";
import { prisma } from "@/lib/prisma";
import Link from "next/link";
import { LogOut, Users, Download, Activity, Globe } from "lucide-react";

export default async function AdminDashboard() {
  const session = await getServerSession(authOptions);

  if (!session) {
    redirect("/admin/login");
  }

  // Fetch Analytics Data
  const totalViews = await prisma.pageView.count();
  
  // Unique visitors based on distinct sessionIds
  const uniqueVisitorsRaw = await prisma.pageView.groupBy({
    by: ['sessionId'],
  });
  const uniqueVisitors = uniqueVisitorsRaw.length;

  const totalDownloads = await prisma.event.count({
    where: { type: "DOWNLOAD" }
  });

  // Top OS
  const osStats = await prisma.pageView.groupBy({
    by: ['os'],
    _count: { os: true },
    orderBy: { _count: { os: 'desc' } },
    take: 5,
  });

  // Top Browsers
  const browserStats = await prisma.pageView.groupBy({
    by: ['browser'],
    _count: { browser: true },
    orderBy: { _count: { browser: 'desc' } },
    take: 5,
  });

  return (
    <div className="min-h-screen bg-[#050505] p-6 lg:p-12 relative overflow-hidden">
      <div className="absolute top-0 right-0 w-[600px] h-[600px] bg-blue-500/[0.03] rounded-full blur-[120px] pointer-events-none" />
      
      <div className="max-w-7xl mx-auto relative z-10">
        <header className="flex flex-col md:flex-row items-start md:items-center justify-between mb-12 gap-4">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">Glint Analytics</h1>
            <p className="text-white/50 mt-1">Overview of your website traffic and downloads.</p>
          </div>
          
          <div className="flex items-center gap-4">
            <Link href="/" className="text-sm font-medium text-white/60 hover:text-white transition-colors">
              View Site
            </Link>
            <Link 
              href="/api/auth/signout"
              className="flex items-center gap-2 bg-white/5 hover:bg-white/10 px-4 py-2 rounded-xl text-sm font-medium transition-colors border border-white/10"
            >
              <LogOut className="w-4 h-4" />
              Sign Out
            </Link>
          </div>
        </header>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-12">
          {/* Stat Cards */}
          <div className="glass-card p-6 flex flex-col gap-4">
            <div className="flex items-center gap-3 text-white/60">
              <Activity className="w-5 h-5 text-blue-400" />
              <span className="font-medium">Total Page Views</span>
            </div>
            <div className="text-4xl font-bold">{totalViews}</div>
          </div>
          
          <div className="glass-card p-6 flex flex-col gap-4">
            <div className="flex items-center gap-3 text-white/60">
              <Users className="w-5 h-5 text-purple-400" />
              <span className="font-medium">Unique Visitors</span>
            </div>
            <div className="text-4xl font-bold">{uniqueVisitors}</div>
          </div>
          
          <div className="glass-card p-6 flex flex-col gap-4">
            <div className="flex items-center gap-3 text-white/60">
              <Download className="w-5 h-5 text-green-400" />
              <span className="font-medium">DMG Downloads</span>
            </div>
            <div className="text-4xl font-bold">{totalDownloads}</div>
          </div>
          
          <div className="glass-card p-6 flex flex-col gap-4">
            <div className="flex items-center gap-3 text-white/60">
              <Globe className="w-5 h-5 text-orange-400" />
              <span className="font-medium">Conversion Rate</span>
            </div>
            <div className="text-4xl font-bold">
              {uniqueVisitors > 0 ? Math.round((totalDownloads / uniqueVisitors) * 100) : 0}%
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="glass-card p-6">
            <h2 className="text-xl font-bold mb-6">Operating Systems</h2>
            <div className="flex flex-col gap-4">
              {osStats.map((stat, i) => (
                <div key={i} className="flex items-center justify-between">
                  <span className="text-white/80">{stat.os || "Unknown"}</span>
                  <span className="font-medium">{stat._count.os}</span>
                </div>
              ))}
              {osStats.length === 0 && <p className="text-white/40">No data available.</p>}
            </div>
          </div>
          
          <div className="glass-card p-6">
            <h2 className="text-xl font-bold mb-6">Browsers</h2>
            <div className="flex flex-col gap-4">
              {browserStats.map((stat, i) => (
                <div key={i} className="flex items-center justify-between">
                  <span className="text-white/80">{stat.browser || "Unknown"}</span>
                  <span className="font-medium">{stat._count.browser}</span>
                </div>
              ))}
              {browserStats.length === 0 && <p className="text-white/40">No data available.</p>}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
