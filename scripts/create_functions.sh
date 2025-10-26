#!/usr/bin/env bash
set -euo pipefail

# Wrapper: usa awslocal se existir, senão aws com endpoint do LocalStack
AWSL=$(command -v awslocal >/dev/null 2>&1 && echo "awslocal" || echo "aws --endpoint-url=http://localhost:4566")

# Requisitos: docker, docker-compose, zip, jq e (awslocal ou aws)
docker compose up -d

# criar zips (usar npm i ao invés de ci, pois não há package-lock)
pushd lambda-create >/dev/null
npm i --omit=dev
zip -r ../create.zip node_modules handler-create.js >/dev/null
popd >/dev/null

pushd lambda-list >/dev/null
npm i --omit=dev
zip -r ../list.zip node_modules handler-list.js >/dev/null
popd >/dev/null

# criar lambdas com envs de DB (na mesma rede do compose)
$AWSL lambda create-function \
  --function-name createMessage \
  --runtime nodejs20.x \
  --handler handler-create.handler \
  --zip-file fileb://create.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={DB_HOST=postgres,DB_USER=postgres,DB_PASS=postgres,DB_NAME=chatdb,DB_PORT=5432}"

$AWSL lambda create-function \
  --function-name listConversation \
  --runtime nodejs20.x \
  --handler handler-list.handler \
  --zip-file fileb://list.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={DB_HOST=postgres,DB_USER=postgres,DB_PASS=postgres,DB_NAME=chatdb,DB_PORT=5432}"

echo "Funções criadas."
