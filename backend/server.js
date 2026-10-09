require('dotenv').config();
const express = require("express");
const cors = require("cors");
const { Pool } = require("pg");

const app = express();
const PORT = 3000;

// ------------------------------------------------------------
// CONEXIÓN A POSTGRESQL (ajusta user y password a los tuyos)
// ------------------------------------------------------------
const pool = new Pool({
  host: process.env.PGHOST || "localhost",
  port: Number(process.env.PGPORT) || 5432,
  database: process.env.PGDATABASE || "naar_shalem",
  user: process.env.PGUSER || "postgres",
  password: process.env.PGPASSWORD || "TU_PASSWORD_AQUI",
});

app.use(cors());
app.use(express.json());

// ------------------------------------------------------------
// GET /api/usuarios
// Devuelve los usuarios activos del ciclo activo, con el nombre
// de su unidad y de su clase. Se usa LEFT JOIN porque, según el
// documento, unidad y clase pueden ser nulas al iniciar el año.
// ------------------------------------------------------------
app.get("/api/usuarios", async (req, res) => {
  try {
    const sql = `
      SELECT
        u.id_usuario,
        u.nombres,
        u.apellido,
        u.rol,
        un.nombre AS unidad,
        c.nombre  AS clase
      FROM usuarios u
      JOIN ciclos ci         ON ci.id_ciclo   = u.id_ciclo
      LEFT JOIN unidades un  ON un.id_unidad  = u.id_unidad
      LEFT JOIN clases c     ON c.id_clase    = u.id_clase
      WHERE ci.es_activo = TRUE
        AND u.es_activo  = TRUE
      ORDER BY u.nombres, u.apellido;
    `;
    const { rows } = await pool.query(sql);
    res.json(rows);
  } catch (error) {
    console.error("Error en GET /api/usuarios:", error.message);
    res.status(500).json({ error: "No se pudieron obtener los usuarios" });
  }
});

// ------------------------------------------------------------
// GET /api/progreso/:idUsuario
// Asistencia (asistencias + justificados / total de registros)
// y dinero pagado en cuotas, solo del ciclo activo.
// ------------------------------------------------------------
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

app.get("/api/progreso/:idUsuario", async (req, res) => {
  const { idUsuario } = req.params;

  if (!UUID_REGEX.test(idUsuario)) {
    return res.status(400).json({ error: "El id de usuario no es válido" });
  }

  try {
    const [asistenciasResult, cuotasResult] = await Promise.all([
      pool.query(
        `SELECT
           COUNT(*) FILTER (WHERE a.estado = 'asistencia')::int  AS asistencias,
           COUNT(*) FILTER (WHERE a.estado = 'justificado')::int AS justificados,
           COUNT(*) FILTER (WHERE a.estado = 'falta')::int       AS faltas,
           COUNT(*)::int                                         AS total_registros
         FROM asistencias a
         JOIN ciclos ci ON ci.id_ciclo = a.id_ciclo
         WHERE a.id_usuario = $1 AND ci.es_activo = TRUE`,
        [idUsuario],
      ),
      pool.query(
        `SELECT
           COALESCE(SUM(q.monto_pagado), 0)::int              AS total_pagado,
           COUNT(*) FILTER (WHERE q.monto_pagado > 0)::int    AS semanas_pagadas,
           COUNT(*)::int                                      AS semanas_registradas
         FROM cuotas q
         JOIN ciclos ci ON ci.id_ciclo = q.id_ciclo
         WHERE q.id_usuario = $1 AND ci.es_activo = TRUE`,
        [idUsuario],
      ),
    ]);

    const a = asistenciasResult.rows[0];
    const c = cuotasResult.rows[0];

    const porcentajeAsistencia = a.total_registros
      ? Math.round(((a.asistencias + a.justificados) / a.total_registros) * 100)
      : 0;

    const porcentajeCuotas = c.semanas_registradas
      ? Math.round((c.semanas_pagadas / c.semanas_registradas) * 100)
      : 0;

    res.json({
      id_usuario: idUsuario,
      asistencia: {
        asistencias: a.asistencias,
        justificados: a.justificados,
        faltas: a.faltas,
        total_registros: a.total_registros,
        porcentaje: porcentajeAsistencia,
      },
      cuotas: {
        total_pagado: c.total_pagado,
        semanas_pagadas: c.semanas_pagadas,
        semanas_registradas: c.semanas_registradas,
        porcentaje: porcentajeCuotas,
      },
    });
  } catch (error) {
    console.error("Error en GET /api/progreso:", error.message);
    res.status(500).json({ error: "No se pudo calcular el progreso" });
  }
});

app.listen(PORT, () => {
  console.log(`Servidor Naar-Shalem corriendo en http://localhost:${PORT}`);
});
