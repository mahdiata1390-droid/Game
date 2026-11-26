import type { CapacitorConfig } from "@capacitor/cli";

// Android wrapper for the Forge Engine game. The whole game is bundled into
// android/app/src/main/assets/public by `npx cap sync android`, so the installed
// app runs completely offline from the WebView's local files.
const config: CapacitorConfig = {
  appId: "com.mahdiata1390.medievalsandbox",
  appName: "Medieval Sandbox",
  webDir: "dist",
  android: {
    // The game ships no remote content; keep the WebView locked down.
    allowMixedContent: false,
    backgroundColor: "#0b0d10",
    webContentsDebuggingEnabled: false,
  },
  server: {
    androidScheme: "https",
  },
};

export default config;
