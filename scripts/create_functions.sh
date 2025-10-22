#!/usr/bin/env bash
set -euo pipefail

# Requisitos: docker, docker-compose, awslocal, zip, jq
docker compose up -d

# criar zips (usar npm i ao invés de ci, pois não há package-lock)
pushd lambda-create
npm i --omit=dev
zip -r ../create.zip node_modules handler-create.js
popd

pushd lambda-list
npm i --omit=dev
zip -r ../list.zip node_modules handler-list.js
popd

# criar lambdas com envs de DB (na mesma rede do compose)
awslocal lambda create-function \
  --function-name createMessage \
  --runtime nodejs20.x \
  --handler handler-create.handler \
  --zip-file fileb://create.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={DB_HOST=postgres,DB_USER=postgres,DB_PASS=postgres,DB_NAME=chatdb,DB_PORT=5432}"

awslocal lambda create-function \
  --function-name listConversation \
  --runtime nodejs20.x \
  --handler handler-list.handler \
  --zip-file fileb://list.zip \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --environment "Variables={DB_HOST=postgres,DB_USER=postgres,DB_PASS=postgres,DB_NAME=chatdb,DB_PORT=5432}"

echo "Funções criadas."
