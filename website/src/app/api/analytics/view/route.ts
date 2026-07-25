import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request) {
  try {
    const { path, sessionId } = await req.json();
    
    // Create or update session
    await prisma.session.upsert({
      where: { id: sessionId },
      update: {
        updatedAt: new Date()
      },
      create: {
        id: sessionId
      }
    });

    // Parse user agent (simplified)
    const userAgent = req.headers.get("user-agent") || "";
    let browser = "Unknown";
    let os = "Unknown";
    let device = "Desktop";

    if (userAgent.includes("Mac OS")) os = "macOS";
    else if (userAgent.includes("Windows")) os = "Windows";
    else if (userAgent.includes("Linux")) os = "Linux";
    else if (userAgent.includes("iPhone") || userAgent.includes("iPad")) {
      os = "iOS";
      device = "Mobile";
    }
    else if (userAgent.includes("Android")) {
      os = "Android";
      device = "Mobile";
    }

    if (userAgent.includes("Chrome")) browser = "Chrome";
    else if (userAgent.includes("Safari") && !userAgent.includes("Chrome")) browser = "Safari";
    else if (userAgent.includes("Firefox")) browser = "Firefox";

    await prisma.pageView.create({
      data: {
        sessionId,
        path,
        browser,
        os,
        device
      }
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error tracking view:", error);
    return NextResponse.json({ error: "Failed to track view" }, { status: 500 });
  }
}
