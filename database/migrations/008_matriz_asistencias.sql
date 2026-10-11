-- database/migrations/008_matriz_asistencias.sql
BEGIN;
SET LOCAL lock_timeout = '5s';
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='007_reuniones') THEN
    RAISE EXCEPTION 'Ejecuta primero 007_reuniones.';
  END IF;
END $$;

-- Proyección mínima de presentación; no amplía el acceso a expedientes.
CREATE OR REPLACE FUNCTION public.presentacion_integrantes()
RETURNS TABLE(id_usuario UUID, es_directiva BOOLEAN, cobra_cuotas BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT u.id_usuario,u.rol='directiva',u.rol IN ('conquistador','capitan')
  FROM public.directorio_portal() d
  JOIN public.usuarios u ON u.id_usuario=d.id_usuario;
$$;

CREATE OR REPLACE FUNCTION public.historial_matriz()
RETURNS TABLE(
  reunion UUID, fecha DATE, version BIGINT, id_usuario UUID,
  nombre TEXT, unidad_clave TEXT, unidad TEXT, estado TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT r.id,r.fecha,r.version,c.id_usuario,
    (u.nombres||' '||u.apellido)::TEXT,
    coalesce(c.id_unidad::TEXT,'sin-unidad'),c.unidad,c.estado
  FROM privado.reuniones r
  JOIN privado.convocados c ON c.reunion=r.id
  JOIN public.usuarios u ON u.id_usuario=c.id_usuario
  WHERE r.estado='cerrada' AND privado.ver_convocado(r.id,c.id_usuario);
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

  IF p_fecha IS DISTINCT FROM (now() AT TIME ZONE 'America/Mexico_City')::DATE
     OR extract(year FROM p_fecha) <> ciclo.anio THEN
    RAISE EXCEPTION 'Solo puedes crear la reunión de hoy dentro del ciclo activo.'
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

  ELSIF p_accion = 'celda' THEN
    IF r.estado <> 'cerrada' THEN
      RAISE EXCEPTION 'Completa el borrador antes de editar su historial.' USING ERRCODE='22023';
    END IF;
    SELECT * INTO c FROM privado.convocados
      WHERE reunion=p_id AND id_usuario=(p_datos->>'id_usuario')::UUID;
    IF c.id_usuario IS NULL OR p_datos->>'estado' IS NULL
      OR p_datos->>'estado' NOT IN ('asistencia','falta','justificado') THEN
      RAISE EXCEPTION 'Registro o estado inválido.' USING ERRCODE='22023';
    END IF;
    UPDATE privado.convocados SET estado=p_datos->>'estado', motivo=NULL
      WHERE reunion=p_id AND id_usuario=c.id_usuario;
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
      OR c.estado <> 'falta'
    THEN
      RAISE EXCEPTION
        'Escribe un motivo de 3 a 500 caracteres. Solo se puede justificar una falta; una asistencia registrada no se modifica.'
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
  AND p_accion IN ('unidad', 'cerrar', 'justificar', 'celda') THEN
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

DO $$ DECLARE f TEXT; BEGIN
  FOREACH f IN ARRAY ARRAY[
    'public.presentacion_integrantes()', 'public.historial_matriz()',
    'public.reunion_crear(date)', 'public.reunion_accion(uuid,bigint,text,jsonb)'
  ] LOOP
    EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
    EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
    EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated';
  END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('008_matriz_asistencias') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
