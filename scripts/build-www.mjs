// Copies the web app into www/ so Capacitor can bundle it inside the iPhone app.
import { cpSync, rmSync, mkdirSync } from "node:fs";
rmSync("www", { recursive: true, force: true });
mkdirSync("www");
for (const f of ["index.html", "privacy.html", "manifest.webmanifest", "icons"]) {
  cpSync(f, `www/${f}`, { recursive: true });
}
console.log("www/ ready");
