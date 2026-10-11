-- database/migrations/006_asistencias.sql
BEGIN;
SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM privado.migraciones
    WHERE version = '005_portal_y_fotos'
  ) THEN
    RAISE EXCEPTION 'Primero ejecuta la migración 005_portal_y_fotos.';
  END IF;
END;
$$;

ALTER TABLE public.asistencias
  ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1;

CREATE TABLE IF NOT EXISTS privado.historial_asistencias (
  id_evento UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_asistencia UUID NOT NULL REFERENCES public.asistencias(id_asistencia),
  auth_id UUID NOT NULL,
  estado_anterior TEXT,
  estado_nuevo TEXT NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE privado.historial_asistencias ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON privado.historial_asistencias
  FROM PUBLIC, anon, authenticated;

-- La unidad y el rol se comprueban con los datos actuales del integrante.
-- Los capitanes y consejeros consultan su unidad dentro de su mismo ciclo.
-- Sin unidad asignada, conservan únicamente la consulta de su historial.
CREATE OR REPLACE FUNCTION privado.puede_ver_asistencia(p_usuario UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios actor
    JOIN privado.cuentas_miembros cuenta
      ON cuenta.id_usuario = actor.id_usuario
    JOIN public.usuarios destino
      ON destino.id_usuario = p_usuario
    WHERE cuenta.auth_id = (SELECT auth.uid())
      AND actor.es_activo
      AND (
        actor.rol = 'directiva'
        OR actor.id_usuario = destino.id_usuario
        OR (
          actor.rol IN ('capitan', 'consejero')
          AND actor.id_unidad = destino.id_unidad
          AND actor.id_ciclo = destino.id_ciclo
        )
      )
  );
$$;

ALTER FUNCTION privado.puede_ver_asistencia(UUID) OWNER TO postgres;

REVOKE ALL ON FUNCTION privado.puede_ver_asistencia(UUID)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION privado.puede_ver_asistencia(UUID)
  TO authenticated;

-- Sustituye solo las políticas de asistencias.
-- Las cuotas mantienen sus permisos anteriores.
DO $$
DECLARE
  p RECORD;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'asistencias'
  LOOP
    EXECUTE format(
      'DROP POLICY %I ON public.asistencias',
      p.policyname
    );
  END LOOP;
END;
$$;

ALTER TABLE public.asistencias ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.asistencias FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.asistencias TO authenticated;

CREATE POLICY lectura_asistencias
ON public.asistencias
FOR SELECT
TO authenticated
USING (privado.puede_ver_asistencia(id_usuario));

-- Solo devuelve integrantes cuyo historial puede consultar la cuenta.
-- Incluye inactivos para conservar la consulta de sus registros.
CREATE OR REPLACE FUNCTION public.integrantes_asistencias()
RETURNS TABLE (
  id_usuario UUID,
  nombres TEXT,
  apellido TEXT,
  id_unidad UUID,
  unidad TEXT,
  es_activo BOOLEAN,
  id_ciclo UUID,
  anio INTEGER,
  ciclo_activo BOOLEAN,
  puede_marcar BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    u.id_unidad,
    un.nombre::TEXT,
    u.es_activo,
    u.id_ciclo,
    c.anio,
    c.es_activo,
    u.es_activo AND c.es_activo AND (
      actor.rol = 'directiva'
      OR (
        actor.rol = 'capitan'
        AND actor.id_unidad = u.id_unidad
        AND actor.id_ciclo = u.id_ciclo
      )
    ) IS TRUE
  FROM public.usuarios u
  JOIN public.ciclos c ON c.id_ciclo = u.id_ciclo
  LEFT JOIN public.unidades un ON un.id_unidad = u.id_unidad
  JOIN public.usuarios actor ON actor.id_usuario = privado.mi_id()
  WHERE privado.puede_ver_asistencia(u.id_usuario);
$$;

ALTER FUNCTION public.integrantes_asistencias() OWNER TO postgres;

REVOKE ALL ON FUNCTION public.integrantes_asistencias()
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.integrantes_asistencias()
  TO authenticated;

-- Todo el lote se guarda en una transacción.
-- Si un registro falla, ninguno de los cambios del lote se aplica.
-- La versión evita sobrescribir cambios realizados por otra persona.
CREATE OR REPLACE FUNCTION public.guardar_asistencias(
  p_fecha DATE,
  p_cambios JSONB
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  actor public.usuarios%ROWTYPE;
  destino public.usuarios%ROWTYPE;
  anterior public.asistencias%ROWTYPE;
  cambio RECORD;
  ciclo public.ciclos%ROWTYPE;
  registro UUID;
  cantidad INTEGER := 0;
BEGIN
  -- Comparte bloqueo con activar/desactivar integrantes.
  PERFORM pg_advisory_xact_lock(728401);

  SELECT * INTO actor
  FROM public.usuarios
  WHERE id_usuario = privado.mi_id()
  FOR SHARE;

  IF actor.id_usuario IS NULL
     OR actor.rol NOT IN ('directiva', 'capitan') THEN
    RAISE EXCEPTION 'No tienes permiso para registrar asistencias.'
      USING ERRCODE = '42501';
  END IF;

  IF p_fecha IS NULL
     OR p_fecha > (now() AT TIME ZONE 'America/Mexico_City')::DATE THEN
    RAISE EXCEPTION 'Selecciona una fecha válida, no futura.'
      USING ERRCODE = '22023';
  END IF;

  IF jsonb_typeof(p_cambios) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'La lista de cambios no es válida.'
      USING ERRCODE = '22023';
  END IF;

  IF jsonb_array_length(p_cambios) NOT BETWEEN 1 AND 500 THEN
    RAISE EXCEPTION 'Envía entre 1 y 500 cambios.'
      USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(p_cambios) AS x(id_usuario UUID)
    GROUP BY id_usuario
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Hay integrantes repetidos.'
      USING ERRCODE = '22023';
  END IF;

  IF (SELECT count(*) FROM public.ciclos WHERE es_activo) <> 1 THEN
    RAISE EXCEPTION 'Debe existir exactamente un ciclo activo.'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO ciclo
  FROM public.ciclos
  WHERE es_activo
  FOR SHARE;

  IF extract(year FROM p_fecha) <> ciclo.anio THEN
    RAISE EXCEPTION 'La fecha debe pertenecer al año del ciclo activo.'
      USING ERRCODE = '22023';
  END IF;

  FOR cambio IN
    SELECT *
    FROM jsonb_to_recordset(p_cambios)
      AS x(id_usuario UUID, estado TEXT, version BIGINT)
    ORDER BY id_usuario
  LOOP
    SELECT * INTO destino
    FROM public.usuarios
    WHERE id_usuario = cambio.id_usuario
    FOR UPDATE;

    IF destino.id_usuario IS NULL
       OR NOT destino.es_activo
       OR destino.id_ciclo <> ciclo.id_ciclo THEN
      RAISE EXCEPTION 'El integrante no está activo en el ciclo actual.'
        USING ERRCODE = '22023';
    END IF;

    IF cambio.estado IS NULL
       OR cambio.estado NOT IN ('asistencia', 'falta', 'justificado') THEN
      RAISE EXCEPTION 'Estado de asistencia inválido.'
        USING ERRCODE = '22023';
    END IF;

    IF actor.rol = 'capitan' AND (
      cambio.estado <> 'justificado'
      OR actor.id_unidad IS NULL
      OR actor.id_unidad IS DISTINCT FROM destino.id_unidad
      OR actor.id_ciclo <> destino.id_ciclo
    ) THEN
      RAISE EXCEPTION 'Solo puedes justificar integrantes de tu unidad.'
        USING ERRCODE = '42501';
    END IF;

    SELECT * INTO anterior
    FROM public.asistencias
    WHERE id_usuario = destino.id_usuario
      AND fecha = p_fecha
    FOR UPDATE;

    IF anterior.id_asistencia IS NULL THEN
      IF cambio.version IS NOT NULL THEN
        RAISE EXCEPTION 'El registro cambió. Recarga la lista antes de guardar.'
          USING ERRCODE = '40001';
      END IF;

      INSERT INTO public.asistencias (
        id_usuario,
        id_ciclo,
        fecha,
        estado
      )
      VALUES (
        destino.id_usuario,
        ciclo.id_ciclo,
        p_fecha,
        cambio.estado
      )
      RETURNING id_asistencia INTO registro;
    ELSE
      IF anterior.id_ciclo <> ciclo.id_ciclo
         OR cambio.version IS DISTINCT FROM anterior.version THEN
        RAISE EXCEPTION 'Otro usuario modificó la lista. Recarga antes de guardar.'
          USING ERRCODE = '40001';
      END IF;

      UPDATE public.asistencias
      SET estado = cambio.estado,
          version = version + 1
      WHERE id_asistencia = anterior.id_asistencia;

      registro := anterior.id_asistencia;
    END IF;

    INSERT INTO privado.historial_asistencias (
      id_asistencia,
      auth_id,
      estado_anterior,
      estado_nuevo
    )
    VALUES (
      registro,
      auth.uid(),
      anterior.estado,
      cambio.estado
    );

    cantidad := cantidad + 1;
  END LOOP;

  RETURN cantidad;
END;
$$;

ALTER FUNCTION public.guardar_asistencias(DATE, JSONB)
  OWNER TO postgres;

REVOKE ALL ON FUNCTION public.guardar_asistencias(DATE, JSONB)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.guardar_asistencias(DATE, JSONB)
  TO authenticated;

INSERT INTO privado.migraciones(version)
VALUES ('006_asistencias')
ON CONFLICT (version) DO NOTHING;

NOTIFY pgrst, 'reload schema';
COMMIT;