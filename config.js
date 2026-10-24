// Bazaar till — backend configuration.
//
// Shares the "ledger" Supabase project with his other tills, but writes only
// to the bazaar_* tables, so the bazaar's takings never mix with the print
// shop's or the sales ledger's.
//
// The anon key is meant to be public — it grants nothing on its own. Row level
// security is what decides who can read and write.
window.BAZAAR_CONFIG = {
  supabaseUrl: 'https://snfukbofyadfrhuaggad.supabase.co',
  supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNuZnVrYm9meWFkZnJodWFnZ2FkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyNjY3NzUsImV4cCI6MjEwMzg0Mjc3NX0.VS7OJ0vTK97AITaiXcuoTE-cJ3-jdADT1fzniDtPTfo',

  // The shared team account, same as the ledger. Staff sign in with one access
  // code rather than their own login. This address is only a username — the
  // code is the secret and is never stored here.
  // Blank this out to run the till purely offline, with no sign-in at all.
  sharedEmail: 'team@projectdrex-sales.com'
};
