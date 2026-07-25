export const runtime = 'nodejs';
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";
import { cookies } from "next/headers";

export async function POST() {
  try {
    const cookieStore = await cookies();
    let sessionId = cookieStore.get("glint_session")?.value;
    
    if (!sessionId) {
      sessionId = `anon_${Date.now()}_${Math.random().toString(36).substring(7)}`;
      // Note: In Next 13+ setting cookies in API route needs specific handling or middleware. 
      // We will just log it with a new ID if none exists.
    }

    await prisma.event.create({
      data: {
        sessionId,
        type: "DOWNLOAD",
      }
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error tracking download:", error);
    return NextResponse.json({ error: "Failed to track download" }, { status: 500 });
  }
}
