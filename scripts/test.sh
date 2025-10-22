#!/usr/bin/env bash
set -euo pipefail
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
awslocal logs tail /aws/lambda/createMessage --since 1h
