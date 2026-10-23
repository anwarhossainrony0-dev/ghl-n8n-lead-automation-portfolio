#!/usr/bin/env bash
# Post a test payload to the v2 n8n webhook.
#
# Usage:
#   ./test-webhook.sh <payload> [--test]
#   ./test-webhook.sh test-payloads/hot.json           # production URL (workflow must be active)
#   ./test-webhook.sh hot --test                       # /webhook-test/ URL (click "Execute workflow" first)
#   WEBHOOK_URL=https://other-host/webhook/ghl-lead-v2 ./test-webhook.sh warm
#   WEBHOOK_SECRET=xyz ./test-webhook.sh hot           # sends header X-Webhook-Secret (optional hardening)
#
# <payload> can be a file path or a short name: hot, warm, cold, invalid, duplicate.
# The webhook answers 200 immediately; check n8n Executions, the sheet and Telegram for the result.
set -euo pipefail

BASE_URL="https://blueviolet-parrot-909837.hostingersite.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="webhook"
PAYLOAD=""

for arg in "$@"; do
  case "$arg" in
    --test) MODE="webhook-test" ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; exit 1 ;;
    *) PAYLOAD="$arg" ;;
  esac
done

if [[ -z "$PAYLOAD" ]]; then
  sed -n '2,12p' "$0" >&2
  exit 1
fi
if [[ ! -f "$PAYLOAD" && -f "$SCRIPT_DIR/test-payloads/$PAYLOAD.json" ]]; then
  PAYLOAD="$SCRIPT_DIR/test-payloads/$PAYLOAD.json"
fi
if [[ ! -f "$PAYLOAD" ]]; then
  echo "Payload file not found: $PAYLOAD" >&2
  exit 1
fi

WEBHOOK_URL="${WEBHOOK_URL:-$BASE_URL/$MODE/ghl-lead-v2}"
HEADERS=(-H 'Content-Type: application/json')
if [[ -n "${WEBHOOK_SECRET:-}" ]]; then
  HEADERS+=(-H "X-Webhook-Secret: $WEBHOOK_SECRET")
fi

echo "POST $WEBHOOK_URL"
echo "Payload: $PAYLOAD"
RESPONSE_FILE="$(mktemp)"
trap 'rm -f "$RESPONSE_FILE"' EXIT

HTTP_CODE="$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "$WEBHOOK_URL" "${HEADERS[@]}" \
  --data-binary "@$PAYLOAD")"

echo "HTTP $HTTP_CODE"
cat "$RESPONSE_FILE"; echo

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Webhook did not return 200 - see Troubleshooting in SETUP-v2.md" >&2
  exit 1
fi
