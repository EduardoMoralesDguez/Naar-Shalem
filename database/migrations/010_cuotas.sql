-- 010_cuotas.sql | Ejecutar después de 009, como postgres.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='009_pases_por_reunion') THEN
 RAISE EXCEPTION 'Ejecuta primero la migración 009.'; END IF;
END $$;
ALTER TABLE public.usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check
 CHECK(rol IN ('directiva','consejero','capitan','subcapitan','conquistador'));

CREATE OR REPLACE FUNCTION public.admin_guardar_integrante(
  p_id_usuario UUID,
  p_version BIGINT,
  p_nombres TEXT,
  p_apellido TEXT,
  p_rol TEXT,
  p_id_unidad UUID,
  p_id_clase UUID,
  p_url_foto TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actual public.usuarios%ROWTYPE;
  v_ciclos UUID[];
  v_nombres TEXT := btrim(p_nombres);
  v_apellido TEXT := btrim(p_apellido);
  v_foto TEXT := nullif(btrim(p_url_foto), '');
BEGIN
  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede administrar integrantes.';
  END IF;

  IF p_id_usuario IS NULL
    OR coalesce(length(v_nombres), 0) NOT BETWEEN 1 AND 100
    OR coalesce(length(v_apellido), 0) NOT BETWEEN 1 AND 100
    OR p_rol IS NULL
    OR p_rol NOT IN (
      'directiva',
      'consejero',
      'capitan', 'subcapitan',
      'conquistador'
    )
  THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Revisa el nombre, los apellidos y el rol del integrante.';
  END IF;

  IF v_foto IS NOT NULL AND (
    length(v_foto) > 500
    OR NOT (
      v_foto ~ '^https://[^[:space:]]+$'
      OR (
        v_foto ~ '^img/[[:alnum:]_./%-]+$'
        AND v_foto !~ '(^|/)\.\.(/|$)'
      )
    )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La foto debe ser una URL https:// o una ruta dentro de img/, de hasta 500 caracteres.';
  END IF;

  IF p_id_unidad IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.unidades
    WHERE id_unidad = p_id_unidad
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La unidad seleccionada ya no existe.';
  END IF;

  IF p_id_clase IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.clases
    WHERE id_clase = p_id_clase
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La clase seleccionada ya no existe.';
  END IF;

  IF p_version IS NULL THEN
    SELECT array_agg(id_ciclo)
    INTO v_ciclos
    FROM public.ciclos
    WHERE es_activo = TRUE;

    IF coalesce(cardinality(v_ciclos), 0) <> 1 THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'Debe existir exactamente un ciclo activo para registrar integrantes.';
    END IF;

    -- Un reintento con el mismo identificador no duplica el registro.
    IF EXISTS (
      SELECT 1
      FROM public.usuarios
      WHERE id_usuario = p_id_usuario
    ) THEN
      RAISE EXCEPTION USING
        ERRCODE = '23505',
        MESSAGE = 'Este registro ya existe. Cierra el formulario y recarga la página para comprobarlo.';
    END IF;

    INSERT INTO public.usuarios (
      id_usuario,
      id_ciclo,
      nombres,
      apellido,
      rol,
      id_unidad,
      id_clase,
      url_foto,
      es_activo
    )
    VALUES (
      p_id_usuario,
      v_ciclos[1],
      v_nombres,
      v_apellido,
      p_rol,
      p_id_unidad,
      p_id_clase,
      v_foto,
      TRUE
    );

    INSERT INTO privado.usuarios_contacto (id_usuario)
    VALUES (p_id_usuario);

    INSERT INTO privado.usuarios_salud (id_usuario)
    VALUES (p_id_usuario);
  ELSE
    SELECT *
    INTO v_actual
    FROM public.usuarios
    WHERE id_usuario = p_id_usuario
    FOR UPDATE;

    IF NOT FOUND OR NOT v_actual.es_activo THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'El integrante no existe o está inactivo.';
    END IF;

    IF v_actual.version_perfil <> p_version THEN
      RAISE EXCEPTION USING
        ERRCODE = '40001',
        MESSAGE = 'El perfil cambió mientras lo editabas. Cierra y vuelve a abrir el formulario.';
    END IF;

    IF v_actual.rol = 'directiva' AND p_rol <> 'directiva' THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'El rol de una cuenta de directiva no se cambia desde este formulario.';
    END IF;

    UPDATE public.usuarios
    SET
      nombres = v_nombres,
      apellido = v_apellido,
      rol = p_rol,
      id_unidad = p_id_unidad,
      id_clase = p_id_clase,
      url_foto = v_foto
    WHERE id_usuario = p_id_usuario;
  END IF;

  INSERT INTO privado.historial_perfiles (
    id_usuario,
    auth_id,
    accion
  )
  VALUES (
    p_id_usuario,
    auth.uid(),
    CASE
      WHEN p_version IS NULL THEN 'crear'
      ELSE 'editar'
    END
  );

  RETURN p_id_usuario;
END;
$$;

CREATE OR REPLACE FUNCTION public.presentacion_integrantes()
RETURNS TABLE(id_usuario UUID, es_directiva BOOLEAN, cobra_cuotas BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT u.id_usuario,u.rol='directiva',u.rol IN ('conquistador','capitan','subcapitan')
  FROM public.directorio_portal() d
  JOIN public.usuarios u ON u.id_usuario=d.id_usuario;
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
    JOIN privado.convocados_asistencia c
      ON c.reunion = r.id AND c.id_usuario = p_usuario
    WHERE cm.auth_id = (SELECT auth.uid())
      AND actor.es_activo
      AND (
        actor.rol = 'directiva'
        OR actor.id_usuario = p_usuario
        OR (
          actor.rol IN ('capitan', 'subcapitan', 'consejero')
          AND actor.id_unidad = c.id_unidad
          AND actor.id_ciclo = r.id_ciclo
        )
      )
  );
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
      actor.rol IN ('capitan','subcapitan')
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
              WHEN actor.rol IN ('directiva', 'capitan','subcapitan')
              THEN c.motivo
            END,
          'puede_justificar',
            actor.rol IN ('capitan','subcapitan') AND actor.id_unidad = c.id_unidad
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
     OR actor.rol NOT IN ('directiva', 'capitan','subcapitan') THEN
    RAISE EXCEPTION 'No tienes permiso.'
      USING ERRCODE = '42501';
  END IF;

  IF actor.rol IN ('capitan','subcapitan')
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

    IF actor.rol NOT IN ('capitan','subcapitan')
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

-- Importes en centavos: evita redondeos y permite abonos parciales.
CREATE TABLE IF NOT EXISTS privado.cuota_periodos(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), id_ciclo UUID NOT NULL REFERENCES public.ciclos,
 fecha DATE NOT NULL, importe INTEGER NOT NULL DEFAULT 1000 CHECK(importe=1000),
 legado BOOLEAN NOT NULL DEFAULT false, UNIQUE(id_ciclo,fecha)
);
CREATE TABLE IF NOT EXISTS privado.cuota_cuentas(
 id_usuario UUID NOT NULL REFERENCES public.usuarios, id_ciclo UUID NOT NULL REFERENCES public.ciclos,
 version BIGINT NOT NULL DEFAULT 1, PRIMARY KEY(id_usuario,id_ciclo)
);
CREATE TABLE IF NOT EXISTS privado.cuota_cargos(
 periodo UUID NOT NULL REFERENCES privado.cuota_periodos, id_usuario UUID NOT NULL REFERENCES public.usuarios,
 id_unidad UUID REFERENCES public.unidades, importe INTEGER NOT NULL CHECK(importe>0),
 PRIMARY KEY(periodo,id_usuario)
);
CREATE TABLE IF NOT EXISTS privado.cuota_ingresos(
 id UUID PRIMARY KEY, id_usuario UUID NOT NULL REFERENCES public.usuarios,
 id_ciclo UUID NOT NULL REFERENCES public.ciclos, importe INTEGER NOT NULL CHECK(importe>0),
 fecha DATE NOT NULL, creado_en TIMESTAMPTZ NOT NULL DEFAULT now(), auth_id UUID,
 anulado BOOLEAN NOT NULL DEFAULT false, nota TEXT NOT NULL DEFAULT '', legado BOOLEAN NOT NULL DEFAULT false
);
CREATE TABLE IF NOT EXISTS privado.cuota_aplicaciones(
 ingreso UUID NOT NULL REFERENCES privado.cuota_ingresos, periodo UUID NOT NULL,
 id_usuario UUID NOT NULL, importe INTEGER NOT NULL CHECK(importe>0),
 PRIMARY KEY(ingreso,periodo), FOREIGN KEY(periodo,id_usuario) REFERENCES privado.cuota_cargos
);
CREATE TABLE IF NOT EXISTS privado.cuota_operaciones(
 id UUID PRIMARY KEY, auth_id UUID NOT NULL, accion TEXT NOT NULL, datos JSONB NOT NULL,
 resultado JSONB NOT NULL, creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
DO $$ DECLARE t TEXT; BEGIN
 FOREACH t IN ARRAY ARRAY['cuota_periodos','cuota_cuentas','cuota_cargos','cuota_ingresos','cuota_aplicaciones','cuota_operaciones'] LOOP
 EXECUTE 'ALTER TABLE privado.'||t||' ENABLE ROW LEVEL SECURITY';
 EXECUTE 'REVOKE ALL ON privado.'||t||' FROM PUBLIC,anon,authenticated';
 END LOOP;
END $$;
-- Importación única, sin borrar ni reinterpretar las fechas antiguas (incluidos sábados).
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='010_cuotas') THEN
 INSERT INTO privado.cuota_periodos(id_ciclo,fecha,legado)
 SELECT DISTINCT q.id_ciclo,q.fecha_semana,true FROM public.cuotas q JOIN public.usuarios u USING(id_usuario)
 WHERE u.rol IN ('conquistador','capitan','subcapitan') ON CONFLICT DO NOTHING;
 INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo)
 SELECT DISTINCT q.id_usuario,q.id_ciclo FROM public.cuotas q JOIN public.usuarios u USING(id_usuario)
 WHERE u.rol IN ('conquistador','capitan','subcapitan') ON CONFLICT DO NOTHING;
 INSERT INTO privado.cuota_cargos(periodo,id_usuario,id_unidad,importe)
 SELECT p.id,q.id_usuario,u.id_unidad,1000 FROM public.cuotas q JOIN public.usuarios u USING(id_usuario)
 JOIN privado.cuota_periodos p ON p.id_ciclo=q.id_ciclo AND p.fecha=q.fecha_semana
 WHERE u.rol IN ('conquistador','capitan','subcapitan') ON CONFLICT DO NOTHING;
 INSERT INTO privado.cuota_ingresos(id,id_usuario,id_ciclo,importe,fecha,nota,legado)
 SELECT q.id_cuota,q.id_usuario,q.id_ciclo,q.monto_pagado*100,q.fecha_semana,'Importado del registro anterior',true
 FROM public.cuotas q JOIN public.usuarios u USING(id_usuario)
 WHERE q.monto_pagado>0 AND u.rol IN ('conquistador','capitan','subcapitan') ON CONFLICT DO NOTHING;
 INSERT INTO privado.cuota_aplicaciones(ingreso,periodo,id_usuario,importe)
 SELECT i.id,p.id,i.id_usuario,least(i.importe,1000) FROM privado.cuota_ingresos i
 JOIN privado.cuota_periodos p ON p.id_ciclo=i.id_ciclo AND p.fecha=i.fecha WHERE i.legado ON CONFLICT DO NOTHING;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION privado.cuota_visible(p_usuario UUID,p_ciclo UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios a JOIN public.usuarios u ON u.id_usuario=p_usuario
 WHERE a.id_usuario=privado.mi_id() AND u.rol IN ('conquistador','capitan','subcapitan')
 AND (a.rol='directiva' OR a.id_usuario=u.id_usuario OR
 (a.rol IN ('capitan','subcapitan') AND a.id_unidad=u.id_unidad AND a.id_ciclo=p_ciclo AND u.id_ciclo=p_ciclo)));
$$;
-- Distribuye saldo sin crear un segundo ingreso. Se invoca dentro de la transacción serializada.
CREATE OR REPLACE FUNCTION privado.cuota_aplicar(p_usuario UUID,p_ciclo UUID,p_periodos UUID[],p_ingreso UUID DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE cargo RECORD; pago RECORD; falta INTEGER; abono INTEGER; BEGIN
 FOR cargo IN SELECT c.*,p.fecha FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo
 WHERE c.id_usuario=p_usuario AND p.id_ciclo=p_ciclo AND c.periodo=ANY(p_periodos) ORDER BY p.fecha,p.id LOOP
 SELECT cargo.importe-coalesce(sum(a.importe),0) INTO falta FROM privado.cuota_aplicaciones a
 WHERE a.periodo=cargo.periodo AND a.id_usuario=p_usuario;
 FOR pago IN SELECT i.id,i.importe-coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.ingreso=i.id),0) saldo
 FROM privado.cuota_ingresos i WHERE i.id_usuario=p_usuario AND i.id_ciclo=p_ciclo AND NOT i.anulado
 AND (p_ingreso IS NULL OR i.id=p_ingreso) ORDER BY i.creado_en,i.id LOOP
 abono:=least(falta,pago.saldo); IF abono>0 THEN
 INSERT INTO privado.cuota_aplicaciones(ingreso,periodo,id_usuario,importe) VALUES(pago.id,cargo.periodo,p_usuario,abono)
 ON CONFLICT(ingreso,periodo) DO UPDATE SET importe=privado.cuota_aplicaciones.importe+excluded.importe;
 falta:=falta-abono; END IF; EXIT WHEN falta<=0;
 END LOOP;
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.cuotas_panel()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión con una cuenta activa.' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 RETURN jsonb_build_object('id_ciclo',ciclo,'hoy',(now() AT TIME ZONE 'America/Mexico_City')::date,'rol',actor.rol,
 'periodos',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.fecha DESC) FROM privado.cuota_periodos p WHERE p.id_ciclo=ciclo),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',u.id_usuario,'nombre',u.nombres||' '||u.apellido,
 'unidad',coalesce(un.nombre,'Sin unidad'),'id_unidad',u.id_unidad,'version',coalesce(c.version,1),
 'saldo',coalesce((SELECT sum(i.importe) FROM privado.cuota_ingresos i WHERE i.id_usuario=u.id_usuario AND i.id_ciclo=ciclo AND NOT i.anulado),0)
 -coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE a.id_usuario=u.id_usuario AND p.id_ciclo=ciclo),0)) ORDER BY u.apellido,u.nombres)
 FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad) LEFT JOIN privado.cuota_cuentas c ON c.id_usuario=u.id_usuario AND c.id_ciclo=ciclo
 WHERE u.id_ciclo=ciclo AND privado.cuota_visible(u.id_usuario,ciclo) AND (u.es_activo OR actor.rol='directiva')),'[]'::jsonb),
 'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('periodo',c.periodo,'id_usuario',c.id_usuario,'importe',c.importe,
 'pagado',coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)))
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE p.id_ciclo=ciclo AND privado.cuota_visible(c.id_usuario,ciclo)),'[]'::jsonb),
 'ingresos',coalesce((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('registrado_por',coalesce((SELECT u.nombres||' '||u.apellido FROM privado.cuentas_miembros cm JOIN public.usuarios u USING(id_usuario) WHERE cm.auth_id=i.auth_id),'Registro anterior')) ORDER BY i.creado_en DESC)
 FROM privado.cuota_ingresos i WHERE i.id_ciclo=ciclo AND privado.cuota_visible(i.id_usuario,ciclo)),'[]'::jsonb),
 'bitacora',CASE WHEN actor.rol='directiva' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('fecha',o.creado_en,'accion',o.accion,'id_usuario',o.datos->>'id_usuario','motivo',o.datos->>'motivo','autor',coalesce(u.nombres||' '||u.apellido,o.auth_id::text)) ORDER BY o.creado_en DESC) FROM privado.cuota_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END,
 'aplicaciones',coalesce((SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE p.id_ciclo=ciclo AND privado.cuota_visible(a.id_usuario,ciclo)),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.cuotas_operar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; previa privado.cuota_operaciones%ROWTYPE;
 u public.usuarios%ROWTYPE; cuenta privado.cuota_cuentas%ROWTYPE; v_ingreso privado.cuota_ingresos%ROWTYPE;
 periodos UUID[]; v_periodo UUID; v_fecha DATE; monto INTEGER; pendiente INTEGER; resultado JSONB; antiguo JSONB;
 BEGIN
 PERFORM pg_advisory_xact_lock(728402);
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL OR actor.rol NOT IN ('directiva','capitan','subcapitan') THEN
 RAISE EXCEPTION 'No tienes permiso para registrar cuotas.' USING ERRCODE='42501'; END IF;
 IF p_operacion IS NULL OR p_accion IS NULL OR jsonb_typeof(p_datos) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Operación inválida.' USING ERRCODE='22023'; END IF;
 SELECT * INTO previa FROM privado.cuota_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF previa.auth_id<>auth.uid() OR previa.accion<>p_accion OR previa.datos<>p_datos THEN RAISE EXCEPTION 'Identificador de operación reutilizado.' USING ERRCODE='22023'; END IF;
 RETURN previa.resultado; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF (p_datos->>'id_ciclo')::uuid IS DISTINCT FROM ciclo THEN RAISE EXCEPTION 'El ciclo cambió. Revisa el registro pendiente.' USING ERRCODE='40001'; END IF;
 IF p_accion='periodo' THEN
 IF actor.rol<>'directiva' THEN RAISE EXCEPTION 'Solo directiva define domingos de cobro.' USING ERRCODE='42501'; END IF;
 v_fecha:=(p_datos->>'fecha')::date;
 IF v_fecha IS NULL OR extract(dow FROM v_fecha)<>0 OR extract(year FROM v_fecha)<>(SELECT anio FROM public.ciclos WHERE id_ciclo=ciclo) THEN
 RAISE EXCEPTION 'Selecciona un domingo del ciclo activo.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.cuota_periodos(id_ciclo,fecha) VALUES(ciclo,v_fecha) ON CONFLICT(id_ciclo,fecha) DO NOTHING RETURNING id INTO v_periodo;
 IF v_periodo IS NOT NULL THEN
 INSERT INTO privado.cuota_cargos(periodo,id_usuario,id_unidad,importe)
 SELECT v_periodo,id_usuario,id_unidad,1000 FROM public.usuarios WHERE es_activo AND id_ciclo=ciclo AND rol IN ('conquistador','capitan','subcapitan');
 FOR u IN SELECT us.* FROM public.usuarios us JOIN privado.cuota_cargos c ON c.id_usuario=us.id_usuario WHERE c.periodo=v_periodo LOOP
 INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,ciclo) ON CONFLICT DO NOTHING;
 PERFORM privado.cuota_aplicar(u.id_usuario,ciclo,ARRAY[v_periodo]);
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=u.id_usuario AND id_ciclo=ciclo;
 END LOOP;
 ELSE SELECT id INTO v_periodo FROM privado.cuota_periodos WHERE id_ciclo=ciclo AND cuota_periodos.fecha=v_fecha; END IF;
 resultado:=jsonb_build_object('periodo',v_periodo);
 ELSE
 SELECT * INTO u FROM public.usuarios WHERE id_usuario=(p_datos->>'id_usuario')::uuid;
 IF u.id_usuario IS NULL OR u.rol NOT IN ('conquistador','capitan','subcapitan') OR u.id_ciclo<>ciclo OR NOT privado.cuota_visible(u.id_usuario,ciclo) THEN
 RAISE EXCEPTION 'Integrante no autorizado.' USING ERRCODE='42501'; END IF;
 IF actor.rol<>'directiva' AND (actor.id_unidad IS NULL OR actor.id_unidad IS DISTINCT FROM u.id_unidad OR actor.id_ciclo<>ciclo OR NOT u.es_activo) THEN
 RAISE EXCEPTION 'Solo puedes registrar tu unidad.' USING ERRCODE='42501'; END IF;
 INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,ciclo) ON CONFLICT DO NOTHING;
 SELECT * INTO cuenta FROM privado.cuota_cuentas WHERE id_usuario=u.id_usuario AND id_ciclo=ciclo FOR UPDATE;
 IF (p_datos->>'version')::bigint IS DISTINCT FROM cuenta.version THEN RAISE EXCEPTION 'El registro cambió en otro dispositivo. Revisa antes de volver a guardar.' USING ERRCODE='40001'; END IF;
 IF p_accion IN ('pago','saldo') THEN
 SELECT coalesce(array_agg(value::uuid),'{}'::uuid[]) INTO periodos FROM jsonb_array_elements_text(coalesce(p_datos->'periodos','[]'::jsonb));
 IF EXISTS(SELECT 1 FROM unnest(periodos) x WHERE NOT EXISTS(SELECT 1 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=u.id_usuario AND p.id_ciclo=ciclo AND c.periodo=x)) THEN
 RAISE EXCEPTION 'Domingo no asignado al integrante.' USING ERRCODE='22023'; END IF;
 IF p_accion='pago' THEN
 monto:=(p_datos->>'importe')::integer; v_fecha:=(p_datos->>'fecha')::date;
 IF monto IS NULL OR monto NOT BETWEEN 1 AND 10000000 OR v_fecha IS NULL OR v_fecha>(now() AT TIME ZONE 'America/Mexico_City')::date OR length(coalesce(p_datos->>'nota',''))>500 THEN
 RAISE EXCEPTION 'Revisa importe, fecha y nota.' USING ERRCODE='22023'; END IF;
 IF actor.rol<>'directiva' THEN
 IF cardinality(periodos)<>1 OR monto<>1000 THEN RAISE EXCEPTION 'Capitán y subcapitán registran una cuota completa de $10.' USING ERRCODE='42501'; END IF;
 SELECT c.importe-coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=u.id_usuario),0) INTO pendiente
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.periodo=periodos[1] AND c.id_usuario=u.id_usuario AND p.fecha=v_fecha AND NOT p.legado;
 IF pendiente IS DISTINCT FROM 1000 THEN RAISE EXCEPTION 'Esta cuota ya tiene un pago o no corresponde al domingo indicado. Solicita revisión a directiva.' USING ERRCODE='40001'; END IF;
 END IF;
 INSERT INTO privado.cuota_ingresos(id,id_usuario,id_ciclo,importe,fecha,auth_id,nota)
 VALUES(p_operacion,u.id_usuario,ciclo,monto,v_fecha,auth.uid(),coalesce(p_datos->>'nota',''));
 PERFORM privado.cuota_aplicar(u.id_usuario,ciclo,periodos,p_operacion);
 ELSE
 IF actor.rol<>'directiva' THEN RAISE EXCEPTION 'Solo directiva aplica saldo.' USING ERRCODE='42501'; END IF;
 PERFORM privado.cuota_aplicar(u.id_usuario,ciclo,periodos);
 END IF;
 ELSIF p_accion IN ('anular','corregir') THEN
 IF actor.rol<>'directiva' THEN RAISE EXCEPTION 'Solo directiva corrige pagos.' USING ERRCODE='42501'; END IF;
 IF length(btrim(coalesce(p_datos->>'motivo',''))) NOT BETWEEN 3 AND 500 THEN RAISE EXCEPTION 'Escribe el motivo de la corrección.' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_ingreso FROM privado.cuota_ingresos WHERE id=(p_datos->>'ingreso')::uuid AND id_usuario=u.id_usuario AND id_ciclo=ciclo;
 IF v_ingreso.id IS NULL OR v_ingreso.anulado THEN RAISE EXCEPTION 'Ingreso no disponible.' USING ERRCODE='40001'; END IF;
 antiguo:=to_jsonb(v_ingreso)||jsonb_build_object('aplicaciones',(SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a WHERE a.ingreso=v_ingreso.id));
 SELECT array_agg(a.periodo) INTO periodos FROM privado.cuota_aplicaciones a WHERE a.ingreso=v_ingreso.id;
 DELETE FROM privado.cuota_aplicaciones WHERE cuota_aplicaciones.ingreso=v_ingreso.id;
 IF p_accion='anular' THEN UPDATE privado.cuota_ingresos SET anulado=true WHERE id=v_ingreso.id;
 ELSE
 monto:=(p_datos->>'importe')::integer;
 IF monto IS NULL OR monto NOT BETWEEN 1 AND 10000000 THEN RAISE EXCEPTION 'Importe inválido.' USING ERRCODE='22023'; END IF;
 UPDATE privado.cuota_ingresos SET importe=monto WHERE id=v_ingreso.id;
 PERFORM privado.cuota_aplicar(u.id_usuario,ciclo,periodos,v_ingreso.id);
 END IF;
 ELSE RAISE EXCEPTION 'Acción desconocida.' USING ERRCODE='22023'; END IF;
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=u.id_usuario AND id_ciclo=ciclo;
 resultado:=jsonb_build_object('id_usuario',u.id_usuario,'version',cuenta.version+1,'anterior',antiguo);
 END IF;
 INSERT INTO privado.cuota_operaciones(id,auth_id,accion,datos,resultado) VALUES(p_operacion,auth.uid(),p_accion,p_datos,resultado);
 RETURN resultado;
END $$;

CREATE OR REPLACE FUNCTION public.cuotas_resumen(p_usuario UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$ DECLARE ciclo UUID; total INTEGER; pagadas INTEGER; dinero BIGINT; BEGIN
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id() THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 IF NOT privado.cuota_visible(p_usuario,ciclo) THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 SELECT count(*),count(*) FILTER(WHERE c.importe<=coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)) INTO total,pagadas
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=p_usuario AND p.id_ciclo=ciclo AND p.fecha<=(now() AT TIME ZONE 'America/Mexico_City')::date;
 SELECT coalesce(sum(importe),0) INTO dinero FROM privado.cuota_ingresos WHERE id_usuario=p_usuario AND id_ciclo=ciclo AND NOT anulado;
 RETURN jsonb_build_object('total_pagado',dinero/100.0,'semanas_pagadas',pagadas,'semanas_registradas',total,'porcentaje',CASE WHEN total=0 THEN 0 ELSE round(100.0*pagadas/total) END);
END $$;
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.cuota_visible(uuid,uuid)','privado.cuota_aplicar(uuid,uuid,uuid[],uuid)','public.cuotas_panel()','public.cuotas_operar(uuid,text,jsonb)','public.cuotas_resumen(uuid)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
 EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('010_cuotas') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
