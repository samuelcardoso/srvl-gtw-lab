#!/usr/bin/env bash
set -euo pipefail

AWSL=$(command -v awslocal >/dev/null 2>&1 && echo "awslocal" || echo "aws --endpoint-url=http://localhost:4566")

# carrega BASE do arquivo gerado no create_gtw.sh
source .apibase.env

echo "POST nova mensagem:"
curl -s -X POST "$BASE/conversations/demo/messages" \
  -H 'content-type: application/json' \
  -d '{"role":"user","content":"olá"}' | jq .

echo
echo "GET mensagens:"
curl -s "$BASE/conversations/demo/messages" | jq .

echo
echo "Logs da lambda createMessage (última hora):"

# Se 'aws logs tail' existir (CLI v2), usa; caso contrário, fallback com filter-log-events (CLI v1)
if $AWSL logs tail --help >/dev/null 2>&1; then
  # CLI v2
  $AWSL logs tail /aws/lambda/createMessage --since 1h
else
  # CLI v1: usar filter-log-events com janela de 1h
  # calcula epoch em ms de 1h atrás
  START_MS=$(($(date -d '1 hour ago' +%s) * 1000))
  $AWSL logs filter-log-events \
    --log-group-name /aws/lambda/createMessage \
    --start-time "$START_MS" \
    --query 'events[].message' \
    --output text || true
fi
