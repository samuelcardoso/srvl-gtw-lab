#!/usr/bin/env bash
set -euo pipefail

# arns
ARN_CREATE=$(awslocal lambda get-function --function-name createMessage     --query 'Configuration.FunctionArn' --output text)
ARN_LIST=$(awslocal   lambda get-function --function-name listConversation   --query 'Configuration.FunctionArn' --output text)

# API
API_ID=$(awslocal apigatewayv2 create-api \
  --name chat-api \
  --protocol-type HTTP \
  --cors-configuration AllowOrigins='*',AllowMethods='GET,POST,OPTIONS' \
  --query 'ApiId' --output text)

# integrações
INT_CREATE=$(awslocal apigatewayv2 create-integration \
  --api-id $API_ID --integration-type AWS_PROXY \
  --integration-uri $ARN_CREATE --payload-format-version 2.0 \
  --integration-method POST --query 'IntegrationId' --output text)

INT_LIST=$(awslocal apigatewayv2 create-integration \
  --api-id $API_ID --integration-type AWS_PROXY \
  --integration-uri $ARN_LIST --payload-format-version 2.0 \
  --integration-method POST --query 'IntegrationId' --output text)

# rotas
awslocal apigatewayv2 create-route --api-id $API_ID \
  --route-key "POST /conversations/{id}/messages" \
  --target "integrations/$INT_CREATE"

awslocal apigatewayv2 create-route --api-id $API_ID \
  --route-key "GET /conversations/{id}/messages" \
  --target "integrations/$INT_LIST"

# permissões
awslocal lambda add-permission \
  --function-name createMessage --statement-id apigw1 \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$API_ID/*/*/conversations/*/messages"

awslocal lambda add-permission \
  --function-name listConversation --statement-id apigw2 \
  --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:us-east-1:000000000000:$API_ID/*/*/conversations/*/messages"

# stage
awslocal apigatewayv2 create-stage --api-id $API_ID --stage-name dev --auto-deploy

# endpoint
BASE=$(awslocal apigatewayv2 get-apis --query "Items[?Name=='chat-api'].ApiEndpoint" --output text)/dev
echo "API base: $BASE"
# exporta para arquivo para outros scripts
echo "BASE=$BASE" > .apibase.env
