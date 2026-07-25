import { createClient } from "@libsql/client";

const libsql = createClient({
  url: "file:./dev.db",
});

async function main() {
  try {
    const res = await libsql.execute("SELECT 1;");
    console.log("SUCCESS! libsql res:", res);
  } catch (err) {
    console.error("ERROR CAUGHT:");
    console.log("Original error cause:", err.cause);
    console.log("Stack:", err.stack);
  }
}
main();
