# Serverless + API Gateway (LocalStack) — Persistência de Conversas (Postgres)

Este lab cria uma API **Serverless** (Lambda + API Gateway — emulado com **LocalStack**) que **persiste e lista** mensagens de conversas em um **Postgres** local (via Docker Compose).

## O que será criado
- **Banco:** Postgres com tabela `messages` (inicializado por `sql/init.sql`);
- **Lambdas:**  
  - `createMessage` (POST `/conversations/{id}/messages`)  
  - `listConversation` (GET `/conversations/{id}/messages`)
- **API Gateway HTTP API:** rotas integradas às Lambdas (payload v2.0)
- **Logs:** CloudWatch (emulado pelo LocalStack)

## Pré-requisitos
- Docker e Docker Compose
- LocalStack (imagem Docker já usada pelo compose)
- AWS CLI + `awslocal` (CLI wrapper do LocalStack)
- Node.js (para `npm`, caso precise rodar local)
- `jq` e `zip`

> No Windows, recomenda-se WSL2.

## Estrutura
- `docker-compose.yml` — LocalStack + Postgres
- `sql/init.sql` — cria tabela e índice
- `lambda-create/` e `lambda-list/` — handlers Node.js + `package.json`
- `scripts/create_functions.sh` — sobe compose, empacota e cria Lambdas
- `scripts/create_gtw.sh` — cria API Gateway, integra e escreve `.apibase.env`
- `scripts/test.sh` — envia requisições de teste e tail nos logs da Lambda

## Passo a passo

### 1) Subir infraestrutura local
```bash
cd srvl-gtw-lab
docker compose up -d
```
- Sobe `localstack` (porta `4566`) e `postgres` (porta `5432`).
- O Postgres é inicializado com `sql/init.sql`.

### 2) Criar as funções Lambda (zip) + variáveis de ambiente do DB
```bash
./scripts/create_functions.sh
```
O script:
- Instala dependências em cada Lambda (`npm i --omit=dev`);
- Empacota (`zip`) incluindo `node_modules` + handler;
- Cria as funções no LocalStack (runtime `nodejs20.x`) passando envs do Postgres.

### 3) Criar a API Gateway e integrar
```bash
./scripts/create_gtw.sh
```
O script:
- Cria uma HTTP API (`chat-api`) com CORS;
- Cria integrações AWS_PROXY para cada Lambda (payload 2.0);
- Cria rotas:
  - **POST** `/conversations/{id}/messages` → `createMessage`
  - **GET**  `/conversations/{id}/messages` → `listConversation`
- Concede permissões de invocação às rotas;
- Cria stage `dev` com auto-deploy;
- Grava o endpoint base em `.apibase.env` (variável `BASE`).

### 4) Testar
```bash
./scripts/test.sh
```
Você verá:
- `POST` de uma nova mensagem (role/content) para `conversation_id = demo`;
- `GET` listando mensagens;
- Tail dos logs da Lambda `createMessage`.

> Se preferir testar manualmente após `create_gtw.sh`:
```bash
source .apibase.env
curl -s -X POST "$BASE/conversations/demo/messages"   -H 'content-type: application/json'   -d '{"role":"user","content":"olá"}' | jq .

curl -s "$BASE/conversations/demo/messages" | jq .
```

## Formato dos handlers

### `POST /conversations/{id}/messages`
**Body (JSON)**
```json
{
  "role": "user",
  "content": "olá"
}
```
**Respostas**
- `201 { "ok": true }` em sucesso
- `400` se payload inválido
- `500` erro interno

### `GET /conversations/{id}/messages`
**Resposta**
```json
[
  {"role":"user","content":"olá","ts":"2025-01-01T12:00:00.000Z"}
]
```

## Solução de problemas
- **LocalStack não responde na 4566**: verifique `docker compose ps` e `docker logs localstack`.
- **Erro de conexão ao DB**: confirme envs das Lambdas (host `postgres`) e se o container do Postgres está `healthy`.  
  Para reexecutar, você pode deletar as funções e recriar:
  ```bash
  awslocal lambda delete-function --function-name createMessage || true
  awslocal lambda delete-function --function-name listConversation || true
  ./scripts/create_functions.sh
  ```
- **Rotas 403/404**: rode `./scripts/create_gtw.sh` novamente e confirme se o arquivo `.apibase.env` foi gerado.
- **Permissões**: o script já adiciona `lambda add-permission` para cada rota. Se trocou o `API_ID`, recrie.

## Limpeza
```bash
docker compose down -v
```
Remove containers e volume do Postgres.