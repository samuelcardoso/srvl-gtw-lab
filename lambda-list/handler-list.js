const { Pool } = require("pg");
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
    if (!convId) return { statusCode: 400, body: JSON.stringify({ error: "missing id" }) };
    const { rows } = await pool.query(
      "select role, content, ts from messages where conversation_id=$1 order by ts asc",
      [convId]
    );
    return { statusCode: 200, body: JSON.stringify(rows) };
  } catch (e) {
    console.error(e);
    return { statusCode: 500, body: JSON.stringify({ error: "internal" }) };
  }
};
