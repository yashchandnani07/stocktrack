import path from "node:path";
import { loadEnv } from "vite";
import { defineConfig } from "vitest/config";

// Mirrors the "@/*" -> "./*" path mapping in tsconfig.json so pure modules under src/ can be unit-tested
// with the same import style the app uses, instead of every test needing relative-path workarounds.
export default defineConfig(({ mode }) => {
  // Vite only loads .env into process.env for its own dev server by default; tests need it explicitly so
  // tests/supabase.connection.test.ts can pick up EXPO_PUBLIC_SUPABASE_* from a local .env file.
  Object.assign(process.env, loadEnv(mode, process.cwd(), ""));
  return {
    resolve: {
      alias: {
        "@": path.resolve(__dirname, "."),
      },
    },
  };
});
