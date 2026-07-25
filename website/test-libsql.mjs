import { createClient } from "@libsql/client";

const libsql = createClient({
  url: "file:./dev.db",
});

async function main() {
  try {
    const res = await libsql.execute("SELECT 1;");
    console.log("SUCCESS! libsql:", res);
  } catch (err) {
    console.error("ERROR CAUGHT IN LIBSQL:");
    console.error(err);
  }
}
main();
