import { describe, expect, it } from "vitest";

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const configured = Boolean(supabaseUrl && supabaseKey);

describe("Supabase public configuration", () => {
  // This test needs a real project: it is skipped (not failed) until EXPO_PUBLIC_SUPABASE_URL and
  // EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY are set, e.g. in a local .env file (see supabase/README.md).
  it.skipIf(!configured)("reaches the authentication settings endpoint with the publishable key", async () => {
    expect(supabaseUrl, "EXPO_PUBLIC_SUPABASE_URL must be configured").toMatch(/^https:\/\/.+/);
    expect(supabaseKey, "EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY must be configured").toBeTruthy();

    const response = await fetch(`${supabaseUrl}/auth/v1/settings`, {
      headers: { apikey: supabaseKey ?? "" },
    });

    expect(response.status, "Supabase endpoint and publishable key must be accepted").toBe(200);
  });
});
