-- Organización anual. Ejecutar después de 013, como postgres.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='013_cierre_cuotas') THEN RAISE EXCEPTION 'Ejecuta primero 013_cierre_cuotas.sql'; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir exactamente un ciclo activo'; END IF;
END $$;
ALTER TABLE public.unidades ADD COLUMN IF NOT EXISTS id_ciclo UUID REFERENCES public.ciclos;
ALTER TABLE public.unidades ADD COLUMN IF NOT EXISTS es_activa BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.unidades ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1;
ALTER TABLE public.unidades ADD COLUMN IF NOT EXISTS foto_path TEXT;
UPDATE public.unidades SET id_ciclo=(SELECT id_ciclo FROM public.ciclos WHERE es_activo) WHERE id_ciclo IS NULL;
ALTER TABLE public.unidades ALTER COLUMN id_ciclo SET NOT NULL;
ALTER TABLE public.clases ADD COLUMN IF NOT EXISTS es_activa BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.clases ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 1;
CREATE UNIQUE INDEX IF NOT EXISTS un_ciclo_activo ON public.ciclos(es_activo) WHERE es_activo;

-- Identidad y Auth permanecen en usuarios. Sus campos organizativos son la
-- proyección compatible de la inscripción actual para las RPC existentes.
CREATE TABLE IF NOT EXISTS privado.inscripciones (
 id_usuario UUID NOT NULL REFERENCES public.usuarios,
 id_ciclo UUID NOT NULL REFERENCES public.ciclos,
 id_unidad UUID REFERENCES public.unidades,
 id_clase UUID REFERENCES public.clases,
 rol TEXT NOT NULL,
 activo BOOLEAN NOT NULL,
 nombre_unidad TEXT,
 nombre_clase TEXT,
 PRIMARY KEY(id_usuario,id_ciclo)
);
ALTER TABLE privado.inscripciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.inscripciones FROM PUBLIC,anon,authenticated;
INSERT INTO privado.inscripciones SELECT u.id_usuario,u.id_ciclo,u.id_unidad,u.id_clase,u.rol,u.es_activo,un.nombre,c.nombre
 FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad) LEFT JOIN public.clases c USING(id_clase)
 ON CONFLICT DO NOTHING;
DO $$ BEGIN
 IF EXISTS(SELECT 1 FROM privado.inscripciones WHERE activo AND rol IN ('capitan','subcapitan') AND id_unidad IS NOT NULL GROUP BY id_ciclo,id_unidad,rol HAVING count(*)>1) THEN
 RAISE EXCEPTION 'Hay más de un capitán o subcapitán en una unidad. Ajusta sus roles antes de ejecutar 014.'; END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS un_cargo_por_unidad ON privado.inscripciones(id_ciclo,id_unidad,rol)
 WHERE activo AND rol IN ('capitan','subcapitan') AND id_unidad IS NOT NULL;
CREATE TABLE IF NOT EXISTS privado.historial_organizacion (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),auth_id UUID,accion TEXT NOT NULL,datos JSONB NOT NULL,fecha TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE privado.historial_organizacion ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.historial_organizacion FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION privado.validar_inscripcion() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(728403);
 IF NEW.id_unidad IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.unidades WHERE id_unidad=NEW.id_unidad AND id_ciclo=NEW.id_ciclo AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una unidad activa del ciclo actual.' USING ERRCODE='22023'; END IF;
 IF NEW.id_clase IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.clases WHERE id_clase=NEW.id_clase AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una clase activa.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol IN ('capitan','subcapitan') AND NEW.id_unidad IS NULL THEN
 RAISE EXCEPTION 'Asigna una unidad al capitán o subcapitán.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol IN ('capitan','subcapitan') AND EXISTS(SELECT 1 FROM privado.inscripciones i WHERE i.id_ciclo=NEW.id_ciclo AND i.id_unidad=NEW.id_unidad AND i.rol=NEW.rol AND i.activo AND i.id_usuario<>NEW.id_usuario) THEN
 RAISE EXCEPTION 'La unidad ya tiene ese cargo. Revócalo antes de nombrar a otra persona.' USING ERRCODE='23505'; END IF;
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION privado.sincronizar_inscripcion() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 INSERT INTO privado.inscripciones(id_usuario,id_ciclo,id_unidad,id_clase,rol,activo,nombre_unidad,nombre_clase)
 VALUES(NEW.id_usuario,NEW.id_ciclo,NEW.id_unidad,NEW.id_clase,NEW.rol,NEW.es_activo,
 (SELECT nombre FROM public.unidades WHERE id_unidad=NEW.id_unidad),(SELECT nombre FROM public.clases WHERE id_clase=NEW.id_clase))
 ON CONFLICT(id_usuario,id_ciclo) DO UPDATE SET id_unidad=excluded.id_unidad,id_clase=excluded.id_clase,rol=excluded.rol,activo=excluded.activo,nombre_unidad=excluded.nombre_unidad,nombre_clase=excluded.nombre_clase;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS validar_inscripcion ON public.usuarios;
CREATE TRIGGER validar_inscripcion BEFORE INSERT OR UPDATE OF id_ciclo,id_unidad,id_clase,rol,es_activo ON public.usuarios FOR EACH ROW EXECUTE FUNCTION privado.validar_inscripcion();
DROP TRIGGER IF EXISTS sincronizar_inscripcion ON public.usuarios;
CREATE TRIGGER sincronizar_inscripcion AFTER INSERT OR UPDATE ON public.usuarios FOR EACH ROW EXECUTE FUNCTION privado.sincronizar_inscripcion();

CREATE OR REPLACE FUNCTION privado.editar_unidad(p_id UUID) RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.unidades un JOIN public.ciclos c USING(id_ciclo) JOIN public.usuarios u ON u.id_usuario=privado.mi_id()
 WHERE un.id_unidad=p_id AND c.es_activo AND (u.rol='directiva' OR (un.es_activa AND u.id_ciclo=c.id_ciclo AND u.id_unidad=un.id_unidad AND u.rol IN ('consejero','capitan','subcapitan'))));
$$;

CREATE OR REPLACE FUNCTION public.organizacion_panel(p_ciclo UUID DEFAULT NULL) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ciclo UUID; actor public.usuarios%ROWTYPE; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 ciclo:=coalesce(p_ciclo,(SELECT id_ciclo FROM public.ciclos WHERE es_activo));
 IF NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND (es_activo OR actor.rol='directiva')) THEN RAISE EXCEPTION 'Ciclo no disponible.' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('id_ciclo',ciclo,'vigente',EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo),'rol',actor.rol,
 'ciclos',(SELECT jsonb_agg(to_jsonb(c) ORDER BY anio DESC) FROM public.ciclos c WHERE es_activo OR actor.rol='directiva'),
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u)||jsonb_build_object('editable',privado.editar_unidad(u.id_unidad)) ORDER BY nombre) FROM public.unidades u WHERE id_ciclo=ciclo),'[]'::jsonb),
 'clases',coalesce((SELECT jsonb_agg(to_jsonb(c)||jsonb_build_object('nombre',CASE WHEN EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo) THEN c.nombre ELSE coalesce((SELECT i.nombre_clase FROM privado.inscripciones i WHERE i.id_ciclo=ciclo AND i.id_clase=c.id_clase LIMIT 1),c.nombre) END) ORDER BY nombre) FROM public.clases c),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',i.id_usuario,'nombre',u.nombres||' '||u.apellido,'id_unidad',i.id_unidad,'id_clase',i.id_clase,'rol',i.rol,'activo',i.activo,'version',u.version_perfil,'unidad',i.nombre_unidad,'clase',i.nombre_clase) ORDER BY u.apellido,u.nombres)
 FROM privado.inscripciones i JOIN public.usuarios u USING(id_usuario) WHERE i.id_ciclo=ciclo AND (i.activo OR actor.rol='directiva')),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.organizacion_guardar(p_accion TEXT,p_datos JSONB) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
#variable_conflict use_variable
<<org>>
DECLARE ciclo UUID; unidad public.unidades%ROWTYPE; clase public.clases%ROWTYPE; miembro public.usuarios%ROWTYPE; id UUID; nombre TEXT; nuevo UUID; anio INTEGER; BEGIN
 -- Mismo orden que calendario y cuotas; iniciar ciclo es atómico respecto a ambos.
 PERFORM pg_advisory_xact_lock(728401); PERFORM pg_advisory_xact_lock(728402); PERFORM pg_advisory_xact_lock(728403);
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF (p_datos->>'id_ciclo')::uuid IS DISTINCT FROM ciclo THEN RAISE EXCEPTION 'Cambió el ciclo. Actualiza la pantalla.' USING ERRCODE='40001'; END IF;
 IF p_accion<>'identidad' AND NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva administra la organización.' USING ERRCODE='42501'; END IF;
 id:=(p_datos->>'id')::uuid; nombre:=nullif(btrim(p_datos->>'nombre'),'');
 IF p_accion IN ('unidad','identidad') THEN
 SELECT * INTO unidad FROM public.unidades WHERE id_unidad=id;
 IF p_accion='identidad' AND NOT privado.editar_unidad(id) THEN RAISE EXCEPTION 'Solo puedes editar la identidad de tu unidad.' USING ERRCODE='42501'; END IF;
 IF unidad.id_unidad IS NOT NULL AND (unidad.id_ciclo<>ciclo OR unidad.version IS DISTINCT FROM (p_datos->>'version')::bigint) THEN RAISE EXCEPTION 'La unidad cambió. Actualiza antes de guardar.' USING ERRCODE='40001'; END IF;
 IF p_accion='identidad' THEN nombre:=unidad.nombre; END IF;
 IF nombre IS NULL OR length(nombre)>100 OR length(coalesce(p_datos->>'lema',''))>255 OR length(coalesce(p_datos->>'porra',''))>5000 THEN RAISE EXCEPTION 'Revisa nombre, lema y porra.' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.unidades WHERE id_ciclo=ciclo AND lower(btrim(unidades.nombre))=lower(nombre) AND id_unidad<>id) THEN RAISE EXCEPTION 'Ya existe una unidad con ese nombre.' USING ERRCODE='23505'; END IF;
 IF nullif(p_datos->>'foto_path','') IS NOT NULL AND (split_part(p_datos->>'foto_path','/',1)<>id::text OR NOT EXISTS(SELECT 1 FROM storage.objects WHERE bucket_id='unidades-fotos' AND name=p_datos->>'foto_path')) THEN RAISE EXCEPTION 'La foto no pertenece a esta unidad.' USING ERRCODE='22023'; END IF;
 IF unidad.id_unidad IS NULL THEN
 IF p_datos->'version' IS NOT NULL AND p_datos->'version'<>'null'::jsonb THEN RAISE EXCEPTION 'Unidad no disponible.' USING ERRCODE='40001'; END IF;
 INSERT INTO public.unidades(id_unidad,id_ciclo,nombre,lema,porra) VALUES(id,ciclo,nombre,p_datos->>'lema',p_datos->>'porra');
 ELSE
 UPDATE public.unidades SET nombre=org.nombre,lema=p_datos->>'lema',porra=p_datos->>'porra',foto_path=nullif(p_datos->>'foto_path',''),version=version+1 WHERE id_unidad=id;
 END IF;
 ELSIF p_accion='clase' THEN
 SELECT * INTO clase FROM public.clases WHERE id_clase=id;
 IF clase.id_clase IS NOT NULL AND clase.version IS DISTINCT FROM (p_datos->>'version')::bigint THEN RAISE EXCEPTION 'La clase cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 IF nombre IS NULL OR length(nombre)>100 OR length(coalesce(p_datos->>'color',''))>50 THEN RAISE EXCEPTION 'Revisa nombre y color.' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.clases WHERE lower(btrim(clases.nombre))=lower(nombre) AND id_clase<>id) THEN RAISE EXCEPTION 'Ya existe esa clase.' USING ERRCODE='23505'; END IF;
 INSERT INTO public.clases(id_clase,nombre,color_distintivo) VALUES(id,nombre,p_datos->>'color')
 ON CONFLICT(id_clase) DO UPDATE SET nombre=excluded.nombre,color_distintivo=excluded.color_distintivo,version=public.clases.version+1;
 ELSIF p_accion IN ('estado_unidad','estado_clase') THEN
 IF p_accion='estado_unidad' THEN
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE id_ciclo=ciclo AND id_unidad=id) THEN RAISE EXCEPTION 'Retira las asignaciones antes de desactivar la unidad.' USING ERRCODE='22023'; END IF;
 UPDATE public.unidades SET es_activa=(p_datos->>'activo')::boolean,version=version+1 WHERE id_unidad=id AND id_ciclo=ciclo AND version=(p_datos->>'version')::bigint;
 ELSE
 IF EXISTS(SELECT 1 FROM public.usuarios WHERE id_ciclo=ciclo AND id_clase=id) THEN RAISE EXCEPTION 'Retira las asignaciones antes de desactivar la clase.' USING ERRCODE='22023'; END IF;
 UPDATE public.clases SET es_activa=(p_datos->>'activo')::boolean,version=version+1 WHERE id_clase=id AND version=(p_datos->>'version')::bigint;
 END IF;
 IF NOT FOUND THEN RAISE EXCEPTION 'El registro cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 ELSIF p_accion='asignar' THEN
 SELECT * INTO miembro FROM public.usuarios WHERE id_usuario=id AND id_ciclo=ciclo FOR UPDATE;
 IF miembro.id_usuario IS NULL OR miembro.version_perfil IS DISTINCT FROM (p_datos->>'version')::bigint THEN RAISE EXCEPTION 'El integrante cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 IF miembro.rol='directiva' OR p_datos->>'rol' NOT IN ('conquistador','consejero','capitan','subcapitan') OR p_datos->>'rol' IS NULL THEN RAISE EXCEPTION 'Asigna un cargo de integrante válido.' USING ERRCODE='22023'; END IF;
 UPDATE public.usuarios SET rol=p_datos->>'rol',id_unidad=nullif(p_datos->>'unidad','')::uuid,id_clase=nullif(p_datos->>'clase','')::uuid WHERE id_usuario=id;
 ELSIF p_accion='ciclo' THEN
 anio:=(p_datos->>'anio')::integer;
 IF anio IS NULL OR anio NOT BETWEEN 2000 AND 2200 OR anio<=(SELECT ciclos.anio FROM public.ciclos WHERE id_ciclo=ciclo) THEN RAISE EXCEPTION 'El nuevo año debe ser posterior al actual.' USING ERRCODE='22023'; END IF;
 IF EXISTS(SELECT 1 FROM public.ciclos WHERE ciclos.anio=org.anio) THEN RAISE EXCEPTION 'Ese ciclo ya existe.' USING ERRCODE='23505'; END IF;
 -- Fotos, expedientes, Auth, asistencias, ingresos e insignias no se eliminan.
 UPDATE privado.inscripciones i SET nombre_unidad=u.nombre,nombre_clase=c.nombre FROM public.usuarios m LEFT JOIN public.unidades u USING(id_unidad) LEFT JOIN public.clases c USING(id_clase) WHERE i.id_usuario=m.id_usuario AND i.id_ciclo=ciclo;
 UPDATE public.ciclos SET es_activo=false WHERE id_ciclo=ciclo;
 INSERT INTO public.ciclos(anio,es_activo) VALUES(anio,true) RETURNING id_ciclo INTO nuevo;
 UPDATE public.usuarios SET id_ciclo=nuevo,id_unidad=NULL,id_clase=NULL,rol=CASE WHEN rol IN ('capitan','subcapitan') THEN 'conquistador' ELSE rol END;
 ELSE RAISE EXCEPTION 'Acción desconocida.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.historial_organizacion(auth_id,accion,datos) VALUES(auth.uid(),p_accion,p_datos);
END $$;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('unidades-fotos','unidades-fotos',false,2097152,ARRAY['image/webp']) ON CONFLICT(id) DO NOTHING;
DROP POLICY IF EXISTS unidad_foto_leer ON storage.objects;
CREATE POLICY unidad_foto_leer ON storage.objects FOR SELECT TO authenticated USING(bucket_id='unidades-fotos' AND privado.mi_id() IS NOT NULL AND EXISTS(SELECT 1 FROM public.unidades WHERE foto_path=name));
DROP POLICY IF EXISTS unidad_foto_subir ON storage.objects;
CREATE POLICY unidad_foto_subir ON storage.objects FOR INSERT TO authenticated WITH CHECK(bucket_id='unidades-fotos' AND name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' AND privado.editar_unidad(split_part(name,'/',1)::uuid));
DROP POLICY IF EXISTS unidad_foto_limpiar ON storage.objects;
CREATE POLICY unidad_foto_limpiar ON storage.objects FOR DELETE TO authenticated USING(bucket_id='unidades-fotos' AND privado.editar_unidad(split_part(name,'/',1)::uuid) AND NOT EXISTS(SELECT 1 FROM public.unidades WHERE foto_path=name));
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.validar_inscripcion()','privado.sincronizar_inscripcion()','privado.editar_unidad(uuid)','public.organizacion_panel(uuid)','public.organizacion_guardar(text,jsonb)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres'; EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' OR f='privado.editar_unidad(uuid)' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('014_organizacion') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
