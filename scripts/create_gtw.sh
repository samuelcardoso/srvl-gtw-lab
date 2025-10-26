#!/usr/bin/env bash
set -euo pipefail

# Usa awslocal, ou aws apontando para o LocalStack
AWSL=$(command -v awslocal >/dev/null 2>&1 && echo "awslocal" || echo "aws --endpoint-url=http://localhost:4566")

# ARNs das Lambdas
ARN_CREATE=$($AWSL lambda get-function --function-name createMessage    --query 'Configuration.FunctionArn' --output text)
ARN_LIST=$($AWSL   lambda get-function --function-name listConversation --query 'Configuration.FunctionArn' --output text)

# ===== API GATEWAY v1 (REST API) =====

# 1) Cria API
REST_ID=$($AWSL apigateway create-rest-api --name chat-api --query id --output text)

# 2) Cria recursos /conversations/{id}/messages
ROOT_ID=$($AWSL apigateway get-resources --rest-api-id "$REST_ID" --query 'items[?path==`/`].id' --output text)
RES_CONV=$($AWSL apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$ROOT_ID" --path-part 'conversations' --query id --output text)
RES_ID=$($AWSL   apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$RES_CONV" --path-part '{id}'        --query id --output text)
RES_MSG=$($AWSL  apigateway create-resource --rest-api-id "$REST_ID" --parent-id "$RES_ID"  --path-part 'messages'     --query id --output text)

# 3) Métodos e integrações (Lambda Proxy)
$AWSL apigateway put-method \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method POST --authorization-type "NONE"

$AWSL apigateway put-integration \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method POST \
  --type AWS_PROXY --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$ARN_CREATE/invocations"

$AWSL apigateway put-method \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method GET --authorization-type "NONE"

$AWSL apigateway put-integration \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method GET \
  --type AWS_PROXY --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/$ARN_LIST/invocations"

# 3.1) OPTIONS para CORS (MOCK)
$AWSL apigateway put-method \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method OPTIONS --authorization-type "NONE"

$AWSL apigateway put-method-response \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method OPTIONS --status-code 200 \
  --response-parameters "method.response.header.Access-Control-Allow-Origin=true,method.response.header.Access-Control-Allow-Methods=true,method.response.header.Access-Control-Allow-Headers=true"

$AWSL apigateway put-integration \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method OPTIONS --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\": 200}"}'

$AWSL apigateway put-integration-response \
  --rest-api-id "$REST_ID" --resource-id "$RES_MSG" --http-method OPTIONS --status-code 200 \
  --response-parameters "method.response.header.Access-Control-Allow-Origin='*',method.response.header.Access-Control-Allow-Methods='GET,POST,OPTIONS',method.response.header.Access-Control-Allow-Headers='*'"

# 4) Permissões para API GW invocar as Lambdas
$AWSL lambda add-permission \
  --function-name createMessage --statement-id apigw1 \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$REST_ID/*/POST/conversations/*/messages"

$AWSL lambda add-permission \
  --function-name listConversation --statement-id apigw2 \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$REST_ID/*/GET/conversations/*/messages"

# 5) Deploy (stage dev)
$AWSL apigateway create-deployment --rest-api-id "$REST_ID" --stage-name dev >/dev/null

# 6) Endpoint base (REST API no LocalStack)
BASE="http://$REST_ID.execute-api.localhost.localstack.cloud:4566/dev"
echo "API base: $BASE"
echo "BASE=$BASE" > .apibase.env
