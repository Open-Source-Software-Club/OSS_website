export const env = {
  SITE_URL: process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000",
  SUPABASE_URL: process.env.NEXT_PUBLIC_SUPABASE_URL || "",
  SUPABASE_ANON_KEY: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "",
  isCiOrSkip: Boolean(process.env.SKIP_ENV_VALIDATION),
};
