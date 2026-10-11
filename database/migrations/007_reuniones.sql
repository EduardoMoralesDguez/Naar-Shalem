-- database/migrations/007_reuniones.sql
BEGIN;
SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM privado.migraciones
    WHERE version = '006_asistencias'
  ) THEN
    RAISE EXCEPTION 'Ejecuta primero la migración 006_asistencias.';
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS privado.reuniones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_ciclo UUID NOT NULL REFERENCES public.ciclos,
  fecha DATE NOT NULL,
  estado TEXT NOT NULL DEFAULT 'borrador'
    CHECK (estado IN ('borrador', 'cerrada', 'anulada')),
  version BIGINT NOT NULL DEFAULT 1,
  importada BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (id_ciclo, fecha)
);

-- Conserva la unidad que tenía el integrante al crear la reunión.
-- Las altas posteriores no modifican las convocatorias existentes.
CREATE TABLE IF NOT EXISTS privado.convocados (
  reunion UUID NOT NULL REFERENCES privado.reuniones,
  id_usuario UUID NOT NULL REFERENCES public.usuarios,
  id_unidad UUID,
  unidad TEXT NOT NULL,
  estado TEXT NOT NULL DEFAULT 'falta'
    CHECK (estado IN ('asistencia', 'falta', 'justificado')),
  motivo TEXT,
  PRIMARY KEY (reunion, id_usuario)
);

CREATE TABLE IF NOT EXISTS privado.unidades_revisadas (
  reunion UUID NOT NULL REFERENCES privado.reuniones,
  clave TEXT NOT NULL,
  nombre TEXT NOT NULL,
  revisada BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (reunion, clave)
);

CREATE TABLE IF NOT EXISTS privado.bitacora_reuniones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reunion UUID NOT NULL REFERENCES privado.reuniones,
  auth_id UUID,
  accion TEXT NOT NULL,
  datos JSONB NOT NULL,
  fecha TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE privado.reuniones ENABLE ROW LEVEL SECURITY;
ALTER TABLE privado.convocados ENABLE ROW LEVEL SECURITY;
ALTER TABLE privado.unidades_revisadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE privado.bitacora_reuniones ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON
  privado.reuniones,
  privado.convocados,
  privado.unidades_revisadas,
  privado.bitacora_reuniones
FROM PUBLIC, anon, authenticated;

-- Importación histórica única.
-- Conserva los estados registrados y prepara los faltantes para revisión.
-- Los faltantes NO se publican como faltas hasta cerrar cada reunión.
-- Para reconstruir la convocatoria se usan los integrantes activos del ciclo
-- y los inactivos que ya tenían un registro en esa fecha.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM privado.migraciones
    WHERE version = '007_reuniones'
  ) THEN
    INSERT INTO privado.reuniones (id_ciclo, fecha, importada)
    SELECT DISTINCT id_ciclo, fecha, true
    FROM public.asistencias;

    INSERT INTO privado.convocados (
      reunion, id_usuario, id_unidad, unidad, estado
    )
    SELECT
      r.id,
      u.id_usuario,
      u.id_unidad,
      coalesce(un.nombre, 'Sin unidad'),
      coalesce(a.estado, 'falta')
    FROM privado.reuniones r
    JOIN public.usuarios u ON u.id_ciclo = r.id_ciclo
    LEFT JOIN public.unidades un ON un.id_unidad = u.id_unidad
    LEFT JOIN public.asistencias a
      ON a.id_usuario = u.id_usuario AND a.fecha = r.fecha
    WHERE u.es_activo OR a.id_asistencia IS NOT NULL;

    INSERT INTO privado.unidades_revisadas (reunion, clave, nombre)
    SELECT DISTINCT
      reunion,
      coalesce(id_unidad::TEXT, 'sin-unidad'),
      unidad
    FROM privado.convocados;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION privado.ver_convocado(
  p_reunion UUID,
  p_usuario UUID
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios actor
    JOIN privado.cuentas_miembros cm
      ON cm.id_usuario = actor.id_usuario
    JOIN privado.reuniones r ON r.id = p_reunion
    JOIN privado.convocados c
      ON c.reunion = r.id AND c.id_usuario = p_usuario
    WHERE cm.auth_id = (SELECT auth.uid())
      AND actor.es_activo
      AND (
        actor.rol = 'directiva'
        OR actor.id_usuario = p_usuario
        OR (
          actor.rol IN ('capitan', 'consejero')
          AND actor.id_unidad = c.id_unidad
          AND actor.id_ciclo = r.id_ciclo
        )
      )
  );
$$;

-- Solo las reuniones cerradas cuentan en el historial y el dashboard.
CREATE OR REPLACE FUNCTION privado.asistencia_publicada(
  p_usuario UUID,
  p_ciclo UUID,
  p_fecha DATE
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM privado.reuniones r
    WHERE r.id_ciclo = p_ciclo
      AND r.fecha = p_fecha
      AND r.estado = 'cerrada'
      AND privado.ver_convocado(r.id, p_usuario)
  );
$$;

DROP POLICY IF EXISTS lectura_asistencias ON public.asistencias;

CREATE POLICY lectura_asistencias
ON public.asistencias
FOR SELECT
TO authenticated
USING (
  privado.asistencia_publicada(id_usuario, id_ciclo, fecha)
);

-- Impide que el frontend anterior siga guardando registros individuales.
CREATE OR REPLACE FUNCTION public.guardar_asistencias(
  p_fecha DATE,
  p_cambios JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION
    'Actualiza la página. El pase se guarda por reunión y unidad.'
    USING ERRCODE = '22023';
END;
$$;

REVOKE ALL ON FUNCTION public.guardar_asistencias(DATE, JSONB)
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reuniones_listar()
RETURNS TABLE (
  id UUID,
  fecha DATE,
  estado TEXT,
  importada BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT r.id, r.fecha, r.estado, r.importada
  FROM privado.reuniones r
  WHERE privado.es_directiva()
    OR (
      r.estado <> 'anulada'
      AND EXISTS (
        SELECT 1
        FROM privado.convocados c
        WHERE c.reunion = r.id
          AND privado.ver_convocado(r.id, c.id_usuario)
      )
    );
$$;

CREATE OR REPLACE FUNCTION public.reunion_crear(p_fecha DATE)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ciclo public.ciclos%ROWTYPE;
  resultado UUID;
BEGIN
  PERFORM pg_advisory_xact_lock(728401);

  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION 'Solo la directiva puede crear reuniones.'
      USING ERRCODE = '42501';
  END IF;

  IF (SELECT count(*) FROM public.ciclos WHERE es_activo) <> 1 THEN
    RAISE EXCEPTION 'Debe existir un ciclo activo.'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO ciclo
  FROM public.ciclos
  WHERE es_activo
  FOR SHARE;

  IF p_fecha IS NULL OR extract(year FROM p_fecha) <> ciclo.anio THEN
    RAISE EXCEPTION 'Selecciona una fecha del año del ciclo activo.'
      USING ERRCODE = '22023';
  END IF;

  SELECT id INTO resultado
  FROM privado.reuniones
  WHERE id_ciclo = ciclo.id_ciclo AND fecha = p_fecha;

  IF resultado IS NOT NULL THEN
    RETURN resultado;
  END IF;

  INSERT INTO privado.reuniones (id_ciclo, fecha)
  VALUES (ciclo.id_ciclo, p_fecha)
  RETURNING id INTO resultado;

  INSERT INTO privado.convocados (
    reunion, id_usuario, id_unidad, unidad
  )
  SELECT
    resultado,
    u.id_usuario,
    u.id_unidad,
    coalesce(un.nombre, 'Sin unidad')
  FROM public.usuarios u
  LEFT JOIN public.unidades un ON un.id_unidad = u.id_unidad
  WHERE u.es_activo AND u.id_ciclo = ciclo.id_ciclo;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay integrantes activos.'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO privado.unidades_revisadas (reunion, clave, nombre)
  SELECT DISTINCT
    reunion,
    coalesce(id_unidad::TEXT, 'sin-unidad'),
    unidad
  FROM privado.convocados
  WHERE reunion = resultado;

  INSERT INTO privado.bitacora_reuniones (
    reunion, auth_id, accion, datos
  )
  VALUES (
    resultado,
    auth.uid(),
    'crear',
    jsonb_build_object('fecha', p_fecha)
  );

  RETURN resultado;
END;
$$;

CREATE OR REPLACE FUNCTION public.reunion_panel(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  r privado.reuniones%ROWTYPE;
  actor public.usuarios%ROWTYPE;
BEGIN
  SELECT * INTO actor
  FROM public.usuarios
  WHERE id_usuario = privado.mi_id();

  SELECT * INTO r
  FROM privado.reuniones
  WHERE id = p_id;

  IF actor.id_usuario IS NULL
    OR r.id IS NULL
    OR (
      actor.rol <> 'directiva'
      AND (
        r.estado = 'anulada'
        OR NOT EXISTS (
          SELECT 1
          FROM privado.convocados c
          WHERE c.reunion = r.id
            AND privado.ver_convocado(r.id, c.id_usuario)
        )
      )
    )
  THEN
    RAISE EXCEPTION 'Reunión no disponible.'
      USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'id', r.id,
    'fecha', r.fecha,
    'estado', r.estado,
    'version', r.version,
    'importada', r.importada,
    'rol', actor.rol,
    'clave_actor', coalesce(actor.id_unidad::TEXT, 'sin-unidad'),
    'hoy', (now() AT TIME ZONE 'America/Mexico_City')::DATE,
    'puede_justificar',
      actor.rol = 'capitan'
      AND actor.id_unidad IS NOT NULL
      AND actor.id_ciclo = r.id_ciclo
      AND r.fecha = (now() AT TIME ZONE 'America/Mexico_City')::DATE,
    'grupos', coalesce((
      SELECT jsonb_agg(
        jsonb_build_object(
          'clave', g.clave,
          'nombre', g.nombre,
          'revisada', g.revisada
        )
        ORDER BY g.nombre
      )
      FROM privado.unidades_revisadas g
      WHERE g.reunion = r.id
        AND (
          actor.rol = 'directiva'
          OR EXISTS (
            SELECT 1
            FROM privado.convocados c
            WHERE c.reunion = r.id
              AND coalesce(c.id_unidad::TEXT, 'sin-unidad') = g.clave
              AND privado.ver_convocado(r.id, c.id_usuario)
          )
        )
    ), '[]'::JSONB),
    'integrantes', coalesce((
      SELECT jsonb_agg(
        jsonb_build_object(
          'id_usuario', c.id_usuario,
          'nombre', u.nombres || ' ' || u.apellido,
          'clave', coalesce(c.id_unidad::TEXT, 'sin-unidad'),
          'estado', c.estado,
          'motivo',
            CASE
              WHEN actor.rol IN ('directiva', 'capitan')
              THEN c.motivo
            END,
          'puede_justificar',
            actor.rol = 'capitan' AND actor.id_unidad = c.id_unidad
        )
        ORDER BY u.apellido, u.nombres, u.id_usuario
      )
      FROM privado.convocados c
      JOIN public.usuarios u ON u.id_usuario = c.id_usuario
      WHERE c.reunion = r.id
        AND privado.ver_convocado(r.id, c.id_usuario)
    ), '[]'::JSONB)
  );
END;
$$;

-- Publica todos los convocados, conservando un registro por persona y fecha.
CREATE OR REPLACE FUNCTION privado.publicar_reunion(p_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  r privado.reuniones%ROWTYPE;
  c RECORD;
  anterior public.asistencias%ROWTYPE;
  registro UUID;
BEGIN
  SELECT * INTO r
  FROM privado.reuniones
  WHERE id = p_id;

  FOR c IN
    SELECT *
    FROM privado.convocados
    WHERE reunion = p_id
    ORDER BY id_usuario
  LOOP
    SELECT * INTO anterior
    FROM public.asistencias
    WHERE id_usuario = c.id_usuario AND fecha = r.fecha
    FOR UPDATE;

    IF anterior.id_asistencia IS NOT NULL
       AND anterior.id_ciclo <> r.id_ciclo THEN
      RAISE EXCEPTION 'Existe un registro de otro ciclo en esta fecha.'
        USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.asistencias (
      id_usuario, id_ciclo, fecha, estado
    )
    VALUES (
      c.id_usuario, r.id_ciclo, r.fecha, c.estado
    )
    ON CONFLICT (id_usuario, fecha)
    DO UPDATE SET
      estado = excluded.estado,
      version = public.asistencias.version + 1
    WHERE public.asistencias.estado IS DISTINCT FROM excluded.estado
    RETURNING id_asistencia INTO registro;

    IF registro IS NOT NULL THEN
      INSERT INTO privado.historial_asistencias (
        id_asistencia, auth_id, estado_anterior, estado_nuevo
      )
      VALUES (
        registro, auth.uid(), anterior.estado, c.estado
      );
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.reunion_accion(
  p_id UUID,
  p_version BIGINT,
  p_accion TEXT,
  p_datos JSONB DEFAULT '{}'
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  r privado.reuniones%ROWTYPE;
  actor public.usuarios%ROWTYPE;
  c privado.convocados%ROWTYPE;
  v_clave TEXT;
  cambios JSONB;
  v_motivo TEXT;
BEGIN
  PERFORM pg_advisory_xact_lock(728401);

  SELECT * INTO actor
  FROM public.usuarios
  WHERE id_usuario = privado.mi_id()
  FOR SHARE;

  SELECT * INTO r
  FROM privado.reuniones
  WHERE id = p_id
  FOR UPDATE;

  IF actor.id_usuario IS NULL
     OR r.id IS NULL
     OR actor.rol NOT IN ('directiva', 'capitan') THEN
    RAISE EXCEPTION 'No tienes permiso.'
      USING ERRCODE = '42501';
  END IF;

  IF actor.rol = 'capitan'
     AND p_accion IS DISTINCT FROM 'justificar' THEN
    RAISE EXCEPTION 'Solo puedes marcar justificado.'
      USING ERRCODE = '42501';
  END IF;

  IF p_version IS DISTINCT FROM r.version THEN
    RAISE EXCEPTION 'La reunión cambió. Recarga y revisa antes de guardar.'
      USING ERRCODE = '40001';
  END IF;

  IF r.estado = 'anulada'
     AND p_accion IS DISTINCT FROM 'restaurar' THEN
    RAISE EXCEPTION 'La reunión está anulada.'
      USING ERRCODE = '22023';
  END IF;

  IF p_accion = 'unidad' THEN
    v_clave := p_datos->>'clave';
    cambios := p_datos->'integrantes';

    IF NOT EXISTS (
      SELECT 1
      FROM privado.unidades_revisadas
      WHERE reunion = p_id
        AND unidades_revisadas.clave = v_clave
    ) OR jsonb_typeof(cambios) IS DISTINCT FROM 'array' THEN
      RAISE EXCEPTION 'Unidad o lista inválida.'
        USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(cambios)
        AS x(id_usuario UUID, estado TEXT)
      WHERE estado IS NULL
        OR estado NOT IN ('asistencia', 'falta', 'justificado')
    )
    OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(cambios) AS x(id_usuario UUID)
      GROUP BY id_usuario
      HAVING count(*) > 1
    )
    OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(cambios) AS x(id_usuario UUID)
      WHERE NOT EXISTS (
        SELECT 1
        FROM privado.convocados cc
        WHERE cc.reunion = p_id
          AND cc.id_usuario = x.id_usuario
          AND coalesce(cc.id_unidad::TEXT, 'sin-unidad') = v_clave
      )
    )
    OR jsonb_array_length(cambios) <> (
      SELECT count(*)
      FROM privado.convocados cc
      WHERE cc.reunion = p_id
        AND coalesce(cc.id_unidad::TEXT, 'sin-unidad') = v_clave
    )
    THEN
      RAISE EXCEPTION 'Revisa la lista completa de esta unidad.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE privado.convocados cc
    SET
      estado = x.estado,
      motivo = CASE
        WHEN x.estado = 'justificado' THEN cc.motivo
        ELSE NULL
      END
    FROM jsonb_to_recordset(cambios)
      AS x(id_usuario UUID, estado TEXT)
    WHERE cc.reunion = p_id AND cc.id_usuario = x.id_usuario;

    UPDATE privado.unidades_revisadas g
    SET revisada = true
    WHERE g.reunion = p_id AND g.clave = v_clave;

  ELSIF p_accion = 'cerrar' THEN
    IF r.estado <> 'borrador'
      OR r.fecha > (now() AT TIME ZONE 'America/Mexico_City')::DATE
      OR EXISTS (
        SELECT 1
        FROM privado.unidades_revisadas
        WHERE reunion = p_id AND NOT revisada
      )
    THEN
      RAISE EXCEPTION
        'Revisa todas las unidades. Solo puedes cerrar el pase el día de la reunión o después.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE privado.reuniones
    SET estado = 'cerrada'
    WHERE id = p_id;

  ELSIF p_accion = 'justificar' THEN
    SELECT * INTO c
    FROM privado.convocados
    WHERE reunion = p_id
      AND id_usuario = (p_datos->>'id_usuario')::UUID;

    v_motivo := trim(p_datos->>'motivo');

    IF actor.rol <> 'capitan'
      OR actor.id_unidad IS NULL
      OR c.id_usuario IS NULL
      OR actor.id_unidad IS DISTINCT FROM c.id_unidad
      OR actor.id_ciclo <> r.id_ciclo
      OR r.fecha <> (now() AT TIME ZONE 'America/Mexico_City')::DATE
    THEN
      RAISE EXCEPTION
        'Solo puedes justificar a tu unidad durante el día de la reunión.'
        USING ERRCODE = '42501';
    END IF;

    IF v_motivo IS NULL
      OR length(v_motivo) NOT BETWEEN 3 AND 500
      OR c.estado = 'justificado'
    THEN
      RAISE EXCEPTION
        'Escribe un motivo de 3 a 500 caracteres. El integrante no debe estar ya justificado.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE privado.convocados
    SET estado = 'justificado', motivo = v_motivo
    WHERE reunion = p_id AND id_usuario = c.id_usuario;

  ELSIF p_accion = 'anular' THEN
    v_motivo := trim(p_datos->>'motivo');

    IF v_motivo IS NULL OR length(v_motivo) NOT BETWEEN 3 AND 500 THEN
      RAISE EXCEPTION 'Indica el motivo de anulación.'
        USING ERRCODE = '22023';
    END IF;

    UPDATE privado.reuniones
    SET estado = 'anulada'
    WHERE id = p_id;

  ELSIF p_accion = 'restaurar' AND r.estado = 'anulada' THEN
    UPDATE privado.reuniones
    SET estado = 'borrador'
    WHERE id = p_id;

    UPDATE privado.unidades_revisadas
    SET revisada = false
    WHERE reunion = p_id;

  ELSE
    RAISE EXCEPTION 'Acción inválida.'
      USING ERRCODE = '22023';
  END IF;

  IF (
    SELECT estado FROM privado.reuniones WHERE id = p_id
  ) = 'cerrada'
  AND p_accion IN ('unidad', 'cerrar', 'justificar') THEN
    PERFORM privado.publicar_reunion(p_id);
  END IF;

  UPDATE privado.reuniones
  SET version = version + 1
  WHERE id = p_id;

  INSERT INTO privado.bitacora_reuniones (
    reunion, auth_id, accion, datos
  )
  VALUES (
    p_id, auth.uid(), p_accion, p_datos
  );
END;
$$;

DO $$
DECLARE
  f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'privado.ver_convocado(uuid,uuid)',
    'privado.asistencia_publicada(uuid,uuid,date)',
    'privado.publicar_reunion(uuid)',
    'public.reuniones_listar()',
    'public.reunion_crear(date)',
    'public.reunion_panel(uuid)',
    'public.reunion_accion(uuid,bigint,text,jsonb)'
  ]
  LOOP
    EXECUTE 'ALTER FUNCTION ' || f || ' OWNER TO postgres';
    EXECUTE 'REVOKE ALL ON FUNCTION ' || f ||
      ' FROM PUBLIC,anon,authenticated';

    IF f <> 'privado.publicar_reunion(uuid)' THEN
      EXECUTE 'GRANT EXECUTE ON FUNCTION ' || f ||
        ' TO authenticated';
    END IF;
  END LOOP;
END;
$$;

INSERT INTO privado.migraciones (version)
VALUES ('007_reuniones')
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';
COMMIT;