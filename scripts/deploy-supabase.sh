#!/usr/bin/env bash
set -euo pipefail

# One-command local Supabase setup: pushes all 3 migrations, sets GEMINI_API_KEY,
# and deploys the `scan-bill` Edge Function.
#
# Required env vars:
#   SUPABASE_ACCESS_TOKEN  (from https://supabase.com/dashboard/account/tokens)
#   SUPABASE_PROJECT_REF   (20-char project ref, e.g. abcdefghijklmnopqrst)
#   SUPABASE_DB_PASSWORD   (database password set when creating the project)
#   GEMINI_API_KEY         (from https://aistudio.google.com/apikey)

for var in SUPABASE_ACCESS_TOKEN SUPABASE_PROJECT_REF SUPABASE_DB_PASSWORD GEMINI_API_KEY; do
  if [ -z "${!var:-}" ]; then
    echo "Error: missing required environment variable: $var" >&2
    exit 1
  fi
done

if command -v supabase >/dev/null 2>&1; then
  SUPA=(supabase)
else
  SUPA=(npx --yes supabase)
fi

echo "1/3 Linking project ${SUPABASE_PROJECT_REF}..."
"${SUPA[@]}" link --project-ref "$SUPABASE_PROJECT_REF" --password "$SUPABASE_DB_PASSWORD"

echo "2/3 Pushing SQL migrations (001..003)..."
"${SUPA[@]}" db push

echo "3/3 Setting GEMINI_API_KEY & deploying Edge Function scan-bill..."
"${SUPA[@]}" secrets set "GEMINI_API_KEY=${GEMINI_API_KEY}" --project-ref "$SUPABASE_PROJECT_REF"
"${SUPA[@]}" functions deploy scan-bill --project-ref "$SUPABASE_PROJECT_REF" --no-verify-jwt

echo "Done! Supabase Cloud Sync + AI OCR (scan-bill) is live."
