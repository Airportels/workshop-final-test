// Replace the two Supabase values after running supabase/schema.sql.
window.APP_CONFIG = {
  SUPABASE_URL: 'https://dkxxhojabangbjotesae.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRreHhob2phYmFuZ2Jqb3Rlc2FlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE4NTU2NDcsImV4cCI6MjA5NzQzMTY0N30.7qKe7pSasQQd8JB_YY3pnVIQp85yHLONLDnzZUqtlHA',
  FACILITATOR_PASSCODE: 'yuunoyo'   // soft gate for facilitator.html only
};
window.sbClient = (function () {
  let c = null;
  return function () {
    const { SUPABASE_URL, SUPABASE_ANON_KEY } = window.APP_CONFIG;
    const ready = /^https:\/\/[a-z0-9-]+\.supabase\.co/.test(SUPABASE_URL) &&
      !SUPABASE_URL.includes('YOUR-PROJECT') && SUPABASE_ANON_KEY.length > 20;
    if (!ready || !window.supabase) return null;
    if (!c) c = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    return c;
  };
})();
