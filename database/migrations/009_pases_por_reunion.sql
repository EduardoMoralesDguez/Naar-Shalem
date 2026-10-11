-- database/migrations/009_pases_por_reunion.sql
BEGIN;
SET LOCAL lock_timeout = '5s';
SELECT pg_advisory_xact_lock(728401);
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='008_matriz_asistencias') THEN
    RAISE EXCEPTION 'Ejecuta primero 008_matriz_asistencias.';
  END IF;
END $$;

ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS nombre TEXT NOT NULL DEFAULT 'General';
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS numero INTEGER NOT NULL DEFAULT 1;
ALTER TABLE public.asistencias ADD COLUMN IF NOT EXISTS id_reunion UUID REFERENCES privado.reuniones(id);
-- Vincula los registros anteriores ANTES de permitir más de un pase por fecha.
UPDATE public.asistencias a SET id_reunion=r.id FROM privado.reuniones r
WHERE a.id_reunion IS NULL AND a.id_ciclo=r.id_ciclo AND a.fecha=r.fecha;
ALTER TABLE public.asistencias ALTER COLUMN id_reunion SET NOT NULL;
ALTER TABLE public.asistencias DROP CONSTRAINT IF EXISTS asistencias_id_usuario_fecha_key;
ALTER TABLE privado.reuniones DROP CONSTRAINT IF EXISTS reuniones_id_ciclo_fecha_key;
CREATE UNIQUE INDEX IF NOT EXISTS asistencia_por_reunion ON public.asistencias(id_reunion,id_usuario);
CREATE UNIQUE INDEX IF NOT EXISTS reunion_nombre_dia ON privado.reuniones(id_ciclo,fecha,lower(nombre));
CREATE UNIQUE INDEX IF NOT EXISTS reunion_numero_dia ON privado.reuniones(id_ciclo,fecha,numero);

-- Se preservan los registros históricos de directiva, pero quedan exentos.
ALTER TABLE privado.convocados ADD COLUMN IF NOT EXISTS exento_asistencia BOOLEAN NOT NULL DEFAULT false;
UPDATE privado.convocados c SET exento_asistencia=true FROM public.usuarios u
WHERE c.id_usuario=u.id_usuario AND u.rol='directiva' AND NOT c.exento_asistencia;
CREATE OR REPLACE VIEW privado.convocados_asistencia AS
SELECT c.* FROM privado.convocados c JOIN public.usuarios u ON u.id_usuario=c.id_usuario
WHERE NOT c.exento_asistencia AND u.rol<>'directiva';
REVOKE ALL ON privado.convocados_asistencia FROM PUBLIC,anon,authenticated;

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
    JOIN privado.convocados_asistencia c
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

CREATE OR REPLACE FUNCTION privado.pase_publicado(p_reunion UUID,p_usuario UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT EXISTS(SELECT 1 FROM privado.reuniones r WHERE r.id=p_reunion
   AND r.estado='cerrada' AND privado.ver_convocado(r.id,p_usuario));
$$;
DROP POLICY IF EXISTS lectura_asistencias ON public.asistencias;
CREATE POLICY lectura_asistencias ON public.asistencias FOR SELECT TO authenticated
USING (privado.pase_publicado(id_reunion,id_usuario));

CREATE OR REPLACE FUNCTION public.reunion_crear_turno(p_fecha DATE, p_nombre TEXT)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  ciclo public.ciclos%ROWTYPE;
  resultado UUID;
  v_nombre TEXT;
  v_numero INTEGER;
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

  v_nombre := btrim(regexp_replace(p_nombre, '\s+', ' ', 'g'));
  IF v_nombre IS NULL OR length(v_nombre) NOT BETWEEN 1 AND 60 THEN
    RAISE EXCEPTION 'Indica un nombre de 1 a 60 caracteres para el pase.' USING ERRCODE='22023';
  END IF;
  SELECT id INTO resultado
  FROM privado.reuniones
  WHERE id_ciclo = ciclo.id_ciclo AND fecha = p_fecha AND lower(nombre)=lower(v_nombre);

  IF resultado IS NOT NULL THEN
    RETURN resultado;
  END IF;

  SELECT coalesce(max(numero),0)+1 INTO v_numero FROM privado.reuniones
    WHERE id_ciclo=ciclo.id_ciclo AND fecha=p_fecha;
  INSERT INTO privado.reuniones (id_ciclo, fecha, nombre, numero)
  VALUES (ciclo.id_ciclo, p_fecha, v_nombre, v_numero)
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
  WHERE u.es_activo AND u.id_ciclo = ciclo.id_ciclo AND u.rol<>'directiva';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay integrantes activos sujetos a asistencia.'
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
    jsonb_build_object('fecha', p_fecha, 'nombre', v_nombre)
  );

  RETURN resultado;
END;
$$;

-- Compatibilidad: clientes anteriores solo crean/abren el pase General.
CREATE OR REPLACE FUNCTION public.reunion_crear(p_fecha DATE)
RETURNS UUID LANGUAGE sql SECURITY DEFINER SET search_path=''
AS $$ SELECT public.reunion_crear_turno(p_fecha,'General'); $$;

CREATE OR REPLACE FUNCTION public.reuniones_listar_turnos()
RETURNS TABLE(id UUID,fecha DATE,estado TEXT,importada BOOLEAN,nombre TEXT,numero INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT r.id,r.fecha,r.estado,r.importada,r.nombre,r.numero
 FROM privado.reuniones r JOIN public.reuniones_listar() visible ON visible.id=r.id;
$$;
CREATE OR REPLACE FUNCTION public.historial_matriz_turnos()
RETURNS TABLE(reunion UUID,fecha DATE,version BIGINT,id_usuario UUID,nombre TEXT,
 unidad_clave TEXT,unidad TEXT,estado TEXT,nombre_pase TEXT,numero INTEGER)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT r.id,r.fecha,r.version,c.id_usuario,(u.nombres||' '||u.apellido)::TEXT,
 coalesce(c.id_unidad::TEXT,'sin-unidad'),c.unidad,c.estado,r.nombre,r.numero
 FROM privado.reuniones r JOIN privado.convocados_asistencia c ON c.reunion=r.id
 JOIN public.usuarios u ON u.id_usuario=c.id_usuario
 WHERE r.estado='cerrada' AND privado.ver_convocado(r.id,c.id_usuario);
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
          FROM privado.convocados_asistencia c
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
    'nombre', r.nombre,
    'numero', r.numero,
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
        AND EXISTS (SELECT 1 FROM privado.convocados_asistencia convocado
          WHERE convocado.reunion=r.id AND coalesce(convocado.id_unidad::TEXT,'sin-unidad')=g.clave)
        AND (
          actor.rol = 'directiva'
          OR EXISTS (
            SELECT 1
            FROM privado.convocados_asistencia c
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
      FROM privado.convocados_asistencia c
      JOIN public.usuarios u ON u.id_usuario = c.id_usuario
      WHERE c.reunion = r.id
        AND privado.ver_convocado(r.id, c.id_usuario)
    ), '[]'::JSONB)
  );
END;
$$;
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
    FROM privado.convocados_asistencia
    WHERE reunion = p_id
    ORDER BY id_usuario
  LOOP
    SELECT * INTO anterior
    FROM public.asistencias
    WHERE id_usuario = c.id_usuario AND id_reunion = r.id
    FOR UPDATE;

    IF anterior.id_asistencia IS NOT NULL
       AND anterior.id_ciclo <> r.id_ciclo THEN
      RAISE EXCEPTION 'Existe un registro de otro ciclo en esta fecha.'
        USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.asistencias (
      id_usuario, id_ciclo, fecha, estado, id_reunion
    )
    VALUES (
      c.id_usuario, r.id_ciclo, r.fecha, c.estado, r.id
    )
    ON CONFLICT (id_reunion, id_usuario)
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
        FROM privado.convocados_asistencia cc
        WHERE cc.reunion = p_id
          AND cc.id_usuario = x.id_usuario
          AND coalesce(cc.id_unidad::TEXT, 'sin-unidad') = v_clave
      )
    )
    OR jsonb_array_length(cambios) <> (
      SELECT count(*)
      FROM privado.convocados_asistencia cc
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
    SELECT * INTO c FROM privado.convocados_asistencia
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
          AND EXISTS(SELECT 1 FROM privado.convocados_asistencia elegible
            WHERE elegible.reunion=p_id AND coalesce(elegible.id_unidad::TEXT,'sin-unidad')=unidades_revisadas.clave)
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
    FROM privado.convocados_asistencia
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
 'privado.ver_convocado(uuid,uuid)','privado.pase_publicado(uuid,uuid)',
 'privado.publicar_reunion(uuid)','public.reunion_crear_turno(date,text)',
 'public.reunion_crear(date)','public.reuniones_listar_turnos()',
 'public.historial_matriz_turnos()','public.reunion_panel(uuid)',
 'public.reunion_accion(uuid,bigint,text,jsonb)'
 ] LOOP
  EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
  EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
  IF f<>'privado.publicar_reunion(uuid)' THEN
   EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated';
  END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('009_pases_por_reunion') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
