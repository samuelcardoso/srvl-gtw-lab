// package.json: { "dependencies": { "pg": "^8.11.5" } }
const { Pool } = require("pg");

// Pool fora do handler para reuso entre invocações
const pool = new Pool({
  host: process.env.DB_HOST || "postgres",
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASS || "postgres",
  database: process.env.DB_NAME || "chatdb",
  port: +(process.env.DB_PORT || 5432),
});

exports.handler = async (event) => {
  try {
    const convId = event.pathParameters?.id;
    const body = JSON.parse(event.body || "{}");
    if (!convId || !body.content || !body.role) {
      return { statusCode: 400, body: JSON.stringify({ error: "invalid payload" }) };
    }
    await pool.query(
      "insert into messages(conversation_id, role, content) values ($1,$2,$3)",
      [convId, body.role, body.content]
    );
    return { statusCode: 201, body: JSON.stringify({ ok: true }) };
  } catch (e) {
    console.error(e);
    return { statusCode: 500, body: JSON.stringify({ error: "internal" }) };
  }
};
