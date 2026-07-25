import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient({ log: ["query", "error", "warn"] });

async function main() {
  try {
    const totalViews = await prisma.pageView.count();
    console.log("SUCCESS! totalViews:", totalViews);
  } catch (err) {
    console.error("ERROR CAUGHT:");
    console.log("Original error cause:", err.cause);
    console.log("Stack:", err.stack);
  } finally {
    await prisma.$disconnect();
  }
}
main();
