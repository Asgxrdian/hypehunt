# M1 — One-time setup outside the code

## Supabase dashboard (required before testing auth)
1. **Disable email confirmation (spec D1):** Authentication → Sign In / Up
   → Email → turn OFF "Confirm email".
2. **Code-based reset email (spec D2):** Authentication → Emails →
   "Reset password" template → make the body show the one-time code:

   Your HyperHunt reset code is: {{ .Token }}

   (Remove or ignore the confirmation-link markup; the app expects the
   6-digit code, not a link.)

## Test accounts for the RLS isolation check
Create two accounts by signing up in the app (or via the dashboard):
test-a@<yourdomain> and test-b@<yourdomain>.

## Running the RLS isolation check (M1 exit test)
From `app/`, with env vars set (PowerShell shown):

    $env:SUPABASE_URL="https://<ref>.supabase.co"
    $env:SUPABASE_PUBLISHABLE_KEY="sb_publishable_..."
    $env:TEST_A_EMAIL="test-a@..."; $env:TEST_A_PASSWORD="..."
    $env:TEST_B_EMAIL="test-b@..."; $env:TEST_B_PASSWORD="..."
    dart run integration/rls_isolation_check.dart

Expect ALL CHECKS PASSED and exit code 0. Paste the output into the
M1 pull request description (Definition of Done #5).
