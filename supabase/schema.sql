-- Naar-Shalem: instalación NUEVA, estado final de 001–024.
-- Generado desde catálogos PostgreSQL por scripts/consolidar-schema.mjs.
-- No ejecutar sobre una instalación existente. No incluye personas ni movimientos de prueba.
-- Supabase proporciona auth.uid(), auth.users, roles anon/authenticated y Storage.
BEGIN;
SET LOCAL check_function_bodies = false;
SET LOCAL search_path = public;
DO $$ BEGIN
 IF to_regclass('public.usuarios') IS NOT NULL OR to_regclass('privado.migraciones') IS NOT NULL THEN
 RAISE EXCEPTION 'La base ya contiene Naar-Shalem. Usa migraciones incrementales.';
 END IF;
 IF to_regclass('auth.users') IS NULL OR to_regclass('storage.objects') IS NULL THEN
 RAISE EXCEPTION 'Se requiere un proyecto Supabase con Auth y Storage.';
 END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS privado;
-- UUID utiliza gen_random_uuid(), nativo de PostgreSQL 13+. No requiere extensión.


-- Tablas: columnas y nulabilidad finales.

CREATE TABLE "privado"."asistencia_operaciones" (
  "id" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "reunion" uuid NOT NULL,
  "version" bigint NOT NULL,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "epoca" uuid NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."bitacora_reuniones" (
  "id" uuid NOT NULL,
  "reunion" uuid NOT NULL,
  "auth_id" uuid,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "fecha" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."competencia_config" (
  "id" boolean NOT NULL,
  "version" bigint NOT NULL,
  "justificados" boolean NOT NULL
);

CREATE TABLE "privado"."competencia_cortes" (
  "id" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "nombre" text NOT NULL,
  "desde" date NOT NULL,
  "hasta" date NOT NULL,
  "resultados" jsonb NOT NULL,
  "auth_id" uuid NOT NULL,
  "creado_en" timestamp with time zone NOT NULL,
  "detalle" jsonb,
  "publicado_hasta" timestamp with time zone
);

CREATE TABLE "privado"."competencia_criterios" (
  "id" uuid NOT NULL,
  "nombre" text NOT NULL,
  "fuente" text NOT NULL,
  "valor" integer NOT NULL,
  "activo" boolean NOT NULL,
  "solo_conquistadores" boolean NOT NULL
);

CREATE TABLE "privado"."competencia_extras" (
  "id" uuid NOT NULL,
  "reunion" uuid NOT NULL,
  "id_usuario" uuid,
  "id_unidad" uuid,
  "nombre" text,
  "unidad" text NOT NULL,
  "puntos" integer NOT NULL,
  "motivo" text NOT NULL
);

CREATE TABLE "privado"."competencia_finales" (
  "id_ciclo" uuid NOT NULL,
  "desde" date NOT NULL,
  "hasta" date NOT NULL,
  "detalle" jsonb NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."competencia_hojas" (
  "reunion" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "fecha" date NOT NULL,
  "criterios" jsonb NOT NULL,
  "justificados" boolean NOT NULL,
  "version" bigint NOT NULL,
  "cerrado" boolean NOT NULL,
  "cerrado_en" timestamp with time zone,
  "unidades_guardadas" text[] NOT NULL
);

CREATE TABLE "privado"."competencia_marcas" (
  "reunion" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_unidad" uuid,
  "nombre" text NOT NULL,
  "unidad" text NOT NULL,
  "cumplidos" uuid[] NOT NULL,
  "automaticos_corte" uuid[],
  "rol" text
);

CREATE TABLE "privado"."competencia_operaciones" (
  "id" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "fecha" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."competencia_periodos" (
  "id" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "nombre" text NOT NULL,
  "desde" date NOT NULL,
  "hasta" date NOT NULL,
  "corte" uuid,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."competencia_reaperturas" (
  "id" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "datos" jsonb NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."convocados" (
  "reunion" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_unidad" uuid,
  "unidad" text NOT NULL,
  "estado" text NOT NULL,
  "motivo" text,
  "exento_asistencia" boolean NOT NULL
);

CREATE TABLE "privado"."cuentas_miembros" (
  "id_usuario" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "vinculado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."cuota_aplicaciones" (
  "ingreso" uuid NOT NULL,
  "periodo" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "importe" integer NOT NULL
);

CREATE TABLE "privado"."cuota_cargos" (
  "periodo" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_unidad" uuid,
  "importe" integer NOT NULL,
  "cerrado" boolean NOT NULL
);

CREATE TABLE "privado"."cuota_cuentas" (
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "version" bigint NOT NULL
);

CREATE TABLE "privado"."cuota_epoca" (
  "unica" boolean NOT NULL,
  "token" uuid NOT NULL,
  "exigir" boolean NOT NULL
);

CREATE TABLE "privado"."cuota_ingresos" (
  "id" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "importe" integer NOT NULL,
  "fecha" date NOT NULL,
  "creado_en" timestamp with time zone NOT NULL,
  "auth_id" uuid,
  "anulado" boolean NOT NULL,
  "nota" text NOT NULL,
  "legado" boolean NOT NULL
);

CREATE TABLE "privado"."cuota_operaciones" (
  "id" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "resultado" jsonb NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."cuota_periodos" (
  "id" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "fecha" date NOT NULL,
  "importe" integer NOT NULL,
  "legado" boolean NOT NULL,
  "cancelado" boolean NOT NULL,
  "gestionado_calendario" boolean NOT NULL,
  "actividad" uuid,
  "nombre" text NOT NULL,
  "hora" time without time zone NOT NULL
);

CREATE TABLE "privado"."historial_asistencias" (
  "id_evento" uuid NOT NULL,
  "id_asistencia" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "estado_anterior" text,
  "estado_nuevo" text NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."historial_calendario" (
  "id" uuid NOT NULL,
  "auth_id" uuid,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."historial_organizacion" (
  "id" uuid NOT NULL,
  "auth_id" uuid,
  "accion" text NOT NULL,
  "datos" jsonb NOT NULL,
  "fecha" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."historial_perfiles" (
  "id_evento" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "accion" text NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."historial_vinculaciones" (
  "id_evento" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "auth_id" uuid NOT NULL,
  "accion" text NOT NULL,
  "ejecutado_por" text NOT NULL,
  "creado_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."inscripciones" (
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "id_unidad" uuid,
  "id_clase" uuid,
  "rol" text NOT NULL,
  "activo" boolean NOT NULL,
  "nombre_unidad" text,
  "nombre_clase" text
);

CREATE TABLE "privado"."migraciones" (
  "version" text NOT NULL,
  "aplicada_en" timestamp with time zone NOT NULL
);

CREATE TABLE "privado"."reuniones" (
  "id" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "fecha" date NOT NULL,
  "estado" text NOT NULL,
  "version" bigint NOT NULL,
  "importada" boolean NOT NULL,
  "nombre" text NOT NULL,
  "numero" integer NOT NULL,
  "hora" time without time zone NOT NULL,
  "periodo_cuota" uuid,
  "tipo" text NOT NULL,
  "fecha_fin" date NOT NULL,
  "destinatario_unidad" uuid,
  "destinatario_clase" uuid,
  "eliminado" boolean NOT NULL
);

CREATE TABLE "privado"."unidades_revisadas" (
  "reunion" uuid NOT NULL,
  "clave" text NOT NULL,
  "nombre" text NOT NULL,
  "revisada" boolean NOT NULL
);

CREATE TABLE "privado"."usuarios_contacto" (
  "id_usuario" uuid NOT NULL,
  "celular" character varying(20),
  "contacto_emergencia" character varying(255),
  "nombre_tutor" character varying(150),
  "celular_tutor" character varying(20)
);

CREATE TABLE "privado"."usuarios_salud" (
  "id_usuario" uuid NOT NULL,
  "tipo_sangre" character varying(5),
  "alergias" text
);

CREATE TABLE "public"."asistencias" (
  "id_asistencia" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "fecha" date NOT NULL,
  "estado" character varying(15) NOT NULL,
  "version" bigint NOT NULL,
  "id_reunion" uuid NOT NULL
);

CREATE TABLE "public"."ciclos" (
  "id_ciclo" uuid NOT NULL,
  "anio" integer NOT NULL,
  "es_activo" boolean NOT NULL
);

CREATE TABLE "public"."clases" (
  "id_clase" uuid NOT NULL,
  "nombre" character varying(100) NOT NULL,
  "color_distintivo" character varying(50),
  "url_foto" character varying(500),
  "es_activa" boolean NOT NULL,
  "version" bigint NOT NULL
);

CREATE TABLE "public"."conquistador_especialidades" (
  "id_usuario" uuid NOT NULL,
  "id_especialidad" uuid NOT NULL,
  "fecha_obtencion" date NOT NULL
);

CREATE TABLE "public"."cuotas" (
  "id_cuota" uuid NOT NULL,
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "fecha_semana" date NOT NULL,
  "monto_pagado" integer NOT NULL
);

CREATE TABLE "public"."especialidades" (
  "id_especialidad" uuid NOT NULL,
  "nombre" character varying(100) NOT NULL,
  "url_imagen" character varying(500) NOT NULL
);

CREATE TABLE "public"."unidades" (
  "id_unidad" uuid NOT NULL,
  "nombre" character varying(100) NOT NULL,
  "lema" character varying(255),
  "porra" text,
  "url_foto" character varying(500),
  "id_ciclo" uuid NOT NULL,
  "es_activa" boolean NOT NULL,
  "version" bigint NOT NULL,
  "foto_path" text
);

CREATE TABLE "public"."usuarios" (
  "id_usuario" uuid NOT NULL,
  "id_ciclo" uuid NOT NULL,
  "id_unidad" uuid,
  "id_clase" uuid,
  "rol" character varying(20) NOT NULL,
  "nombres" character varying(100) NOT NULL,
  "apellido" character varying(100) NOT NULL,
  "url_foto" character varying(500),
  "es_activo" boolean NOT NULL,
  "version_perfil" bigint NOT NULL,
  "foto_path" text
);

-- Funciones finales: conserva SECURITY DEFINER, search_path y firma exactos.

CREATE OR REPLACE FUNCTION privado.actividad_cobro(p_actividad uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r privado.reuniones%ROWTYPE; p privado.cuota_periodos%ROWTYPE; u RECORD; BEGIN
 SELECT * INTO r FROM privado.reuniones WHERE id=p_actividad;
 IF r.id IS NULL OR r.tipo<>'regular' OR r.eliminado THEN RAISE EXCEPTION 'Actividad no apta para cobro.' USING ERRCODE='22023'; END IF;
 SELECT * INTO p FROM privado.cuota_periodos WHERE id=r.periodo_cuota;
 IF p.id IS NULL THEN SELECT * INTO p FROM privado.cuota_periodos WHERE actividad=r.id; END IF;
 IF p.id IS NULL THEN
 INSERT INTO privado.cuota_periodos(id_ciclo,fecha,actividad,nombre,hora,gestionado_calendario)
 VALUES(r.id_ciclo,r.fecha,r.id,r.nombre,r.hora,true) RETURNING * INTO p;
 INSERT INTO privado.cuota_cargos(periodo,id_usuario,id_unidad,importe)
 SELECT p.id,c.id_usuario,c.id_unidad,1000 FROM privado.convocados_asistencia c
 JOIN public.usuarios miembro USING(id_usuario) WHERE c.reunion=r.id AND miembro.rol IN ('conquistador','capitan','subcapitan');
 END IF;
 IF p.actividad=r.id THEN
 UPDATE privado.cuota_periodos SET fecha=r.fecha,nombre=r.nombre,hora=r.hora WHERE id=p.id;
 ELSIF p.fecha<>r.fecha THEN
 RAISE EXCEPTION 'Este cobro antiguo se comparte. Desactívalo antes de mover la actividad.' USING ERRCODE='22023';
 END IF;
 IF p.cancelado THEN UPDATE privado.cuota_cargos SET cerrado=false WHERE periodo=p.id; END IF;
 UPDATE privado.cuota_periodos SET cancelado=false WHERE id=p.id;
 FOR u IN SELECT id_usuario FROM privado.cuota_cargos WHERE periodo=p.id LOOP
 INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,r.id_ciclo) ON CONFLICT DO NOTHING;
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=u.id_usuario AND id_ciclo=r.id_ciclo;
 END LOOP;
 RETURN p.id;
END $function$;

CREATE OR REPLACE FUNCTION privado.actividad_fecha_fin()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$ BEGIN
 IF NEW.fecha_fin IS NULL THEN NEW.fecha_fin:=NEW.fecha; END IF; RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.asistencia_publicada(p_usuario uuid, p_ciclo uuid, p_fecha date)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM privado.reuniones r
    WHERE r.id_ciclo = p_ciclo
      AND r.fecha = p_fecha
      AND r.estado = 'cerrada'
      AND privado.ver_convocado(r.id, p_usuario)
  );
$function$;

CREATE OR REPLACE FUNCTION privado.bloquear_alta_reuniones()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.calendario_liberar_cobro(p_periodo uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ DECLARE p privado.cuota_periodos%ROWTYPE; BEGIN
 IF p_periodo IS NULL THEN RETURN; END IF;
 SELECT * INTO p FROM privado.cuota_periodos WHERE id=p_periodo;
 IF p.cancelado OR NOT p.gestionado_calendario OR EXISTS(
 SELECT 1 FROM privado.reuniones WHERE periodo_cuota=p.id AND estado<>'anulada') THEN RETURN; END IF;
 INSERT INTO privado.historial_calendario(auth_id,accion,datos) VALUES(auth.uid(),'liberar_cobro',jsonb_build_object('periodo',p.id,'fecha',p.fecha,
 'aplicaciones',coalesce((SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a WHERE a.periodo=p.id),'[]'::jsonb)));
 DELETE FROM privado.cuota_aplicaciones WHERE periodo=p.id;
 UPDATE privado.cuota_periodos SET cancelado=true WHERE id=p.id;
 UPDATE privado.cuota_cuentas c SET version=version+1 WHERE c.id_ciclo=p.id_ciclo
 AND EXISTS(SELECT 1 FROM privado.cuota_cargos g WHERE g.periodo=p.id AND g.id_usuario=c.id_usuario);
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_asistencia(p_reunion uuid, p_usuario uuid)
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT CASE WHEN r.estado='cerrada' OR coalesce(g.revisada,false) THEN c.estado ELSE NULL END
 FROM privado.convocados_asistencia c JOIN privado.reuniones r ON r.id=c.reunion
 LEFT JOIN privado.unidades_revisadas g ON g.reunion=c.reunion AND g.clave=coalesce(c.id_unidad::text,'sin-unidad')
 WHERE c.reunion=p_reunion AND c.id_usuario=p_usuario;
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_auto(p_reunion uuid, p_usuario uuid, p_fuente text, p_justificados boolean)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT CASE p_fuente WHEN 'asistencia' THEN EXISTS(
  SELECT 1 FROM privado.reuniones r JOIN privado.convocados_asistencia c ON c.reunion=r.id
  WHERE r.id=p_reunion AND privado.competencia_asistencia(r.id,p_usuario) IS NOT NULL AND c.id_usuario=p_usuario
  AND (c.estado='asistencia' OR (p_justificados AND c.estado='justificado'))
 ) WHEN 'cuota' THEN EXISTS(
  SELECT 1 FROM privado.reuniones r JOIN privado.cuota_periodos p ON p.id=r.periodo_cuota
  JOIN privado.cuota_cargos c ON c.periodo=p.id
  WHERE r.id=p_reunion AND NOT p.cancelado AND c.id_usuario=p_usuario
  AND coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)>=c.importe
 ) ELSE false END;
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_detalle(p_ciclo uuid, p_desde date, p_hasta date)
 RETURNS TABLE(fecha date, id_usuario uuid, id_unidad uuid, nombre text, unidad text, puntos bigint, rol text, criterio text, fuente text, criterio_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT * FROM privado.competencia_detalle_abierto(p_ciclo,p_desde,p_hasta) WHERE NOT EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=p_ciclo)
 UNION ALL SELECT f.* FROM privado.competencia_finales c CROSS JOIN LATERAL jsonb_to_recordset(c.detalle) AS f(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT,criterio TEXT,fuente TEXT,criterio_id UUID)
 WHERE c.id_ciclo=p_ciclo AND f.fecha BETWEEN p_desde AND p_hasta;
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_detalle_abierto(p_ciclo uuid, p_desde date, p_hasta date)
 RETURNS TABLE(fecha date, id_usuario uuid, id_unidad uuid, nombre text, unidad text, puntos bigint, rol text, criterio text, fuente text, criterio_id uuid)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 WITH abiertas AS (
 SELECT h.* FROM privado.competencia_hojas h JOIN privado.reuniones r ON r.id=h.reunion
 WHERE h.id_ciclo=p_ciclo AND h.fecha BETWEEN p_desde AND p_hasta AND r.tipo='regular' AND NOT r.eliminado AND r.estado<>'anulada'
 AND NOT EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=p_ciclo AND h.fecha BETWEEN c.desde AND c.hasta)
 )
 SELECT h.fecha,m.id_usuario,m.id_unidad,m.nombre,m.unidad,
 CASE WHEN CASE WHEN k->>'fuente'='manual' THEN (k->>'id')::uuid=ANY(m.cumplidos) AND privado.competencia_presencial(h.reunion,m.id_usuario,m.rol,k)
 ELSE privado.competencia_auto(h.reunion,m.id_usuario,k->>'fuente',h.justificados) END THEN (k->>'valor')::bigint ELSE 0 END,
 m.rol,k->>'nombre',k->>'fuente',(k->>'id')::uuid
 FROM abiertas h JOIN privado.competencia_marcas m ON m.reunion=h.reunion CROSS JOIN LATERAL jsonb_array_elements(h.criterios) k
 UNION ALL SELECT h.fecha,e.id_usuario,e.id_unidad,e.nombre,e.unidad,e.puntos::bigint,m.rol,'Extras','extra',NULL::uuid
 FROM abiertas h JOIN privado.competencia_extras e ON e.reunion=h.reunion LEFT JOIN privado.competencia_marcas m ON m.reunion=e.reunion AND m.id_usuario=e.id_usuario
 UNION ALL SELECT f.fecha,f.id_usuario,f.id_unidad,f.nombre,f.unidad,f.puntos,f.rol,f.criterio,f.fuente,f.criterio_id
 FROM privado.competencia_cortes c CROSS JOIN LATERAL jsonb_to_recordset(c.detalle) AS f(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT,criterio TEXT,fuente TEXT,criterio_id UUID)
 WHERE c.id_ciclo=p_ciclo AND f.fecha BETWEEN p_desde AND p_hasta
 UNION ALL SELECT f.fecha,f.id_usuario,f.id_unidad,f.nombre,f.unidad,f.puntos,f.rol,'Histórico','legado',NULL::uuid
 FROM privado.competencia_cortes c CROSS JOIN LATERAL jsonb_to_recordset(c.resultados) AS f(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT)
 WHERE c.detalle IS NULL AND c.id_ciclo=p_ciclo AND f.fecha BETWEEN p_desde AND p_hasta;
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_estadisticas(p_ciclo uuid, p_desde date, p_hasta date, p_admin boolean, p_consejeros boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 WITH sumas AS (
 SELECT criterio_id,max(criterio) criterio,fuente,id_usuario,max(nombre) nombre,sum(puntos) puntos
 FROM privado.competencia_detalle(p_ciclo,p_desde,p_hasta)
 WHERE id_usuario IS NOT NULL AND (rol='consejero')=p_consejeros AND fuente<>'legado'
 AND (p_admin OR (NOT p_consejeros AND fuente NOT IN ('cuota','extra')))
 GROUP BY criterio_id,fuente,id_usuario
 ), puestos AS (SELECT *,dense_rank() OVER(PARTITION BY criterio_id,fuente ORDER BY puntos DESC) lugar FROM sumas WHERE puntos>0),
 grupos AS (SELECT criterio_id,max(criterio) criterio,fuente,jsonb_agg(jsonb_build_object('id_usuario',id_usuario,'nombre',nombre,'puntos',puntos) ORDER BY puntos DESC,nombre,id_usuario) integrantes
 FROM puestos WHERE p_admin OR lugar=1 GROUP BY criterio_id,fuente)
 SELECT coalesce(jsonb_agg(to_jsonb(g) ORDER BY criterio),'[]'::jsonb) FROM grupos g;
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_filas(p_ciclo uuid, p_desde date, p_hasta date)
 RETURNS TABLE(fecha date, id_usuario uuid, id_unidad uuid, nombre text, unidad text, puntos bigint)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT fecha,id_usuario,id_unidad,nombre,unidad,puntos FROM privado.competencia_detalle(p_ciclo,p_desde,p_hasta);
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_guardar_019(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; anio INTEGER; anterior privado.competencia_operaciones%ROWTYPE; r privado.reuniones%ROWTYPE; h privado.competencia_hojas%ROWTYPE;
 criterios JSONB; dato JSONB; participante RECORD; criterio_id UUID; fuente TEXT; v_desde DATE; v_hasta DATE; resultados JSONB; detalle JSONB; previos JSONB; periodo privado.competencia_periodos%ROWTYPE; corte_id UUID;
BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);PERFORM pg_advisory_xact_lock(728404);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva administra puntajes.' USING ERRCODE='42501'; END IF;
 IF p_operacion IS NULL OR p_datos IS NULL OR jsonb_typeof(p_datos)<>'object' THEN RAISE EXCEPTION 'Operación inválida.' USING ERRCODE='22023'; END IF;
 SELECT * INTO anterior FROM privado.competencia_operaciones WHERE id=p_operacion;
 IF FOUND THEN
  IF anterior.auth_id IS DISTINCT FROM auth.uid() OR anterior.accion IS DISTINCT FROM p_accion OR anterior.datos IS DISTINCT FROM p_datos THEN RAISE EXCEPTION 'Identificador reutilizado.' USING ERRCODE='22023'; END IF;
  RETURN;
 END IF;
 SELECT c.id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 IF ciclo IS NULL OR (p_datos->>'id_ciclo')::uuid IS DISTINCT FROM ciclo THEN RAISE EXCEPTION 'El ciclo cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 IF p_accion IN ('criterio','criterios','justificados') THEN
  IF (p_datos->>'version_config')::bigint IS DISTINCT FROM (SELECT version FROM privado.competencia_config) THEN RAISE EXCEPTION 'Los criterios cambiaron. Actualiza.' USING ERRCODE='40001'; END IF;
  IF p_accion='justificados' THEN
   UPDATE privado.competencia_config SET justificados=(p_datos->>'valor')::boolean;
  ELSE
   IF p_accion='criterios' AND jsonb_typeof(p_datos->'criterios') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Criterios inválidos.' USING ERRCODE='22023'; END IF;
   FOR dato IN SELECT * FROM jsonb_array_elements(CASE WHEN p_accion='criterios' THEN p_datos->'criterios' ELSE jsonb_build_array(p_datos) END) LOOP
   criterio_id:=(dato->>'id')::uuid;
   SELECT k.fuente INTO fuente FROM privado.competencia_criterios k WHERE k.id=criterio_id;
   INSERT INTO privado.competencia_criterios(id,nombre,fuente,valor,activo)
   VALUES(coalesce(criterio_id,gen_random_uuid()),btrim(dato->>'nombre'),coalesce(fuente,'manual'),(dato->>'valor')::integer,(dato->>'activo')::boolean)
   ON CONFLICT(id) DO UPDATE SET nombre=excluded.nombre,valor=excluded.valor,activo=excluded.activo;
   END LOOP;
  END IF;
  UPDATE privado.competencia_config SET version=version+1;
 ELSIF p_accion='captura' THEN
  SELECT * INTO r FROM privado.reuniones WHERE id=(p_datos->>'reunion')::uuid AND id_ciclo=ciclo AND tipo='regular' AND NOT eliminado AND NOT importada AND estado<>'anulada';
  IF r.id IS NULL THEN RAISE EXCEPTION 'Reunión no disponible.' USING ERRCODE='22023'; END IF;
  IF r.version IS DISTINCT FROM (p_datos->>'version_reunion')::bigint THEN RAISE EXCEPTION 'Cambió la reunión o su lista. Actualiza antes de guardar.' USING ERRCODE='40001'; END IF;
  IF EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND r.fecha BETWEEN c.desde AND c.hasta) THEN RAISE EXCEPTION 'El periodo ya tiene corte.' USING ERRCODE='22023'; END IF;
  SELECT * INTO h FROM privado.competencia_hojas WHERE reunion=r.id;
  IF coalesce(h.version,0) IS DISTINCT FROM (p_datos->>'version')::bigint THEN RAISE EXCEPTION 'El puntaje cambió. Actualiza.' USING ERRCODE='40001'; END IF;
  IF h.reunion IS NULL AND (p_datos->>'version_config')::bigint IS DISTINCT FROM (SELECT version FROM privado.competencia_config) THEN RAISE EXCEPTION 'Los criterios cambiaron. Actualiza.' USING ERRCODE='40001'; END IF;
  criterios:=coalesce(h.criterios,(SELECT jsonb_agg(to_jsonb(k) ORDER BY k.fuente,k.nombre) FROM privado.competencia_criterios k WHERE activo),'[]'::jsonb);
  IF jsonb_typeof(p_datos->'integrantes') IS DISTINCT FROM 'array' OR jsonb_typeof(p_datos->'extras') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION 'Captura incompleta.' USING ERRCODE='22023'; END IF;
  IF (SELECT count(*) FROM jsonb_array_elements(p_datos->'integrantes'))<>(SELECT count(*) FROM privado.convocados_asistencia c WHERE c.reunion=r.id)
   OR (SELECT count(DISTINCT x->>'id_usuario') FROM jsonb_array_elements(p_datos->'integrantes') x)<>jsonb_array_length(p_datos->'integrantes')
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_datos->'integrantes') x WHERE NOT EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND c.id_usuario=(x->>'id_usuario')::uuid)) THEN RAISE EXCEPTION 'La lista de integrantes no coincide. Actualiza.' USING ERRCODE='40001'; END IF;
  INSERT INTO privado.competencia_hojas(reunion,id_ciclo,fecha,criterios,justificados)
  VALUES(r.id,ciclo,r.fecha,criterios,(SELECT c.justificados FROM privado.competencia_config c))
  ON CONFLICT(reunion) DO UPDATE SET version=privado.competencia_hojas.version+1;
  SELECT jsonb_object_agg(id_usuario::text,rol) INTO previos FROM privado.competencia_marcas WHERE reunion=r.id;
  DELETE FROM privado.competencia_marcas WHERE reunion=r.id;
  FOR dato IN SELECT * FROM jsonb_array_elements(p_datos->'integrantes') LOOP
   IF jsonb_typeof(dato->'cumplidos') IS DISTINCT FROM 'array' OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(dato->'cumplidos') x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(criterios) k WHERE k->>'id'=x AND k->>'fuente'='manual')) THEN RAISE EXCEPTION 'Criterio inválido. Asistencia y cuota se calculan automáticamente.' USING ERRCODE='22023'; END IF;
   INSERT INTO privado.competencia_marcas(reunion,id_usuario,id_unidad,nombre,unidad,cumplidos,rol)
   SELECT r.id,c.id_usuario,c.id_unidad,u.nombres||' '||u.apellido,c.unidad,ARRAY(SELECT DISTINCT x::uuid FROM jsonb_array_elements_text(dato->'cumplidos') x JOIN jsonb_array_elements(criterios) k ON k->>'id'=x WHERE privado.competencia_presencial(r.id,c.id_usuario,coalesce(previos->>c.id_usuario::text,u.rol),k)),coalesce(previos->>c.id_usuario::text,u.rol)
   FROM privado.convocados_asistencia c JOIN public.usuarios u USING(id_usuario) WHERE c.reunion=r.id AND c.id_usuario=(dato->>'id_usuario')::uuid;
  END LOOP;
  DELETE FROM privado.competencia_extras WHERE reunion=r.id;
  FOR dato IN SELECT * FROM jsonb_array_elements(p_datos->'extras') LOOP
   IF nullif(dato->>'id_usuario','') IS NOT NULL THEN
    SELECT * INTO participante FROM privado.competencia_marcas m WHERE m.reunion=r.id AND m.id_usuario=(dato->>'id_usuario')::uuid;
    IF NOT FOUND THEN RAISE EXCEPTION 'Integrante no convocado.' USING ERRCODE='22023'; END IF;
    INSERT INTO privado.competencia_extras(reunion,id_usuario,id_unidad,nombre,unidad,puntos,motivo)
    VALUES(r.id,participante.id_usuario,participante.id_unidad,participante.nombre,participante.unidad,(dato->>'puntos')::integer,btrim(dato->>'motivo'));
   ELSE
    SELECT u.id_unidad,u.nombre INTO participante FROM public.unidades u WHERE u.id_unidad=(dato->>'id_unidad')::uuid AND u.id_ciclo=ciclo AND u.es_activa;
    IF NOT FOUND THEN RAISE EXCEPTION 'Unidad no disponible.' USING ERRCODE='22023'; END IF;
    INSERT INTO privado.competencia_extras(reunion,id_unidad,unidad,puntos,motivo) VALUES(r.id,participante.id_unidad,participante.nombre,(dato->>'puntos')::integer,btrim(dato->>'motivo'));
   END IF;
  END LOOP;
 ELSIF p_accion='periodo' THEN
  v_desde:=(p_datos->>'desde')::date;v_hasta:=(p_datos->>'hasta')::date;
  IF v_desde IS NULL OR v_hasta IS NULL OR v_hasta<v_desde OR v_desde<make_date(anio,1,1) OR v_hasta>make_date(anio,12,31) OR length(btrim(coalesce(p_datos->>'nombre',''))) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Revisa el nombre y las fechas del periodo.' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND c.desde<=v_hasta AND c.hasta>=v_desde)
   OR EXISTS(SELECT 1 FROM privado.competencia_periodos p WHERE p.id_ciclo=ciclo AND p.corte IS NULL AND p.desde<=v_hasta AND p.hasta>=v_desde) THEN RAISE EXCEPTION 'Las fechas ya pertenecen a otro periodo.' USING ERRCODE='22023'; END IF;
  INSERT INTO privado.competencia_periodos(id_ciclo,nombre,desde,hasta) VALUES(ciclo,btrim(p_datos->>'nombre'),v_desde,v_hasta);
 ELSIF p_accion='finalizar' THEN
  SELECT * INTO periodo FROM privado.competencia_periodos WHERE id=(p_datos->>'periodo')::uuid AND id_ciclo=ciclo;
  IF periodo.id IS NULL OR periodo.corte IS NOT NULL THEN RAISE EXCEPTION 'Periodo no disponible o ya finalizado.' USING ERRCODE='22023'; END IF;
  v_desde:=periodo.desde;v_hasta:=least(periodo.hasta,(now() AT TIME ZONE 'America/Mexico_City')::date);
  IF v_hasta<v_desde THEN RAISE EXCEPTION 'El periodo aún no comienza.' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND c.desde<=v_hasta AND c.hasta>=v_desde) THEN RAISE EXCEPTION 'Las fechas ya tienen un corte.' USING ERRCODE='22023'; END IF;
  -- El cierre anticipado conserva lo guardado hasta hoy. No incorpora reuniones futuras.
  SELECT coalesce(jsonb_agg(to_jsonb(f)),'[]'::jsonb) INTO detalle FROM privado.competencia_detalle(ciclo,v_desde,v_hasta) f;
  SELECT coalesce(jsonb_agg(to_jsonb(f)),'[]'::jsonb) INTO resultados FROM privado.competencia_filas(ciclo,v_desde,v_hasta) f;
  UPDATE privado.competencia_marcas m SET
   cumplidos=ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(hh.criterios) k WHERE (k->>'id')::uuid=ANY(m.cumplidos) AND privado.competencia_presencial(hh.reunion,m.id_usuario,m.rol,k)),
   automaticos_corte=ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(hh.criterios) k WHERE k->>'fuente'<>'manual' AND privado.competencia_auto(hh.reunion,m.id_usuario,k->>'fuente',hh.justificados))
  FROM privado.competencia_hojas hh WHERE hh.reunion=m.reunion AND hh.id_ciclo=ciclo AND hh.fecha BETWEEN v_desde AND v_hasta;
  INSERT INTO privado.competencia_cortes(id_ciclo,nombre,desde,hasta,resultados,detalle,auth_id,publicado_hasta)
  VALUES(ciclo,periodo.nombre,v_desde,v_hasta,resultados,detalle,auth.uid(),now()+interval '3 days') RETURNING id INTO corte_id;
  UPDATE privado.competencia_periodos SET corte=corte_id WHERE id=periodo.id;
 ELSE RAISE EXCEPTION 'Acción no disponible.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_guardar_020(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; anio INTEGER; anterior privado.competencia_operaciones%ROWTYPE; c privado.competencia_cortes%ROWTYPE; detalle JSONB; BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);PERFORM pg_advisory_xact_lock(728404);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva administra puntajes.' USING ERRCODE='42501'; END IF;
 SELECT * INTO anterior FROM privado.competencia_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF anterior.auth_id IS DISTINCT FROM auth.uid() OR anterior.accion IS DISTINCT FROM p_accion OR anterior.datos IS DISTINCT FROM p_datos THEN RAISE EXCEPTION 'Identificador reutilizado.' USING ERRCODE='22023'; END IF;RETURN;END IF;
 SELECT ci.id_ciclo,ci.anio INTO ciclo,anio FROM public.ciclos ci WHERE es_activo;
 IF ciclo IS NULL OR ciclo IS DISTINCT FROM (p_datos->>'id_ciclo')::uuid THEN RAISE EXCEPTION 'El ciclo cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 IF EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=ciclo) AND p_accion<>'reabrir_ciclo' THEN RAISE EXCEPTION 'Reabre el ciclo para modificar puntajes.' USING ERRCODE='22023'; END IF;
 IF p_accion='reabrir_corte' THEN
 SELECT * INTO c FROM privado.competencia_cortes WHERE id=(p_datos->>'corte')::uuid AND id_ciclo=ciclo;
 IF c.id IS NULL THEN RAISE EXCEPTION 'Corte no disponible.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.competencia_reaperturas(id_ciclo,datos) VALUES(ciclo,to_jsonb(c));
 UPDATE privado.competencia_periodos SET corte=NULL,hasta=c.hasta WHERE corte=c.id;
 UPDATE privado.competencia_marcas m SET automaticos_corte=NULL FROM privado.competencia_hojas h WHERE h.reunion=m.reunion AND h.id_ciclo=ciclo AND h.fecha BETWEEN c.desde AND c.hasta;
 DELETE FROM privado.competencia_cortes WHERE id=c.id;
 UPDATE privado.competencia_cortes SET publicado_hasta=least(publicado_hasta,now()) WHERE id_ciclo=ciclo;
 ELSIF p_accion='finalizar_ciclo' THEN
 SELECT coalesce(jsonb_agg(to_jsonb(d)),'[]'::jsonb) INTO detalle FROM privado.competencia_detalle(ciclo,make_date(anio,1,1),make_date(anio,12,31)) d;
 INSERT INTO privado.competencia_finales(id_ciclo,desde,hasta,detalle) VALUES(ciclo,make_date(anio,1,1),make_date(anio,12,31),detalle);
 ELSIF p_accion='reabrir_ciclo' THEN
 IF NOT EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=ciclo) THEN RAISE EXCEPTION 'El ciclo no está finalizado.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.competencia_reaperturas(id_ciclo,datos) SELECT ciclo,to_jsonb(f) FROM privado.competencia_finales f WHERE id_ciclo=ciclo;
 DELETE FROM privado.competencia_finales WHERE id_ciclo=ciclo;
 -- Reabrir no reactiva una publicación de corte todavía vigente.
 UPDATE privado.competencia_cortes SET publicado_hasta=least(publicado_hasta,now()) WHERE id_ciclo=ciclo;
 ELSE PERFORM privado.competencia_guardar_019(p_operacion,p_accion,p_datos); RETURN; END IF;
 INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_panel_019(p_reunion uuid DEFAULT NULL::uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; anio INTEGER; es_admin BOOLEAN; hoy DATE:=(now() AT TIME ZONE 'America/Mexico_City')::date;
 desde DATE; hasta DATE; r privado.reuniones%ROWTYPE; h privado.competencia_hojas%ROWTYPE; criterios JSONB; justificados BOOLEAN; captura JSONB; publicado privado.competencia_cortes%ROWTYPE;
BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 es_admin:=privado.es_directiva();
 SELECT id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 IF ciclo IS NULL THEN RAISE EXCEPTION 'No hay ciclo activo.' USING ERRCODE='22023'; END IF;
 desde:=coalesce(p_desde,(SELECT max(c.hasta)+1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo),greatest(make_date(anio,1,1),least(date_trunc('month',hoy)::date,make_date(anio,12,1))));
 IF p_desde IS NULL AND desde>make_date(anio,12,31) THEN desde:=make_date(anio,1,1); END IF;
 hasta:=coalesce(p_hasta,greatest(desde,least(hoy,make_date(anio,12,31))));
 IF desde<make_date(anio,1,1) OR hasta>make_date(anio,12,31) OR hasta<desde THEN RAISE EXCEPTION 'Selecciona fechas del ciclo actual.' USING ERRCODE='22023'; END IF;
 IF NOT es_admin THEN
  IF p_reunion IS NOT NULL THEN RAISE EXCEPTION 'Solo directiva captura puntajes.' USING ERRCODE='42501'; END IF;
  SELECT * INTO publicado FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND c.publicado_hasta>now() ORDER BY c.creado_en DESC,c.id LIMIT 1;
  RETURN jsonb_build_object('admin',false,'id_ciclo',ciclo,'anio',anio,'hoy',hoy,'desde',publicado.desde,'hasta',publicado.hasta,'captura',NULL,
   'reuniones','[]'::jsonb,'unidades','[]'::jsonb,'cortes','[]'::jsonb,'criterios','[]'::jsonb,'bitacora','[]'::jsonb,
   'mi_puntaje',public.competencia_perfil(privado.mi_id()),'publicacion',CASE WHEN publicado.id IS NOT NULL THEN jsonb_build_object('nombre',publicado.nombre,'desde',publicado.desde,'hasta',publicado.hasta,'hasta_publicacion',publicado.publicado_hasta) END,
   'resultados',privado.competencia_ranking(ciclo,publicado.desde,publicado.hasta,false),
   'estadisticas',privado.competencia_estadisticas(ciclo,publicado.desde,publicado.hasta,false));
 END IF;
 IF p_reunion IS NOT NULL THEN
  IF NOT es_admin THEN RAISE EXCEPTION 'Solo directiva captura puntajes.' USING ERRCODE='42501'; END IF;
  SELECT * INTO r FROM privado.reuniones WHERE id=p_reunion AND id_ciclo=ciclo AND tipo='regular' AND NOT eliminado AND estado<>'anulada';
  IF r.id IS NULL THEN RAISE EXCEPTION 'Reunión no disponible.' USING ERRCODE='22023'; END IF;
  SELECT * INTO h FROM privado.competencia_hojas WHERE reunion=r.id;
  SELECT coalesce(h.criterios,(SELECT jsonb_agg(to_jsonb(k) ORDER BY k.fuente,k.nombre) FROM privado.competencia_criterios k WHERE activo),'[]'::jsonb),
   coalesce(h.justificados,c.justificados) INTO criterios,justificados FROM privado.competencia_config c;
  captura:=jsonb_build_object('id',r.id,'nombre',r.nombre,'fecha',r.fecha,'version',coalesce(h.version,0),'version_reunion',r.version,
   'version_config',(SELECT version FROM privado.competencia_config),'criterios',criterios,'justificados',justificados,
   'cerrada',EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND r.fecha BETWEEN c.desde AND c.hasta),
   'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',u.id_usuario,'nombre',u.nombres||' '||u.apellido,'id_unidad',c.id_unidad,'unidad',c.unidad,
    'rol',coalesce(m.rol,u.rol),'asistencia',privado.competencia_asistencia(r.id,u.id_usuario),'cumplidos',CASE WHEN m.automaticos_corte IS NOT NULL THEN coalesce(m.cumplidos,'{}'::uuid[]) ELSE ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(criterios) k WHERE (k->>'id')::uuid=ANY(m.cumplidos) AND privado.competencia_presencial(r.id,u.id_usuario,coalesce(m.rol,u.rol),k)) END,'automaticos',coalesce(to_jsonb(m.automaticos_corte),(SELECT jsonb_agg(k->>'id') FROM jsonb_array_elements(criterios) k WHERE k->>'fuente'<>'manual' AND privado.competencia_auto(r.id,u.id_usuario,k->>'fuente',justificados)),'[]'::jsonb),
    'cobra',EXISTS(SELECT 1 FROM privado.cuota_cargos cc JOIN privado.cuota_periodos pp ON pp.id=cc.periodo WHERE cc.periodo=r.periodo_cuota AND cc.id_usuario=u.id_usuario AND NOT pp.cancelado)
   ) ORDER BY c.unidad,u.apellido,u.nombres,u.id_usuario) FROM privado.convocados_asistencia c JOIN public.usuarios u USING(id_usuario)
   LEFT JOIN privado.competencia_marcas m ON m.reunion=c.reunion AND m.id_usuario=c.id_usuario WHERE c.reunion=r.id),'[]'::jsonb),
   'extras',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY e.id) FROM privado.competencia_extras e WHERE e.reunion=r.id),'[]'::jsonb));
 END IF;
 RETURN jsonb_build_object('admin',es_admin,'id_ciclo',ciclo,'anio',anio,'hoy',hoy,'desde',desde,'hasta',hasta,'captura',captura,
  'version_config',CASE WHEN es_admin THEN (SELECT version FROM privado.competencia_config) END,
  'justificados',CASE WHEN es_admin THEN (SELECT c.justificados FROM privado.competencia_config c) END,
  'criterios',CASE WHEN es_admin THEN (SELECT jsonb_agg(to_jsonb(k) ORDER BY k.fuente,k.nombre) FROM privado.competencia_criterios k) ELSE '[]'::jsonb END,
  'reuniones',CASE WHEN es_admin THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',rr.id,'nombre',rr.nombre,'fecha',rr.fecha,'hora',rr.hora,'guardada',hh.reunion IS NOT NULL) ORDER BY rr.fecha DESC,rr.hora,rr.numero)
    FROM privado.reuniones rr LEFT JOIN privado.competencia_hojas hh ON hh.reunion=rr.id WHERE rr.id_ciclo=ciclo AND rr.tipo='regular' AND NOT rr.eliminado AND NOT rr.importada AND rr.estado<>'anulada'),'[]'::jsonb) ELSE '[]'::jsonb END,
  'unidades',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id_unidad,'nombre',nombre) ORDER BY nombre) FROM public.unidades WHERE id_ciclo=ciclo AND es_activa),'[]'::jsonb),
  'cortes',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'nombre',nombre,'desde',c.desde,'hasta',c.hasta,'unidades',privado.competencia_ranking(ciclo,c.desde,c.hasta,false)->'unidades') ORDER BY c.hasta DESC) FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo),'[]'::jsonb),
  'periodos',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.desde DESC) FROM privado.competencia_periodos p WHERE p.id_ciclo=ciclo),'[]'::jsonb),
  'estadisticas',privado.competencia_estadisticas(ciclo,desde,hasta,true),
  'estadisticas_consejeros',privado.competencia_estadisticas(ciclo,desde,hasta,true,true),
  'resultados',privado.competencia_ranking(ciclo,desde,hasta,es_admin),
  'anual',CASE WHEN es_admin THEN privado.competencia_ranking(ciclo,make_date(anio,1,1),make_date(anio,12,31),true) ELSE NULL END,
  'bitacora',CASE WHEN es_admin THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'fecha',o.fecha,'accion',o.accion,'autor',coalesce(u.nombres||' '||u.apellido,'Directiva')) ORDER BY o.fecha DESC,o.id)
   FROM privado.competencia_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u USING(id_usuario) WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END);
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_panel_020(p_reunion uuid DEFAULT NULL::uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE p JSONB; pub JSONB; resultado JSONB; ciclo UUID; anio INTEGER; actor public.usuarios%ROWTYPE; r privado.reuniones%ROWTYPE; h privado.competencia_hojas%ROWTYPE; criterios JSONB; desde DATE; hasta DATE; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT c.id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 pub:=public.competencia_publicacion();
 IF actor.rol='directiva' THEN
 p:=privado.competencia_panel_019(p_reunion,p_desde,p_hasta);
 p:=p||jsonb_build_object('ciclo_finalizado',EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=ciclo));
 IF (p->>'ciclo_finalizado')::boolean AND p->'captura'<>'null'::jsonb THEN p:=jsonb_set(p,'{captura,cerrada}','true'); END IF;
 -- Cada celda es un total por reunión, con la unidad histórica de ese pase.
 p:=p||jsonb_build_object('historial_puntos',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY fecha,nombre) FROM (
 SELECT r.id reunion,r.fecha,r.nombre reunion_nombre,m.id_usuario,m.nombre,m.id_unidad,m.unidad,
 coalesce((SELECT sum((k->>'valor')::int) FROM jsonb_array_elements(h.criterios) k WHERE CASE WHEN k->>'fuente'='manual' THEN (k->>'id')::uuid=ANY(m.cumplidos) AND (m.automaticos_corte IS NOT NULL OR privado.competencia_presencial(r.id,m.id_usuario,m.rol,k)) ELSE CASE WHEN m.automaticos_corte IS NOT NULL THEN (k->>'id')::uuid=ANY(m.automaticos_corte) ELSE privado.competencia_auto(r.id,m.id_usuario,k->>'fuente',h.justificados) END END),0)
 +coalesce((SELECT sum(e.puntos) FROM privado.competencia_extras e WHERE e.reunion=r.id AND e.id_usuario=m.id_usuario),0) puntos
 FROM privado.competencia_marcas m JOIN privado.competencia_hojas h ON h.reunion=m.reunion JOIN privado.reuniones r ON r.id=m.reunion WHERE h.id_ciclo=ciclo AND NOT r.eliminado AND r.estado<>'anulada') t),'[]'::jsonb));
 ELSE
 p:=jsonb_build_object('admin',false,'id_ciclo',ciclo,'anio',anio,'hoy',(now() AT TIME ZONE 'America/Mexico_City')::date,'desde',make_date(anio,1,1),'hasta',make_date(anio,12,31),'cortes','[]'::jsonb,'periodos','[]'::jsonb,'criterios','[]'::jsonb,'bitacora','[]'::jsonb,'unidades','[]'::jsonb,'captura',NULL,'historial_puntos','[]'::jsonb,
 'reuniones',coalesce((SELECT jsonb_agg(jsonb_build_object('id',id,'nombre',nombre,'fecha',fecha,'hora',hora,'guardada',EXISTS(SELECT 1 FROM privado.competencia_hojas h WHERE h.reunion=r.id)) ORDER BY fecha DESC,hora DESC,numero DESC) FROM privado.competencia_reuniones_visibles() r),'[]'::jsonb));
 IF p_reunion IS NOT NULL THEN
 SELECT * INTO r FROM privado.competencia_reuniones_visibles() WHERE id=p_reunion;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Solo puedes ver la última reunión calificada de tu unidad y las posteriores.' USING ERRCODE='42501'; END IF;
 SELECT * INTO h FROM privado.competencia_hojas WHERE reunion=r.id;
 criterios:=coalesce(h.criterios,(SELECT jsonb_agg(to_jsonb(k) ORDER BY fuente,nombre) FROM privado.competencia_criterios k WHERE activo),'[]'::jsonb);
 p:=p||jsonb_build_object('captura',jsonb_build_object('id',r.id,'nombre',r.nombre,'fecha',r.fecha,'cerrada',true,'solo_lectura',true,'criterios',criterios,'extras','[]'::jsonb,
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',u.id_usuario,'nombre',u.nombres||' '||u.apellido,'id_unidad',c.id_unidad,'unidad',c.unidad,'rol',coalesce(m.rol,u.rol),'asistencia',privado.competencia_asistencia(r.id,u.id_usuario),
 'cumplidos',CASE WHEN h.reunion IS NULL THEN '{}'::uuid[] ELSE ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(criterios) k WHERE (k->>'id')::uuid=ANY(m.cumplidos) AND (m.automaticos_corte IS NOT NULL OR privado.competencia_presencial(r.id,u.id_usuario,coalesce(m.rol,u.rol),k))) END,
 'automaticos',CASE WHEN h.reunion IS NULL THEN '{}'::uuid[] ELSE coalesce(m.automaticos_corte,ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(criterios) k WHERE k->>'fuente'<>'manual' AND privado.competencia_auto(r.id,u.id_usuario,k->>'fuente',h.justificados))) END,
 'cobra',EXISTS(SELECT 1 FROM privado.cuota_cargos WHERE periodo=r.periodo_cuota AND id_usuario=u.id_usuario),
 'extras_puntos',coalesce((SELECT sum(e.puntos) FROM privado.competencia_extras e WHERE e.reunion=r.id AND e.id_usuario=u.id_usuario),0))) FROM privado.convocados_asistencia c JOIN public.usuarios u USING(id_usuario) LEFT JOIN privado.competencia_marcas m ON m.reunion=c.reunion AND m.id_usuario=c.id_usuario
 WHERE c.reunion=r.id AND (actor.id_unidad IS NOT NULL AND c.id_unidad=actor.id_unidad OR actor.id_unidad IS NULL AND c.id_usuario=actor.id_usuario)),'[]'::jsonb)));
 END IF;
 -- Siempre hay Top 15 en curso, sin puntuación ni posición. No acepta filtros arbitrarios para inferirlos.
 resultado:=privado.competencia_ranking(ciclo,make_date(anio,1,1),make_date(anio,12,31),false);
 p:=p||jsonb_build_object('resultados',resultado||jsonb_build_object('unidades','[]'::jsonb),'estadisticas','[]'::jsonb,'mi_puntaje',public.competencia_perfil(actor.id_usuario));
 END IF;
 IF pub IS NOT NULL THEN
 desde:=(pub->>'desde')::date;hasta:=(pub->>'hasta')::date;
 resultado:=privado.competencia_ranking(ciclo,desde,hasta,true);
 -- Solo durante la publicación se muestran puntuaciones y orden del Top 15 y consejeros.
 p:=p||jsonb_build_object('publicados',resultado-'individual','estadisticas_publicadas',privado.competencia_estadisticas(ciclo,desde,hasta,false));
 END IF;
 RETURN p||jsonb_build_object('publicacion',pub);
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_presencial(p_reunion uuid, p_usuario uuid, p_rol text, p_criterio jsonb)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT coalesce(privado.competencia_asistencia(p_reunion,p_usuario),'asistencia')='asistencia'
 AND NOT (p_rol='consejero' AND (coalesce((p_criterio->>'solo_conquistadores')::boolean,false) OR lower(p_criterio->>'nombre')='cuadernillo'));
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_proteger_fecha()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF (NEW.fecha IS DISTINCT FROM OLD.fecha OR NEW.tipo IS DISTINCT FROM OLD.tipo OR NEW.id_ciclo IS DISTINCT FROM OLD.id_ciclo)
 AND EXISTS(SELECT 1 FROM privado.competencia_hojas WHERE reunion=OLD.id) THEN
 RAISE EXCEPTION 'La actividad ya tiene puntajes. Conserva su fecha y tipo.' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.competencia_ranking(p_ciclo uuid, p_desde date, p_hasta date, p_admin boolean)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 WITH filas AS (SELECT * FROM privado.competencia_detalle(p_ciclo,p_desde,p_hasta)),
 individuos AS (SELECT id_usuario,max(nombre) nombre,sum(puntos) puntos FROM filas WHERE id_usuario IS NOT NULL AND rol<>'consejero' GROUP BY id_usuario),
 consejeros AS (SELECT id_usuario,max(nombre) nombre,sum(puntos) puntos FROM filas WHERE id_usuario IS NOT NULL AND rol='consejero' GROUP BY id_usuario),
 unidades AS (SELECT id_unidad,max(unidad) nombre,sum(puntos) puntos FROM filas WHERE id_unidad IS NOT NULL GROUP BY id_unidad),
 clasificados AS (SELECT *,rank() OVER(ORDER BY puntos DESC) puesto FROM individuos WHERE puntos>0),
 destacados AS (SELECT id_usuario,nombre FROM clasificados WHERE puesto<=15),
 top_ordenado AS (SELECT id_usuario,nombre,puntos FROM clasificados WHERE puesto<=15)
 SELECT jsonb_build_object(
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u) ORDER BY puntos DESC,nombre,id_unidad) FROM unidades u),'[]'::jsonb),
 'individual',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY puntos DESC,nombre,id_usuario) FROM individuos i),'[]'::jsonb) ELSE '[]'::jsonb END,
 'consejeros',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY puntos DESC,nombre,id_usuario) FROM consejeros i),'[]'::jsonb) ELSE '[]'::jsonb END,
 'top_ordenado',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY puntos DESC,nombre,id_usuario) FROM top_ordenado t),'[]'::jsonb) ELSE '[]'::jsonb END,
 'destacados',coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY random()) FROM destacados d),'[]'::jsonb));
$function$;

CREATE OR REPLACE FUNCTION privado.competencia_reuniones_visibles()
 RETURNS SETOF privado.reuniones
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT * FROM privado.reuniones_unidad_visibles(true);
$function$;

CREATE OR REPLACE FUNCTION privado.cuota_aplicar(p_usuario uuid, p_ciclo uuid, p_periodos uuid[], p_ingreso uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ DECLARE cargo RECORD; pago RECORD; falta INTEGER; abono INTEGER; BEGIN
 FOR cargo IN SELECT c.*,p.fecha FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo
 WHERE c.id_usuario=p_usuario AND p.id_ciclo=p_ciclo AND NOT p.cancelado AND c.periodo=ANY(p_periodos) ORDER BY p.fecha,p.hora,p.id LOOP
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
END $function$;

CREATE OR REPLACE FUNCTION privado.cuota_visible(p_usuario uuid, p_ciclo uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.usuarios a JOIN public.usuarios u ON u.id_usuario=p_usuario
 WHERE a.id_usuario=privado.mi_id() AND u.rol IN ('conquistador','capitan','subcapitan')
 AND (a.rol='directiva' OR a.id_usuario=u.id_usuario OR
 (a.rol IN ('capitan','subcapitan') AND a.id_unidad=u.id_unidad AND a.id_ciclo=p_ciclo AND u.id_ciclo=p_ciclo)));
$function$;

CREATE OR REPLACE FUNCTION privado.cuotas_panel_019()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión con una cuenta activa.' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 RETURN jsonb_build_object('id_ciclo',ciclo,'hoy',(now() AT TIME ZONE 'America/Mexico_City')::date,'rol',actor.rol,'epoca',(SELECT token FROM privado.cuota_epoca),
 'periodos',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.fecha DESC,p.hora DESC,p.id) FROM privado.cuota_periodos p WHERE NOT p.cancelado AND p.id_ciclo=ciclo),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',u.id_usuario,'nombre',u.nombres||' '||u.apellido,
 'unidad',coalesce(un.nombre,'Sin unidad'),'id_unidad',u.id_unidad,'version',coalesce(c.version,1),
 'saldo',coalesce((SELECT sum(i.importe) FROM privado.cuota_ingresos i WHERE i.id_usuario=u.id_usuario AND i.id_ciclo=ciclo AND NOT i.anulado),0)
 -coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE a.id_usuario=u.id_usuario AND p.id_ciclo=ciclo),0)) ORDER BY u.apellido,u.nombres)
 FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad) LEFT JOIN privado.cuota_cuentas c ON c.id_usuario=u.id_usuario AND c.id_ciclo=ciclo
 WHERE u.id_ciclo=ciclo AND privado.cuota_visible(u.id_usuario,ciclo) AND (u.es_activo OR actor.rol='directiva')),'[]'::jsonb),
 'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('periodo',c.periodo,'id_usuario',c.id_usuario,'importe',c.importe,'id_unidad',c.id_unidad,'cerrado',c.cerrado,
 'pagado',coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)))
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(c.id_usuario,ciclo)),'[]'::jsonb),
 'ingresos',coalesce((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('registrado_por',coalesce((SELECT u.nombres||' '||u.apellido FROM privado.cuentas_miembros cm JOIN public.usuarios u USING(id_usuario) WHERE cm.auth_id=i.auth_id),'Registro anterior')) ORDER BY i.creado_en DESC)
 FROM privado.cuota_ingresos i WHERE i.id_ciclo=ciclo AND privado.cuota_visible(i.id_usuario,ciclo)),'[]'::jsonb),
 'bitacora',CASE WHEN actor.rol='directiva' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('fecha',o.creado_en,'accion',o.accion,'periodo',o.datos->>'periodo','unidad',o.datos->>'unidad','id_usuario',o.datos->>'id_usuario','motivo',o.datos->>'motivo','autor',coalesce(u.nombres||' '||u.apellido,o.auth_id::text)) ORDER BY o.creado_en DESC) FROM privado.cuota_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END,
 'aplicaciones',coalesce((SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(a.id_usuario,ciclo)),'[]'::jsonb));
END $function$;

CREATE OR REPLACE FUNCTION privado.cuotas_resumen_019(p_usuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ DECLARE ciclo UUID; total INTEGER; pagadas INTEGER; dinero BIGINT; BEGIN
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id() THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 IF NOT privado.cuota_visible(p_usuario,ciclo) THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 SELECT count(*),count(*) FILTER(WHERE c.importe<=coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)) INTO total,pagadas
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=p_usuario AND p.id_ciclo=ciclo AND NOT p.cancelado AND p.fecha<=(now() AT TIME ZONE 'America/Mexico_City')::date;
 SELECT coalesce(sum(importe),0) INTO dinero FROM privado.cuota_ingresos WHERE id_usuario=p_usuario AND id_ciclo=ciclo AND NOT anulado;
 RETURN jsonb_build_object('total_pagado',dinero/100.0,'semanas_pagadas',pagadas,'semanas_registradas',total,'porcentaje',CASE WHEN total=0 THEN 0 ELSE round(100.0*pagadas/total) END);
END $function$;

CREATE OR REPLACE FUNCTION privado.editar_unidad(p_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.unidades un JOIN public.ciclos c USING(id_ciclo) JOIN public.usuarios u ON u.id_usuario=privado.mi_id()
 WHERE un.id_unidad=p_id AND c.es_activo AND (u.rol='directiva' OR (un.es_activa AND u.id_ciclo=c.id_ciclo AND u.id_unidad=un.id_unidad AND u.rol IN ('consejero','capitan','subcapitan'))));
$function$;

CREATE OR REPLACE FUNCTION privado.es_directiva()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM privado.cuentas_miembros cm
    JOIN public.usuarios u ON u.id_usuario = cm.id_usuario
    WHERE cm.auth_id = (SELECT auth.uid())
      AND u.es_activo = TRUE
      AND u.rol = 'directiva'
  );
$function$;

CREATE OR REPLACE FUNCTION privado.foto_visible(p_path text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT privado.es_directiva() OR EXISTS (
    SELECT 1
    FROM public.directorio_portal() d
    WHERE d.foto_path = p_path
  );
$function$;

CREATE OR REPLACE FUNCTION privado.incorporar_alta_reuniones()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM privado.incorporar_integrante_pendientes(NEW.id_usuario,(now() AT TIME ZONE 'America/Mexico_City')::date);
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.incorporar_integrante_pendientes(p_usuario uuid, p_desde date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u public.usuarios%ROWTYPE; r RECORD; nombre_unidad TEXT; filas INTEGER;
BEGIN
 PERFORM pg_advisory_xact_lock(728401);
 PERFORM pg_advisory_xact_lock(728402);
 PERFORM pg_advisory_xact_lock(728403);
 SELECT * INTO u FROM public.usuarios WHERE id_usuario=p_usuario;
 IF u.id_usuario IS NULL OR NOT u.es_activo OR u.rol='directiva'
 OR NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=u.id_ciclo AND es_activo) THEN RETURN; END IF;
 SELECT coalesce((SELECT nombre FROM public.unidades WHERE id_unidad=u.id_unidad),'Sin unidad') INTO nombre_unidad;
 FOR r IN SELECT * FROM privado.reuniones
 WHERE id_ciclo=u.id_ciclo AND fecha>=p_desde AND tipo='regular'
 AND NOT eliminado AND NOT importada AND estado<>'anulada' ORDER BY fecha,id LOOP
  IF r.estado='borrador' THEN
   INSERT INTO privado.convocados(reunion,id_usuario,id_unidad,unidad)
   VALUES(r.id,u.id_usuario,u.id_unidad,nombre_unidad) ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS filas=ROW_COUNT;
   IF filas>0 THEN
    INSERT INTO privado.unidades_revisadas(reunion,clave,nombre,revisada)
    VALUES(r.id,coalesce(u.id_unidad::text,'sin-unidad'),nombre_unidad,false)
    ON CONFLICT(reunion,clave) DO UPDATE SET revisada=false;
    UPDATE privado.reuniones SET version=version+1 WHERE id=r.id;
    INSERT INTO privado.bitacora_reuniones(reunion,auth_id,accion,datos)
    VALUES(r.id,auth.uid(),'incorporar',jsonb_build_object('id_usuario',u.id_usuario,'motivo','Alta en reunión pendiente'));
   END IF;
  END IF;
  -- El cierre de cuotas es independiente del pase de asistencia y se realiza por unidad.
  IF u.rol IN ('conquistador','capitan','subcapitan') AND EXISTS(
   SELECT 1 FROM privado.cuota_periodos p WHERE p.id=r.periodo_cuota AND p.actividad=r.id
   AND NOT p.cancelado AND NOT p.legado
  ) AND NOT EXISTS(
   SELECT 1 FROM privado.cuota_cargos c WHERE c.periodo=r.periodo_cuota
   AND c.id_unidad IS NOT DISTINCT FROM u.id_unidad AND c.cerrado
  ) THEN
   INSERT INTO privado.cuota_cargos(periodo,id_usuario,id_unidad,importe)
   VALUES(r.periodo_cuota,u.id_usuario,u.id_unidad,1000) ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS filas=ROW_COUNT;
   IF filas>0 THEN
    INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,u.id_ciclo)
    ON CONFLICT(id_usuario,id_ciclo) DO UPDATE SET version=privado.cuota_cuentas.version+1;
   END IF;
  END IF;
 END LOOP;
END $function$;

CREATE OR REPLACE FUNCTION privado.incrementar_version_perfil()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
BEGIN
  NEW.version_perfil := OLD.version_perfil + 1;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION privado.mi_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT u.id_usuario
  FROM privado.cuentas_miembros cm
  JOIN public.usuarios u ON u.id_usuario = cm.id_usuario
  WHERE cm.auth_id = (SELECT auth.uid())
    AND u.es_activo = TRUE;
$function$;

CREATE OR REPLACE FUNCTION privado.pase_publicado(p_reunion uuid, p_usuario uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM privado.reuniones r WHERE r.id=p_reunion
   AND r.estado='cerrada' AND privado.ver_convocado(r.id,p_usuario));
$function$;

CREATE OR REPLACE FUNCTION privado.publicar_reunion(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION privado.puede_ver_asistencia(p_usuario uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION privado.reuniones_unidad_visibles(p_puntajes boolean)
 RETURNS SETOF privado.reuniones
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 WITH actor AS (SELECT * FROM public.usuarios WHERE id_usuario=privado.mi_id() AND es_activo),
 elegibles AS (
 SELECT r.*, CASE WHEN p_puntajes THEN coalesce(h.cerrado,false) ELSE r.estado='cerrada' END finalizada
 FROM privado.reuniones r JOIN public.ciclos ci ON ci.id_ciclo=r.id_ciclo AND ci.es_activo
 LEFT JOIN privado.competencia_hojas h ON h.reunion=r.id
 WHERE r.tipo='regular' AND NOT r.eliminado AND NOT r.importada AND r.estado<>'anulada'
 AND EXISTS(SELECT 1 FROM privado.convocados_asistencia c,actor a WHERE c.reunion=r.id AND a.id_ciclo=r.id_ciclo
 AND (a.id_unidad IS NOT NULL AND c.id_unidad=a.id_unidad OR a.id_unidad IS NULL AND c.id_usuario=a.id_usuario))
 ), ultima AS (SELECT id FROM elegibles WHERE finalizada ORDER BY fecha DESC,hora DESC,numero DESC,id DESC LIMIT 1)
 SELECT r.* FROM privado.reuniones r JOIN elegibles e ON e.id=r.id WHERE NOT e.finalizada OR e.id=(SELECT id FROM ultima);
$function$;

CREATE OR REPLACE FUNCTION privado.sincronizar_inscripcion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 INSERT INTO privado.inscripciones(id_usuario,id_ciclo,id_unidad,id_clase,rol,activo,nombre_unidad,nombre_clase)
 VALUES(NEW.id_usuario,NEW.id_ciclo,NEW.id_unidad,NEW.id_clase,NEW.rol,NEW.es_activo,
 (SELECT nombre FROM public.unidades WHERE id_unidad=NEW.id_unidad),(SELECT nombre FROM public.clases WHERE id_clase=NEW.id_clase))
 ON CONFLICT(id_usuario,id_ciclo) DO UPDATE SET id_unidad=excluded.id_unidad,id_clase=excluded.id_clase,rol=excluded.rol,activo=excluded.activo,nombre_unidad=excluded.nombre_unidad,nombre_clase=excluded.nombre_clase;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.validar_inscripcion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 PERFORM pg_advisory_xact_lock(728403);
 IF NEW.id_unidad IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.unidades WHERE id_unidad=NEW.id_unidad AND id_ciclo=NEW.id_ciclo AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una unidad activa del ciclo actual.' USING ERRCODE='22023'; END IF;
 IF NEW.id_clase IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.clases WHERE id_clase=NEW.id_clase AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una clase activa.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol='capitan' AND NEW.id_unidad IS NULL THEN
 RAISE EXCEPTION 'Asigna una unidad al capitán.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol='capitan' AND (SELECT count(*) FROM privado.inscripciones i WHERE i.id_ciclo=NEW.id_ciclo AND i.id_unidad=NEW.id_unidad AND i.rol='capitan' AND i.activo AND i.id_usuario<>NEW.id_usuario)>=2 THEN
 RAISE EXCEPTION 'La unidad ya tiene dos capitanes. Revoca un cargo antes de nombrar otro.' USING ERRCODE='23505'; END IF;
 RETURN NEW;
END $function$;

CREATE OR REPLACE FUNCTION privado.ver_convocado(p_reunion uuid, p_usuario uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT EXISTS(SELECT 1 FROM public.usuarios a JOIN privado.convocados_asistencia c ON c.reunion=p_reunion AND c.id_usuario=p_usuario
 WHERE a.id_usuario=privado.mi_id() AND a.es_activo AND
 (a.rol='directiva' OR (EXISTS(SELECT 1 FROM privado.reuniones_unidad_visibles(false) r WHERE r.id=p_reunion)
 AND (a.id_unidad IS NOT NULL AND a.id_unidad=c.id_unidad OR a.id_unidad IS NULL AND a.id_usuario=p_usuario))));
$function$;

CREATE OR REPLACE FUNCTION privado.vincular_cuenta(p_id_usuario uuid, p_auth_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
DECLARE
    v_auth_actual UUID;
    v_es_activo BOOLEAN;
BEGIN
    IF p_id_usuario IS NULL OR p_auth_id IS NULL THEN
        RAISE EXCEPTION
            'Debes indicar el UUID del miembro y el UUID de su cuenta Auth.';
    END IF;

    SELECT u.es_activo
    INTO v_es_activo
    FROM public.usuarios u
    WHERE u.id_usuario = p_id_usuario
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el miembro indicado.';
    END IF;

    IF NOT v_es_activo THEN
        RAISE EXCEPTION
            'El miembro está inactivo. Revisa su expediente antes de vincularlo.';
    END IF;

    PERFORM 1
    FROM auth.users a
    WHERE a.id = p_auth_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe esa cuenta en Supabase Auth. Créala primero en Authentication > Users.';
    END IF;

    SELECT cm.auth_id
    INTO v_auth_actual
    FROM privado.cuentas_miembros cm
    WHERE cm.id_usuario = p_id_usuario;

    IF FOUND THEN
        IF v_auth_actual = p_auth_id THEN
            RAISE NOTICE 'Esta cuenta ya estaba vinculada al miembro.';
            RETURN;
        END IF;

        RAISE EXCEPTION
            'El miembro ya tiene otra cuenta vinculada. No se reemplazó el vínculo.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM privado.cuentas_miembros cm
        WHERE cm.auth_id = p_auth_id
    ) THEN
        RAISE EXCEPTION
            'Esa cuenta Auth ya pertenece a otro miembro.';
    END IF;

    INSERT INTO privado.cuentas_miembros (id_usuario, auth_id)
    VALUES (p_id_usuario, p_auth_id);

    INSERT INTO privado.historial_vinculaciones (
        id_usuario,
        auth_id,
        accion,
        ejecutado_por
    )
    VALUES (
        p_id_usuario,
        p_auth_id,
        'vincular',
        current_user
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_estado_integrante(p_id_usuario uuid, p_version bigint, p_activo boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v public.usuarios%ROWTYPE;
BEGIN
  -- Serializa cambios de estado y comprueba nuevamente quién actúa.
  PERFORM pg_catalog.pg_advisory_xact_lock(728401);

  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede cambiar el estado.';
  END IF;

  IF p_id_usuario = privado.mi_id() THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'No puedes desactivar tu propio perfil.';
  END IF;

  SELECT *
  INTO v
  FROM public.usuarios
  WHERE id_usuario = p_id_usuario
  FOR UPDATE;

  IF NOT FOUND OR p_activo IS NULL OR p_version IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Integrante o estado inválido.';
  END IF;

  IF v.version_perfil <> p_version THEN
    RAISE EXCEPTION USING
      ERRCODE = '40001',
      MESSAGE = 'El perfil cambió. Vuelve a abrirlo e inténtalo otra vez.';
  END IF;

  IF v.es_activo = p_activo THEN
    RETURN;
  END IF;

  UPDATE public.usuarios
  SET es_activo = p_activo
  WHERE id_usuario = p_id_usuario;

  INSERT INTO privado.historial_perfiles (
    id_usuario,
    auth_id,
    accion
  )
  VALUES (
    p_id_usuario,
    auth.uid(),
    CASE WHEN p_activo THEN 'activar' ELSE 'desactivar' END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_guardar_integrante(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.admin_guardar_perfil(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text, p_foto_path text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede guardar perfiles.';
  END IF;

  IF p_foto_path IS NOT NULL AND (
    split_part(p_foto_path, '/', 1) <> p_id_usuario::TEXT
    OR NOT EXISTS (
      SELECT 1
      FROM storage.objects
      WHERE bucket_id = 'integrantes-fotos'
        AND name = p_foto_path
    )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La foto no pertenece a este perfil o no terminó de subirse.';
  END IF;

  PERFORM public.admin_guardar_integrante(
    p_id_usuario,
    p_version,
    p_nombres,
    p_apellido,
    p_rol,
    p_id_unidad,
    p_id_clase,
    p_url_foto
  );

  UPDATE public.usuarios
  SET foto_path = p_foto_path
  WHERE id_usuario = p_id_usuario
    AND foto_path IS DISTINCT FROM p_foto_path;

  RETURN p_id_usuario;
END;
$function$;

CREATE OR REPLACE FUNCTION public.asistencia_operar(p_operacion uuid, p_epoca uuid, p_id uuid, p_version bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE anterior privado.asistencia_operaciones%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 IF p_operacion IS NULL OR p_epoca IS DISTINCT FROM (SELECT token FROM privado.cuota_epoca) THEN RAISE EXCEPTION 'Los datos se reiniciaron. Revisa este pendiente anterior.' USING ERRCODE='40001'; END IF;
 SELECT * INTO anterior FROM privado.asistencia_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF anterior.auth_id IS DISTINCT FROM auth.uid() OR anterior.reunion IS DISTINCT FROM p_id OR anterior.version IS DISTINCT FROM p_version OR anterior.accion IS DISTINCT FROM p_accion OR anterior.datos IS DISTINCT FROM p_datos THEN RAISE EXCEPTION 'Identificador reutilizado.' USING ERRCODE='22023'; END IF;
 RETURN;
 END IF;
 IF NOT EXISTS(SELECT 1 FROM privado.reuniones r JOIN public.ciclos c USING(id_ciclo) WHERE r.id=p_id AND c.es_activo) THEN RAISE EXCEPTION 'El ciclo cambió. Revisa el pendiente.' USING ERRCODE='40001'; END IF;
 -- La RPC existente conserva reglas de rol/unidad, versiones, cierre y fecha de justificación.
 PERFORM public.reunion_accion(p_id,p_version,p_accion,p_datos);
 INSERT INTO privado.asistencia_operaciones(id,auth_id,reunion,version,accion,datos,epoca) VALUES(p_operacion,auth.uid(),p_id,p_version,p_accion,p_datos,p_epoca);
END $function$;

CREATE OR REPLACE FUNCTION public.asistencia_resumen(p_usuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE total BIGINT; presentes BIGINT; justificados BIGINT; BEGIN
 IF privado.mi_id() IS NULL OR (NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id()) THEN
 RAISE EXCEPTION 'Solo puedes consultar tu propio progreso.' USING ERRCODE='42501'; END IF;
 SELECT count(*),count(*) FILTER(WHERE a.estado='asistencia'),count(*) FILTER(WHERE a.estado='justificado')
 INTO total,presentes,justificados FROM public.asistencias a JOIN privado.reuniones r ON r.id=a.id_reunion
 JOIN public.ciclos ci ON ci.id_ciclo=r.id_ciclo AND ci.es_activo JOIN public.usuarios u ON u.id_usuario=a.id_usuario
 WHERE a.id_usuario=p_usuario AND u.rol<>'directiva' AND r.estado='cerrada' AND NOT r.eliminado AND r.tipo='regular';
 RETURN jsonb_build_object('asistencias',presentes,'justificados',justificados,'faltas',total-presentes-justificados,'total_registros',total,
 'porcentaje',CASE WHEN total=0 THEN 0 ELSE round(100.0*(presentes+justificados)/total) END);
END $function$;

CREATE OR REPLACE FUNCTION public.asistencias_bitacora()
 RETURNS TABLE(id uuid, fecha timestamp with time zone, autor text, reunion text, accion text, datos jsonb)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva consulta la bitácora.' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT b.id,b.fecha,coalesce(u.nombres||' '||u.apellido,'Registro anterior'),r.fecha::text||' · '||r.nombre,b.accion,b.datos
 FROM privado.bitacora_reuniones b JOIN privado.reuniones r ON r.id=b.reunion JOIN public.ciclos c USING(id_ciclo)
 LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=b.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario
 WHERE c.es_activo ORDER BY b.fecha DESC,b.id;
END $function$;

CREATE OR REPLACE FUNCTION public.asistencias_contexto()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('epoca',(SELECT token FROM privado.cuota_epoca),'ciclo',(SELECT id_ciclo FROM public.ciclos WHERE es_activo));
END $function$;

CREATE OR REPLACE FUNCTION public.calendario_cancelar(p_id uuid, p_version bigint, p_motivo text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ BEGIN
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva cancela actividades.' USING ERRCODE='42501'; END IF;
 PERFORM public.reunion_accion(p_id,p_version,'anular',jsonb_build_object('motivo',p_motivo));
END $function$;

CREATE OR REPLACE FUNCTION public.calendario_eliminar(p_id uuid, p_version bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r privado.reuniones%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(728401); PERFORM pg_advisory_xact_lock(728402);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva elimina actividades.' USING ERRCODE='42501'; END IF;
 SELECT * INTO r FROM privado.reuniones WHERE id=p_id FOR UPDATE;
 IF r.id IS NULL THEN RAISE EXCEPTION 'Actividad no disponible.' USING ERRCODE='22023'; END IF;
 IF r.eliminado THEN RETURN; END IF; -- Reintento idempotente; nunca revive el registro.
 IF p_version IS DISTINCT FROM r.version THEN RAISE EXCEPTION 'La actividad cambió. Recarga antes de eliminar.' USING ERRCODE='40001'; END IF;
 UPDATE privado.reuniones SET eliminado=true,estado='anulada',version=version+1 WHERE id=p_id;
 PERFORM privado.calendario_liberar_cobro(r.periodo_cuota);
 INSERT INTO privado.historial_calendario(auth_id,accion,datos) VALUES(auth.uid(),'eliminar',jsonb_build_object('actividad',p_id,'anterior',to_jsonb(r)));
END $function$;

CREATE OR REPLACE FUNCTION public.calendario_guardar(p_id uuid, p_version bigint, p_fecha date, p_hora time without time zone, p_nombre text, p_cobra boolean, p_tipo text, p_fecha_fin date, p_unidad uuid, p_clase uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE r privado.reuniones%ROWTYPE; ciclo UUID; nombre_limpio TEXT; cobro UUID; anterior JSONB; BEGIN
 PERFORM pg_advisory_xact_lock(728401); PERFORM pg_advisory_xact_lock(728402);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva organiza actividades.' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 nombre_limpio:=btrim(regexp_replace(p_nombre,'\s+',' ','g'));
 IF p_id IS NULL OR nombre_limpio IS NULL OR length(nombre_limpio) NOT BETWEEN 1 AND 60 OR p_hora IS NULL OR p_fecha IS NULL OR p_cobra IS NULL
 OR extract(year FROM p_fecha)<>(SELECT anio FROM public.ciclos WHERE id_ciclo=ciclo)
 OR p_tipo IS NULL OR p_tipo NOT IN ('regular','practica','parcial','evento')
 OR p_fecha_fin IS NULL OR p_fecha_fin<p_fecha OR (p_tipo<>'evento' AND p_fecha_fin<>p_fecha)
 OR p_fecha_fin-p_fecha>366 OR (p_tipo<>'regular' AND p_cobra)
 OR (CASE WHEN p_tipo='parcial' THEN num_nonnulls(p_unidad,p_clase)<>1 ELSE num_nonnulls(p_unidad,p_clase)<>0 END) THEN
 RAISE EXCEPTION 'Revisa tipo, nombre, fechas, destinatarios y cobro.' USING ERRCODE='22023'; END IF;
 IF (p_unidad IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.unidades WHERE id_unidad=p_unidad))
 OR (p_clase IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.clases WHERE id_clase=p_clase)) THEN
 RAISE EXCEPTION 'La unidad o clase no existe.' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM privado.reuniones WHERE id=p_id FOR UPDATE;
 IF p_version IS NULL THEN
 IF r.id IS NOT NULL THEN
 IF NOT r.eliminado AND r.estado<>'anulada' AND r.id_ciclo=ciclo AND r.nombre=nombre_limpio AND r.fecha=p_fecha AND r.hora=p_hora
 AND (r.periodo_cuota IS NOT NULL)=p_cobra AND r.tipo=p_tipo AND r.fecha_fin=p_fecha_fin
 AND r.destinatario_unidad IS NOT DISTINCT FROM p_unidad AND r.destinatario_clase IS NOT DISTINCT FROM p_clase THEN RETURN r.id; END IF;
 RAISE EXCEPTION 'Este intento ya creó una actividad. Recarga el calendario.' USING ERRCODE='40001'; END IF;
 ELSE
 IF r.id IS NULL OR r.id_ciclo<>ciclo OR r.version<>p_version OR r.estado='anulada' OR r.eliminado THEN
 RAISE EXCEPTION 'La actividad cambió o ya no está disponible. Recarga antes de editar.' USING ERRCODE='40001'; END IF;
 IF (r.fecha<>p_fecha OR r.tipo<>p_tipo) AND (r.estado<>'borrador'
 OR EXISTS(SELECT 1 FROM privado.unidades_revisadas WHERE reunion=p_id AND revisada)
 OR EXISTS(SELECT 1 FROM privado.convocados WHERE reunion=p_id AND estado<>'falta')) THEN
 RAISE EXCEPTION 'Ya hay asistencia registrada. Conserva el tipo y fecha o elimina la actividad incorrecta.' USING ERRCODE='22023'; END IF;
 anterior:=to_jsonb(r);
 END IF;
 IF EXISTS(SELECT 1 FROM privado.reuniones WHERE id<>p_id AND NOT eliminado AND id_ciclo=ciclo AND fecha=p_fecha AND lower(nombre)=lower(nombre_limpio)) THEN
 RAISE EXCEPTION 'Ya existe una actividad con ese nombre en la fecha. Usa otro nombre.' USING ERRCODE='23505'; END IF;
 IF p_version IS NULL THEN
 INSERT INTO privado.reuniones(id,id_ciclo,fecha,hora,nombre,numero,tipo,fecha_fin,destinatario_unidad,destinatario_clase)
 SELECT p_id,ciclo,p_fecha,p_hora,nombre_limpio,coalesce(max(numero),0)+1,p_tipo,p_fecha_fin,p_unidad,p_clase
 FROM privado.reuniones WHERE id_ciclo=ciclo AND fecha=p_fecha;
 ELSE
 UPDATE privado.reuniones SET fecha=p_fecha,hora=p_hora,nombre=nombre_limpio,tipo=p_tipo,fecha_fin=p_fecha_fin,
 destinatario_unidad=p_unidad,destinatario_clase=p_clase,periodo_cuota=CASE WHEN p_cobra THEN periodo_cuota ELSE NULL END,version=version+1,
 numero=CASE WHEN fecha<>p_fecha THEN (SELECT coalesce(max(n.numero),0)+1 FROM privado.reuniones n WHERE n.id_ciclo=ciclo AND n.fecha=p_fecha) ELSE numero END WHERE id=p_id;
 END IF;
 IF p_tipo='regular' AND (p_version IS NULL OR r.tipo<>'regular') THEN
 INSERT INTO privado.convocados(reunion,id_usuario,id_unidad,unidad)
 SELECT p_id,u.id_usuario,u.id_unidad,coalesce(un.nombre,'Sin unidad') FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad)
 WHERE u.es_activo AND u.id_ciclo=ciclo AND u.rol<>'directiva';
 INSERT INTO privado.unidades_revisadas(reunion,clave,nombre)
 SELECT DISTINCT p_id,coalesce(id_unidad::text,'sin-unidad'),unidad FROM privado.convocados WHERE reunion=p_id;
 ELSIF p_tipo<>'regular' THEN
 DELETE FROM privado.unidades_revisadas WHERE reunion=p_id;
 DELETE FROM privado.convocados WHERE reunion=p_id;
 END IF;
 IF p_cobra THEN
 cobro:=privado.actividad_cobro(p_id);
 UPDATE privado.reuniones SET periodo_cuota=cobro WHERE id=p_id;
 END IF;
 IF r.periodo_cuota IS DISTINCT FROM cobro THEN PERFORM privado.calendario_liberar_cobro(r.periodo_cuota); END IF;
 INSERT INTO privado.historial_calendario(auth_id,accion,datos) VALUES(auth.uid(),CASE WHEN p_version IS NULL THEN 'crear' ELSE 'editar' END,
 jsonb_build_object('actividad',p_id,'anterior',anterior,'nuevo',(SELECT to_jsonb(n) FROM privado.reuniones n WHERE id=p_id)));
 RETURN p_id;
END $function$;

CREATE OR REPLACE FUNCTION public.calendario_listar(p_desde date, p_hasta date)
 RETURNS TABLE(id uuid, fecha date, hora text, nombre text, estado text, version bigint, cobra_cuota boolean, cobro_compartido boolean, tipo text, fecha_fin date, destinatario_unidad uuid, destinatario_clase uuid, destinatario text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT r.id,r.fecha,to_char(r.hora,'HH24:MI'),r.nombre,r.estado,r.version,r.periodo_cuota IS NOT NULL,
 EXISTS(SELECT 1 FROM privado.reuniones otra WHERE otra.id<>r.id AND otra.periodo_cuota=r.periodo_cuota AND otra.estado<>'anulada' AND NOT otra.eliminado),
 r.tipo,r.fecha_fin,r.destinatario_unidad,r.destinatario_clase,coalesce(un.nombre,cl.nombre,'Todo el club')::text
 FROM privado.reuniones r JOIN public.ciclos c ON c.id_ciclo=r.id_ciclo
 JOIN public.usuarios actor ON actor.id_usuario=privado.mi_id()
 LEFT JOIN public.unidades un ON un.id_unidad=r.destinatario_unidad
 LEFT JOIN public.clases cl ON cl.id_clase=r.destinatario_clase
 WHERE c.es_activo AND NOT r.eliminado AND r.fecha<=p_hasta AND r.fecha_fin>=p_desde
 AND p_hasta-p_desde BETWEEN 0 AND 366
 AND (r.tipo<>'parcial' OR actor.rol='directiva' OR actor.id_unidad=r.destinatario_unidad OR actor.id_clase=r.destinatario_clase)
 ORDER BY r.fecha,r.hora,r.numero;
$function$;

CREATE OR REPLACE FUNCTION public.colores_integrantes()
 RETURNS TABLE(id_usuario uuid, color_clase text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT u.id_usuario,c.color_distintivo::text FROM public.usuarios u LEFT JOIN public.clases c USING(id_clase)
 WHERE privado.mi_id() IS NOT NULL AND (u.es_activo OR privado.es_directiva());
$function$;

CREATE OR REPLACE FUNCTION public.competencia_guardar(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; anterior privado.competencia_operaciones%ROWTYPE; h privado.competencia_hojas%ROWTYPE; r privado.reuniones%ROWTYPE; BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);PERFORM pg_advisory_xact_lock(728404);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva administra puntajes.' USING ERRCODE='42501'; END IF;
 SELECT * INTO anterior FROM privado.competencia_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF anterior.auth_id IS DISTINCT FROM auth.uid() OR anterior.accion IS DISTINCT FROM p_accion OR anterior.datos IS DISTINCT FROM p_datos THEN
 RAISE EXCEPTION 'Identificador reutilizado.' USING ERRCODE='22023'; END IF; RETURN; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF ciclo IS NULL OR ciclo IS DISTINCT FROM (p_datos->>'id_ciclo')::uuid THEN RAISE EXCEPTION 'El ciclo cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 IF p_accion IN ('captura','cerrar_puntajes','reabrir_puntajes') THEN
 SELECT * INTO h FROM privado.competencia_hojas WHERE reunion=(p_datos->>'reunion')::uuid;
 IF p_accion='captura' AND coalesce(h.cerrado,false) THEN RAISE EXCEPTION 'Reabre el puntaje de esta reunión para editarlo.' USING ERRCODE='22023'; END IF;
 END IF;
 IF p_accion NOT IN ('cerrar_puntajes','reabrir_puntajes') THEN
 PERFORM privado.competencia_guardar_020(p_operacion,p_accion,p_datos);RETURN; END IF;
 SELECT * INTO r FROM privado.reuniones WHERE id=h.reunion AND id_ciclo=ciclo AND tipo='regular' AND NOT eliminado AND estado<>'anulada';
 IF r.id IS NULL THEN RAISE EXCEPTION 'Guarda primero los puntajes de esta reunión.' USING ERRCODE='22023'; END IF;
 IF h.version IS DISTINCT FROM (p_datos->>'version')::bigint OR r.version IS DISTINCT FROM (p_datos->>'version_reunion')::bigint THEN
 RAISE EXCEPTION 'La captura o el pase cambió. Actualiza antes de cerrar o reabrir.' USING ERRCODE='40001'; END IF;
 IF EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=ciclo) OR EXISTS(SELECT 1 FROM privado.competencia_cortes WHERE id_ciclo=ciclo AND h.fecha BETWEEN desde AND hasta) THEN
 RAISE EXCEPTION 'Reabre primero el corte o ciclo que contiene esta reunión.' USING ERRCODE='22023'; END IF;
 IF h.cerrado=(p_accion='cerrar_puntajes') THEN RAISE EXCEPTION 'El estado del puntaje cambió. Actualiza.' USING ERRCODE='40001'; END IF;
 UPDATE privado.competencia_hojas SET cerrado=p_accion='cerrar_puntajes',cerrado_en=CASE WHEN p_accion='cerrar_puntajes' THEN now() END,version=version+1 WHERE reunion=r.id;
 INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $function$;

CREATE OR REPLACE FUNCTION public.competencia_panel(p_reunion uuid DEFAULT NULL::uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p JSONB; h privado.competencia_hojas%ROWTYPE; bloqueado BOOLEAN; BEGIN
 p:=privado.competencia_panel_020(p_reunion,p_desde,p_hasta);
 p:=p||jsonb_build_object('api_version',21);
 p:=jsonb_set(p,'{reuniones}',coalesce((SELECT jsonb_agg(x||jsonb_build_object('puntaje_cerrado',coalesce(hh.cerrado,false)) ORDER BY n)
 FROM jsonb_array_elements(p->'reuniones') WITH ORDINALITY a(x,n) LEFT JOIN privado.competencia_hojas hh ON hh.reunion=(x->>'id')::uuid),'[]'::jsonb));
 IF p_reunion IS NOT NULL AND p->'captura'<>'null'::jsonb THEN
 SELECT * INTO h FROM privado.competencia_hojas WHERE reunion=p_reunion;
 bloqueado:=coalesce((p->'captura'->>'cerrada')::boolean,false);
 p:=jsonb_set(p,'{captura}',(p->'captura')||jsonb_build_object('puntaje_cerrado',coalesce(h.cerrado,false),'guardada',h.reunion IS NOT NULL,
 'cerrada',bloqueado OR coalesce(h.cerrado,false),
 'puede_reabrir',privado.es_directiva() AND NOT bloqueado AND coalesce(h.cerrado,false)));
 END IF;
 RETURN p;
END $function$;

CREATE OR REPLACE FUNCTION public.competencia_perfil(p_usuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE pub JSONB; ciclo UUID; c privado.competencia_cortes%ROWTYPE; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 pub:=public.competencia_publicacion();
 IF pub IS NOT NULL THEN RETURN pub||jsonb_build_object('puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,(pub->>'desde')::date,(pub->>'hasta')::date) WHERE id_usuario=p_usuario),0)); END IF;
 IF NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id() THEN RETURN NULL; END IF;
 SELECT * INTO c FROM privado.competencia_cortes WHERE id_ciclo=ciclo ORDER BY creado_en DESC,id LIMIT 1;
 IF c.id IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('nombre',c.nombre,'desde',c.desde,'hasta',c.hasta,'puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,c.desde,c.hasta) WHERE id_usuario=p_usuario),0));
END $function$;

CREATE OR REPLACE FUNCTION public.competencia_publicacion()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; anio INTEGER; f privado.competencia_finales%ROWTYPE; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 SELECT * INTO f FROM privado.competencia_finales WHERE id_ciclo=ciclo;
 IF FOUND THEN RETURN jsonb_build_object('nombre','Ciclo '||anio,'desde',f.desde,'hasta',f.hasta,'anual',true,'publicado_hasta',NULL); END IF;
 RETURN (SELECT jsonb_build_object('nombre',nombre,'desde',desde,'hasta',hasta,'anual',false,'publicado_hasta',publicado_hasta) FROM privado.competencia_cortes WHERE id_ciclo=ciclo AND publicado_hasta>now() ORDER BY creado_en DESC,id LIMIT 1);
END $function$;

CREATE OR REPLACE FUNCTION public.competencia_unidad(p_unidad uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE pub JSONB; ciclo UUID; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.unidades WHERE id_unidad=p_unidad;
 IF NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo) THEN RETURN NULL; END IF;
 pub:=public.competencia_publicacion();
 IF pub IS NULL THEN SELECT jsonb_build_object('nombre',nombre,'desde',desde,'hasta',hasta) INTO pub FROM privado.competencia_cortes WHERE id_ciclo=ciclo ORDER BY creado_en DESC,id LIMIT 1; END IF;
 IF pub IS NULL THEN RETURN NULL; END IF;
 RETURN pub||jsonb_build_object('puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,(pub->>'desde')::date,(pub->>'hasta')::date) WHERE id_unidad=p_unidad),0));
END $function$;

CREATE OR REPLACE FUNCTION public.cuotas_operar(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; previa privado.cuota_operaciones%ROWTYPE;
 u public.usuarios%ROWTYPE; cuenta privado.cuota_cuentas%ROWTYPE; v_ingreso privado.cuota_ingresos%ROWTYPE;
 periodos UUID[]; v_periodo UUID; v_fecha DATE; monto INTEGER; pendiente INTEGER; resultado JSONB; antiguo JSONB; cargo RECORD; clave TEXT;
 BEGIN
 PERFORM pg_advisory_xact_lock(728402);
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL OR actor.rol NOT IN ('directiva','capitan','subcapitan') THEN
 RAISE EXCEPTION 'No tienes permiso para registrar cuotas.' USING ERRCODE='42501'; END IF;
 IF p_operacion IS NULL OR p_accion IS NULL OR jsonb_typeof(p_datos) IS DISTINCT FROM 'object' THEN RAISE EXCEPTION 'Operación inválida.' USING ERRCODE='22023'; END IF;
 -- Una limpieza invalida las colas offline anteriores, incluso si coinciden sus versiones.
 IF EXISTS(SELECT 1 FROM privado.cuota_epoca e WHERE
   ((p_datos ? 'epoca') AND (p_datos->>'epoca') IS DISTINCT FROM e.token::text)
   OR (e.exigir AND NOT (p_datos ? 'epoca'))) THEN
 RAISE EXCEPTION 'Los datos se reiniciaron. Descarta este pendiente anterior y actualiza la lista.' USING ERRCODE='40001'; END IF;
 SELECT * INTO previa FROM privado.cuota_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF previa.auth_id<>auth.uid() OR previa.accion<>p_accion OR previa.datos<>p_datos THEN RAISE EXCEPTION 'Identificador de operación reutilizado.' USING ERRCODE='22023'; END IF;
 RETURN previa.resultado; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF (p_datos->>'id_ciclo')::uuid IS DISTINCT FROM ciclo THEN RAISE EXCEPTION 'El ciclo cambió. Revisa el registro pendiente.' USING ERRCODE='40001'; END IF;
 IF p_accion='cerrar' THEN
 v_periodo:=(p_datos->>'periodo')::uuid; clave:=p_datos->>'unidad';
 IF clave IS NULL OR NOT EXISTS(SELECT 1 FROM privado.cuota_periodos p WHERE p.id=v_periodo AND p.id_ciclo=ciclo AND NOT p.cancelado AND NOT p.legado) THEN
 RAISE EXCEPTION 'Cobro no disponible.' USING ERRCODE='22023'; END IF;
 IF actor.rol<>'directiva' AND (actor.id_ciclo<>ciclo OR actor.id_unidad IS NULL OR clave<>actor.id_unidad::text) THEN
 RAISE EXCEPTION 'Solo puedes cerrar tu unidad.' USING ERRCODE='42501'; END IF;
 IF NOT EXISTS(SELECT 1 FROM privado.cuota_cargos c WHERE c.periodo=v_periodo AND coalesce(c.id_unidad::text,'sin-unidad')=clave) THEN
 RAISE EXCEPTION 'Unidad sin cobros.' USING ERRCODE='22023'; END IF;
 FOR cargo IN SELECT c.*,q.version FROM privado.cuota_cargos c JOIN privado.cuota_cuentas q ON q.id_usuario=c.id_usuario AND q.id_ciclo=ciclo
 WHERE c.periodo=v_periodo AND coalesce(c.id_unidad::text,'sin-unidad')=clave LOOP
 IF (p_datos->'versiones'->>cargo.id_usuario::text)::bigint IS DISTINCT FROM cargo.version OR cargo.cerrado THEN
 RAISE EXCEPTION 'El cobro cambió. Actualiza y revisa antes de cerrar.' USING ERRCODE='40001'; END IF;
 PERFORM privado.cuota_aplicar(cargo.id_usuario,ciclo,ARRAY[v_periodo]);
 UPDATE privado.cuota_cargos SET cerrado=true WHERE periodo=v_periodo AND id_usuario=cargo.id_usuario;
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=cargo.id_usuario AND id_ciclo=ciclo;
 END LOOP;
 resultado:=jsonb_build_object('periodo',v_periodo,'unidad',clave,'cerrado',true);
 ELSIF p_accion='periodo' THEN
 RAISE EXCEPTION 'Crea el cobro en una reunión regular del Calendario.' USING ERRCODE='22023';
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
 IF EXISTS(SELECT 1 FROM unnest(periodos) x WHERE NOT EXISTS(SELECT 1 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=u.id_usuario AND p.id_ciclo=ciclo AND NOT p.cancelado AND c.periodo=x)) THEN
 RAISE EXCEPTION 'Cobro no asignado al integrante.' USING ERRCODE='22023'; END IF;
 IF actor.rol<>'directiva' AND EXISTS(SELECT 1 FROM privado.cuota_cargos c WHERE c.periodo=ANY(periodos) AND c.id_usuario=u.id_usuario AND (c.cerrado OR c.id_unidad IS DISTINCT FROM actor.id_unidad)) THEN
 RAISE EXCEPTION 'Cobro cerrado o fuera de tu unidad. Solicita revisión a directiva.' USING ERRCODE='40001'; END IF;
 IF p_accion='saldo' AND EXISTS(SELECT 1 FROM privado.cuota_cargos c WHERE c.periodo=ANY(periodos) AND c.id_usuario=u.id_usuario AND NOT c.cerrado) THEN
 RAISE EXCEPTION 'El saldo se aplica al cerrar el cobro de la unidad.' USING ERRCODE='22023'; END IF;
 IF p_accion='pago' THEN
 monto:=(p_datos->>'importe')::integer; v_fecha:=(p_datos->>'fecha')::date;
 IF monto IS NULL OR monto NOT BETWEEN 1 AND 10000000 OR v_fecha IS NULL OR v_fecha>(now() AT TIME ZONE 'America/Mexico_City')::date OR length(coalesce(p_datos->>'nota',''))>500 THEN
 RAISE EXCEPTION 'Revisa importe, fecha y nota.' USING ERRCODE='22023'; END IF;
 IF actor.rol<>'directiva' THEN
 IF cardinality(periodos)<>1 OR monto<>1000 THEN RAISE EXCEPTION 'Capitán y subcapitán registran una cuota completa de $10.' USING ERRCODE='42501'; END IF;
 SELECT c.importe-coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=u.id_usuario),0) INTO pendiente
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.periodo=periodos[1] AND c.id_usuario=u.id_usuario AND p.fecha=v_fecha AND NOT p.legado;
 IF pendiente IS DISTINCT FROM 1000 THEN RAISE EXCEPTION 'Esta cuota ya tiene un pago o no corresponde a la actividad indicada. Solicita revisión a directiva.' USING ERRCODE='40001'; END IF;
 END IF;
 INSERT INTO privado.cuota_ingresos(id,id_usuario,id_ciclo,importe,fecha,auth_id,nota)
 VALUES(p_operacion,u.id_usuario,ciclo,monto,v_fecha,auth.uid(),coalesce(p_datos->>'nota',''));
 PERFORM privado.cuota_aplicar(u.id_usuario,ciclo,ARRAY(SELECT p.id FROM privado.cuota_periodos p WHERE p.id=ANY(periodos) AND p.fecha<=v_fecha),p_operacion);
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
END $function$;

CREATE OR REPLACE FUNCTION public.cuotas_panel()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p JSONB; actor public.usuarios%ROWTYPE; fecha DATE; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 p:=privado.cuotas_panel_019();
 IF actor.rol='directiva' THEN RETURN p; END IF;
 p:=p||jsonb_build_object('ingresos','[]'::jsonb,'aplicaciones','[]'::jsonb,'bitacora','[]'::jsonb);
 IF actor.rol NOT IN ('capitan','subcapitan') THEN
 RETURN p||jsonb_build_object('integrantes','[]'::jsonb,'cargos','[]'::jsonb,'periodos','[]'::jsonb,'cumplimiento',CASE WHEN actor.rol='conquistador' THEN public.cuotas_resumen(actor.id_usuario)->'porcentaje' ELSE NULL END);
 END IF;
 -- Solo el día de cobro vigente de su unidad; sin importes de reuniones históricas.
 SELECT max((x->>'fecha')::date) INTO fecha FROM jsonb_array_elements(p->'periodos') x
 WHERE NOT (x->>'legado')::boolean AND (x->>'fecha')::date<=(now() AT TIME ZONE 'America/Mexico_City')::date
 AND EXISTS(SELECT 1 FROM jsonb_array_elements(p->'cargos') c WHERE c->>'periodo'=x->>'id' AND (c->>'id_unidad')::uuid IS NOT DISTINCT FROM actor.id_unidad);
 p:=jsonb_set(p,'{periodos}',coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(p->'periodos') x WHERE (x->>'fecha')::date=fecha AND NOT (x->>'legado')::boolean),'[]'::jsonb));
 p:=jsonb_set(p,'{cargos}',coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(p->'cargos') x WHERE (x->>'id_unidad')::uuid IS NOT DISTINCT FROM actor.id_unidad AND EXISTS(SELECT 1 FROM jsonb_array_elements(p->'periodos') pp WHERE pp->>'id'=x->>'periodo')),'[]'::jsonb));
 RETURN jsonb_set(p,'{integrantes}',coalesce((SELECT jsonb_agg(x-'saldo') FROM jsonb_array_elements(p->'integrantes') x WHERE EXISTS(SELECT 1 FROM jsonb_array_elements(p->'cargos') c WHERE c->>'id_usuario'=x->>'id_usuario')),'[]'::jsonb));
END $function$;

CREATE OR REPLACE FUNCTION public.cuotas_resumen(p_usuario uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p JSONB; BEGIN
 p:=privado.cuotas_resumen_019(p_usuario);
 RETURN CASE WHEN privado.es_directiva() THEN p ELSE jsonb_build_object('porcentaje',p->'porcentaje') END;
END $function$;

CREATE OR REPLACE FUNCTION public.directorio_integrantes()
 RETURNS TABLE(id_usuario uuid, nombres text, apellido text, url_foto text, unidad text, clase text, rol text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    u.url_foto::TEXT,
    un.nombre::TEXT,
    cl.nombre::TEXT,
    CASE
      WHEN (SELECT privado.es_directiva())
        OR u.id_usuario = (SELECT privado.mi_id())
      THEN u.rol::TEXT
      ELSE NULL::TEXT
    END
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE (SELECT privado.mi_id()) IS NOT NULL
    AND u.es_activo = TRUE
    AND (
      u.id_usuario = (SELECT privado.mi_id())
      OR EXISTS (
        SELECT 1
        FROM public.ciclos c
        WHERE c.id_ciclo = u.id_ciclo
          AND c.es_activo = TRUE
      )
    );
$function$;

CREATE OR REPLACE FUNCTION public.directorio_portal()
 RETURNS TABLE(id_usuario uuid, nombres text, apellido text, rol text, unidad text, clase text, url_foto text, foto_path text, es_activo boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    CASE
      WHEN privado.es_directiva()
        OR u.id_usuario = privado.mi_id()
      THEN u.rol::TEXT
    END,
    un.nombre::TEXT,
    cl.nombre::TEXT,
    u.url_foto::TEXT,
    u.foto_path,
    u.es_activo
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE privado.mi_id() IS NOT NULL
    AND (u.es_activo OR privado.es_directiva())
    AND (
      u.id_usuario = privado.mi_id()
      OR EXISTS (
        SELECT 1
        FROM public.ciclos c
        WHERE c.id_ciclo = u.id_ciclo
          AND c.es_activo
      )
    );
$function$;

CREATE OR REPLACE FUNCTION public.especialidades_visibles(p_id_usuario uuid)
 RETURNS TABLE(id_especialidad uuid, nombre text, url_imagen text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT
    e.id_especialidad,
    e.nombre::TEXT,
    e.url_imagen::TEXT
  FROM public.conquistador_especialidades ce
  JOIN public.especialidades e
    ON e.id_especialidad = ce.id_especialidad
  WHERE ce.id_usuario = p_id_usuario
    AND EXISTS (
      SELECT 1
      FROM public.directorio_portal() d
      WHERE d.id_usuario = p_id_usuario
    );
$function$;

CREATE OR REPLACE FUNCTION public.guardar_asistencias(p_fecha date, p_cambios jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION
    'Actualiza la página. El pase se guarda por reunión y unidad.'
    USING ERRCODE = '22023';
END;
$function$;

CREATE OR REPLACE FUNCTION public.historial_matriz()
 RETURNS TABLE(reunion uuid, fecha date, version bigint, id_usuario uuid, nombre text, unidad_clave text, unidad text, estado text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT r.id,r.fecha,r.version,c.id_usuario,
    (u.nombres||' '||u.apellido)::TEXT,
    coalesce(c.id_unidad::TEXT,'sin-unidad'),c.unidad,c.estado
  FROM privado.reuniones r
  JOIN privado.convocados c ON c.reunion=r.id
  JOIN public.usuarios u ON u.id_usuario=c.id_usuario
  WHERE r.estado='cerrada' AND privado.ver_convocado(r.id,c.id_usuario);
$function$;

CREATE OR REPLACE FUNCTION public.historial_matriz_turnos()
 RETURNS TABLE(reunion uuid, fecha date, version bigint, id_usuario uuid, nombre text, unidad_clave text, unidad text, estado text, nombre_pase text, numero integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT r.id,r.fecha,r.version,c.id_usuario,(u.nombres||' '||u.apellido)::TEXT,
 coalesce(c.id_unidad::TEXT,'sin-unidad'),c.unidad,c.estado,r.nombre,r.numero
 FROM privado.reuniones r JOIN privado.convocados_asistencia c ON c.reunion=r.id
 JOIN public.usuarios u ON u.id_usuario=c.id_usuario
 WHERE r.estado='cerrada' AND privado.ver_convocado(r.id,c.id_usuario);
$function$;

CREATE OR REPLACE FUNCTION public.integrantes_asistencias()
 RETURNS TABLE(id_usuario uuid, nombres text, apellido text, id_unidad uuid, unidad text, es_activo boolean, id_ciclo uuid, anio integer, ciclo_activo boolean, puede_marcar boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.mi_perfil()
 RETURNS TABLE(id_usuario uuid, nombres text, apellido text, rol text, unidad text, clase text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    u.rol::TEXT,
    un.nombre::TEXT,
    cl.nombre::TEXT
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE u.id_usuario = (SELECT privado.mi_id());
$function$;

CREATE OR REPLACE FUNCTION public.organizacion_guardar(p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE foto text:=nullif(btrim(p_datos->>'url_foto'),''); BEGIN
 IF p_accion IN ('unidad','identidad') AND p_datos ? 'url_foto' THEN
 IF foto IS NOT NULL AND (length(foto)>500 OR foto !~ '^img/unidades/[A-Za-z0-9_-]+\.(webp|png|jpg|jpeg)$') THEN
 RAISE EXCEPTION 'La foto debe ser una ruta img/unidades/archivo.webp, png o jpg.' USING ERRCODE='22023'; END IF;
 END IF;
 -- Conserva validación de rol/unidad, ciclo, versión, bitácora y campos de identidad.
 PERFORM public.organizacion_guardar_023(p_accion,p_datos);
 IF p_accion IN ('unidad','identidad') AND p_datos ? 'url_foto' THEN
 UPDATE public.unidades SET url_foto=foto,foto_path=NULL WHERE id_unidad=(p_datos->>'id')::uuid;
 END IF;
END $function$;

CREATE OR REPLACE FUNCTION public.organizacion_guardar_023(p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
END $function$;

CREATE OR REPLACE FUNCTION public.organizacion_panel(p_ciclo uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE ciclo UUID; actor public.usuarios%ROWTYPE; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 ciclo:=coalesce(p_ciclo,(SELECT id_ciclo FROM public.ciclos WHERE es_activo));
 IF NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND (es_activo OR actor.rol='directiva')) THEN RAISE EXCEPTION 'Ciclo no disponible.' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('id_ciclo',ciclo,'vigente',EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo),'rol',actor.rol,
 'ciclos',(SELECT jsonb_agg(to_jsonb(c) ORDER BY anio DESC) FROM public.ciclos c WHERE es_activo OR actor.rol='directiva'),
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u)||jsonb_build_object('editable',privado.editar_unidad(u.id_unidad),
 'asistencia',(SELECT jsonb_build_object('total',count(*),'asistencias',count(*) FILTER(WHERE a.estado='asistencia'),'justificados',count(*) FILTER(WHERE a.estado='justificado'),'faltas',count(*) FILTER(WHERE a.estado='falta'),'porcentaje',CASE WHEN count(*)>0 THEN round(100.0*count(*) FILTER(WHERE a.estado IN ('asistencia','justificado'))/count(*)) ELSE NULL END)
 FROM privado.convocados_asistencia a JOIN privado.reuniones r ON r.id=a.reunion
 WHERE a.id_unidad=u.id_unidad AND r.id_ciclo=ciclo AND r.tipo='regular' AND r.estado='cerrada' AND NOT r.eliminado)) ORDER BY nombre) FROM public.unidades u WHERE id_ciclo=ciclo),'[]'::jsonb),
 'clases',coalesce((SELECT jsonb_agg(to_jsonb(c)||jsonb_build_object('nombre',CASE WHEN EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo) THEN c.nombre ELSE coalesce((SELECT i.nombre_clase FROM privado.inscripciones i WHERE i.id_ciclo=ciclo AND i.id_clase=c.id_clase LIMIT 1),c.nombre) END) ORDER BY nombre) FROM public.clases c),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',i.id_usuario,'nombre',u.nombres||' '||u.apellido,'id_unidad',i.id_unidad,'id_clase',i.id_clase,'rol',i.rol,'activo',i.activo,'version',u.version_perfil,'unidad',i.nombre_unidad,'clase',i.nombre_clase) ORDER BY u.apellido,u.nombres)
 FROM privado.inscripciones i JOIN public.usuarios u USING(id_usuario) WHERE i.id_ciclo=ciclo AND (i.activo OR actor.rol='directiva')),'[]'::jsonb));
END $function$;

CREATE OR REPLACE FUNCTION public.presentacion_integrantes()
 RETURNS TABLE(id_usuario uuid, es_directiva boolean, cobra_cuotas boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT u.id_usuario,u.rol='directiva',u.rol IN ('conquistador','capitan','subcapitan')
  FROM public.directorio_portal() d
  JOIN public.usuarios u ON u.id_usuario=d.id_usuario;
$function$;

CREATE OR REPLACE FUNCTION public.reunion_accion(p_id uuid, p_version bigint, p_accion text, p_datos jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  r privado.reuniones%ROWTYPE;
  actor public.usuarios%ROWTYPE;
  c privado.convocados%ROWTYPE;
  v_clave TEXT;
  cambios JSONB;
  v_motivo TEXT;
BEGIN
  PERFORM pg_advisory_xact_lock(728401);
  PERFORM pg_advisory_xact_lock(728402);

  SELECT * INTO actor
  FROM public.usuarios
  WHERE id_usuario = privado.mi_id()
  FOR SHARE;

  SELECT * INTO r
  FROM privado.reuniones
  WHERE id = p_id
  FOR UPDATE;

  IF actor.id_usuario IS NULL
     OR r.id IS NULL OR r.eliminado
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

  IF r.tipo<>'regular' AND p_accion NOT IN ('anular','restaurar') THEN
    RAISE EXCEPTION 'Esta actividad es solo un aviso, sin pase de asistencia.' USING ERRCODE='22023';
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
      OR EXISTS (
        SELECT 1
        FROM privado.unidades_revisadas
        WHERE reunion = p_id AND NOT revisada
          AND EXISTS(SELECT 1 FROM privado.convocados_asistencia elegible
            WHERE elegible.reunion=p_id AND coalesce(elegible.id_unidad::TEXT,'sin-unidad')=unidades_revisadas.clave)
      )
    THEN
      RAISE EXCEPTION
        'Revisa y guarda todas las unidades antes de cerrar el pase.'
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
    PERFORM privado.calendario_liberar_cobro(r.periodo_cuota);

  ELSIF p_accion = 'restaurar' AND r.estado = 'anulada' THEN
    UPDATE privado.reuniones
    SET estado = 'borrador'
    WHERE id = p_id;

    IF r.periodo_cuota IS NOT NULL THEN PERFORM privado.actividad_cobro(r.id); END IF;
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
$function$;

CREATE OR REPLACE FUNCTION public.reunion_crear(p_fecha date)
 RETURNS uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$ SELECT public.reunion_crear_turno(p_fecha,'General'); $function$;

CREATE OR REPLACE FUNCTION public.reunion_crear_turno(p_fecha date, p_nombre text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.reunion_integrada_guardar(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE u public.usuarios%ROWTYPE; r privado.reuniones%ROWTYPE; a privado.competencia_operaciones%ROWTYPE; x jsonb; BEGIN
IF p_accion NOT IN ('capitan_cobrar','capitan_justificar') THEN PERFORM public.reunion_integrada_guardar_022(p_operacion,p_accion,p_datos);RETURN;END IF;
PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);PERFORM pg_advisory_xact_lock(728404);
SELECT * INTO u FROM public.usuarios WHERE id_usuario=privado.mi_id();
SELECT * INTO r FROM privado.reuniones WHERE id=(p_datos->>'reunion')::uuid;
IF u.rol IS DISTINCT FROM 'capitan' OR u.id_unidad IS NULL OR r.id IS NULL OR r.id_ciclo<>u.id_ciclo OR r.eliminado OR r.estado='anulada' THEN RAISE EXCEPTION 'Sin permiso para esta reunión.' USING ERRCODE='42501';END IF;
SELECT * INTO a FROM privado.competencia_operaciones WHERE id=p_operacion;
IF FOUND THEN IF a.auth_id IS DISTINCT FROM auth.uid() OR a.accion<>p_accion OR a.datos<>p_datos THEN RAISE EXCEPTION 'Operación reutilizada.' USING ERRCODE='22023';END IF;RETURN;END IF;
IF p_accion='capitan_justificar' THEN
PERFORM public.reunion_accion(r.id,(p_datos->>'version_reunion')::bigint,'justificar',p_datos);
ELSE
IF EXISTS(SELECT 1 FROM privado.competencia_hojas WHERE reunion=r.id AND cerrado) THEN RAISE EXCEPTION 'Reunión cerrada.' USING ERRCODE='22023';END IF;
FOR x IN SELECT value FROM jsonb_array_elements(p_datos->'pagos') LOOP
IF (x->>'importe')::int IS DISTINCT FROM 1000 OR NOT EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND c.id_usuario=(x->>'id_usuario')::uuid AND c.id_unidad=u.id_unidad) THEN RAISE EXCEPTION 'Cobro inválido.' USING ERRCODE='42501';END IF;
PERFORM public.cuotas_operar(gen_random_uuid(),'pago',x||jsonb_build_object('id_ciclo',r.id_ciclo,'epoca',p_datos->'epoca','periodos',jsonb_build_array(r.periodo_cuota),'fecha',(now() AT TIME ZONE 'America/Mexico_City')::date));
END LOOP;END IF;
INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $function$;

CREATE OR REPLACE FUNCTION public.reunion_integrada_guardar_022(p_operacion uuid, p_accion text, p_datos jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
#variable_conflict use_column
DECLARE anterior privado.competencia_operaciones%ROWTYPE; r privado.reuniones%ROWTYPE; p JSONB; x JSONB; cargo RECORD; datos JSONB; integrantes JSONB; extras JSONB; clave TEXT; BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);PERFORM pg_advisory_xact_lock(728404);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva captura reuniones.' USING ERRCODE='42501'; END IF;
 IF p_accion NOT IN ('unidad_integrada','cerrar_integrada') THEN PERFORM public.competencia_guardar(p_operacion,p_accion,p_datos);RETURN; END IF;
 IF p_operacion IS NULL OR (p_datos->>'epoca')::uuid IS DISTINCT FROM (SELECT token FROM privado.cuota_epoca) THEN RAISE EXCEPTION 'Datos reiniciados. Actualiza.' USING ERRCODE='40001'; END IF;
 SELECT * INTO anterior FROM privado.competencia_operaciones WHERE id=p_operacion;
 IF FOUND THEN
 IF anterior.auth_id IS DISTINCT FROM auth.uid() OR anterior.accion IS DISTINCT FROM p_accion OR anterior.datos IS DISTINCT FROM p_datos THEN RAISE EXCEPTION 'Operación reutilizada.' USING ERRCODE='22023'; END IF;RETURN; END IF;
 SELECT * INTO r FROM privado.reuniones WHERE id=(p_datos->>'reunion')::uuid AND id_ciclo=(p_datos->>'id_ciclo')::uuid AND id_ciclo=(SELECT id_ciclo FROM public.ciclos WHERE es_activo);
 IF r.id IS NULL OR r.eliminado OR r.estado='anulada' THEN RAISE EXCEPTION 'Reunión no disponible.' USING ERRCODE='22023'; END IF;
 p:=public.competencia_panel(r.id,NULL,NULL);
 IF (p->'captura'->>'cerrada')::boolean THEN RAISE EXCEPTION 'Reabre el puntaje antes de modificar la reunión.' USING ERRCODE='22023'; END IF;
 IF r.version IS DISTINCT FROM (p_datos->>'version_reunion')::bigint OR (p->'captura'->>'version')::bigint IS DISTINCT FROM (p_datos->>'version')::bigint THEN RAISE EXCEPTION 'La reunión cambió. Revisa el intento.' USING ERRCODE='40001'; END IF;
 IF p_accion='unidad_integrada' THEN
 clave:=p_datos->>'unidad';
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_datos->'integrantes') x WHERE jsonb_typeof(x->'cumplidos') IS DISTINCT FROM 'array' OR NOT EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND c.id_usuario=(x->>'id_usuario')::uuid AND coalesce(c.id_unidad::text,'sin-unidad')=clave)) THEN RAISE EXCEPTION 'Puntajes fuera de la unidad.' USING ERRCODE='22023';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_datos->'extras','[]')) e WHERE NOT (
 (e->>'id_usuario' IS NOT NULL AND EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND c.id_usuario=(e->>'id_usuario')::uuid AND coalesce(c.id_unidad::text,'sin-unidad')=clave)) OR
 (e->>'id_usuario' IS NULL AND e->>'id_unidad'=clave))) THEN RAISE EXCEPTION 'Extra fuera de la unidad.' USING ERRCODE='42501'; END IF;
 IF jsonb_array_length(p_datos->'integrantes')<>(SELECT count(*) FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND coalesce(c.id_unidad::text,'sin-unidad')=clave) OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_datos->'integrantes') a GROUP BY a->>'id_usuario' HAVING count(*)>1) THEN RAISE EXCEPTION 'Revisa los puntos de la unidad.' USING ERRCODE='22023'; END IF;
 PERFORM public.reunion_accion(r.id,r.version,'unidad',jsonb_build_object('clave',clave,'integrantes',p_datos->'asistencias'));
 FOR x IN SELECT value FROM jsonb_array_elements(coalesce(p_datos->'pagos','[]')) LOOP
 IF NOT EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND c.id_usuario=(x->>'id_usuario')::uuid AND coalesce(c.id_unidad::text,'sin-unidad')=clave) THEN RAISE EXCEPTION 'Pago fuera de la unidad.' USING ERRCODE='42501'; END IF;
 PERFORM public.cuotas_operar(gen_random_uuid(),'pago',x||jsonb_build_object('id_ciclo',r.id_ciclo,'epoca',p_datos->'epoca','periodos',jsonb_build_array(r.periodo_cuota),'fecha',(now() AT TIME ZONE 'America/Mexico_City')::date));
 END LOOP;
 SELECT jsonb_agg(jsonb_build_object('id_usuario',u->'id_usuario','cumplidos',CASE WHEN coalesce(u->>'id_unidad','sin-unidad')=clave THEN (SELECT a->'cumplidos' FROM jsonb_array_elements(p_datos->'integrantes') a WHERE a->>'id_usuario'=u->>'id_usuario') ELSE u->'cumplidos' END)) INTO integrantes FROM jsonb_array_elements(p->'captura'->'integrantes') u;
 SELECT coalesce(jsonb_agg(e),'[]') INTO extras FROM jsonb_array_elements(p->'captura'->'extras') e WHERE coalesce(e->>'id_unidad','sin-unidad')<>clave;
 datos:=p_datos||jsonb_build_object('integrantes',integrantes,'extras',extras||coalesce(p_datos->'extras','[]'),'version_reunion',(SELECT version FROM privado.reuniones WHERE id=r.id));
 PERFORM public.competencia_guardar(gen_random_uuid(),'captura',datos);
 UPDATE privado.competencia_hojas SET unidades_guardadas=array_append(array_remove(unidades_guardadas,clave),clave) WHERE reunion=r.id;
 ELSE
 IF EXISTS(SELECT 1 FROM privado.unidades_revisadas g WHERE g.reunion=r.id AND NOT g.clave=ANY(coalesce((SELECT unidades_guardadas FROM privado.competencia_hojas WHERE reunion=r.id),'{}'::text[]))) THEN RAISE EXCEPTION 'Guarda todas las unidades antes de cerrar la reunión.' USING ERRCODE='22023'; END IF;
 IF r.estado<>'cerrada' THEN PERFORM public.reunion_accion(r.id,r.version,'cerrar','{}'); END IF;
 FOR cargo IN SELECT coalesce(c.id_unidad::text,'sin-unidad') clave,jsonb_object_agg(c.id_usuario,q.version) versiones FROM privado.cuota_cargos c JOIN privado.cuota_cuentas q ON q.id_usuario=c.id_usuario AND q.id_ciclo=r.id_ciclo WHERE c.periodo=r.periodo_cuota AND NOT c.cerrado GROUP BY c.id_unidad LOOP
 PERFORM public.cuotas_operar(gen_random_uuid(),'cerrar',jsonb_build_object('id_ciclo',r.id_ciclo,'epoca',p_datos->'epoca','periodo',r.periodo_cuota,'unidad',cargo.clave,'versiones',cargo.versiones));
 END LOOP;
 PERFORM public.competencia_guardar(gen_random_uuid(),'cerrar_puntajes',p_datos||jsonb_build_object('version_reunion',(SELECT version FROM privado.reuniones WHERE id=r.id)));
 END IF;
 INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $function$;

CREATE OR REPLACE FUNCTION public.reunion_integrada_panel(p_reunion uuid DEFAULT NULL::uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p jsonb; f jsonb; u public.usuarios%ROWTYPE; r privado.reuniones%ROWTYPE; BEGIN
p:=public.reunion_integrada_panel_022(p_reunion,p_desde,p_hasta);
SELECT * INTO u FROM public.usuarios WHERE id_usuario=privado.mi_id();
SELECT * INTO r FROM privado.reuniones WHERE id=p_reunion;
IF u.rol='capitan' AND u.id_unidad IS NOT NULL AND r.id_ciclo=u.id_ciclo AND NOT r.eliminado AND r.estado<>'anulada' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p->'captura'->'integrantes') x WHERE x->>'id_unidad'=u.id_unidad::text) THEN
p:=jsonb_set(p,'{captura,version_reunion}',to_jsonb(r.version));
f:=public.cuotas_panel();
p:=p||jsonb_build_object('capitan_captura',r.fecha=(now() AT TIME ZONE 'America/Mexico_City')::date AND NOT coalesce((p->'captura'->>'puntaje_cerrado')::boolean,false),'capitan_justifica',r.fecha=(now() AT TIME ZONE 'America/Mexico_City')::date,'periodo_cuota',r.periodo_cuota,'epoca',(SELECT token FROM privado.cuota_epoca),'finanzas',jsonb_build_object('periodos',coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(f->'periodos') x WHERE x->>'id'=r.periodo_cuota::text),'[]'),'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',x->'id_usuario','periodo',x->'periodo','pagado',x->'pagado')) FROM jsonb_array_elements(f->'cargos') x WHERE x->>'periodo'=r.periodo_cuota::text),'[]'),'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',x->'id_usuario','version',x->'version')) FROM jsonb_array_elements(f->'integrantes') x),'[]')));
END IF;RETURN p;END $function$;

CREATE OR REPLACE FUNCTION public.reunion_integrada_panel_022(p_reunion uuid DEFAULT NULL::uuid, p_desde date DEFAULT NULL::date, p_hasta date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE p JSONB; BEGIN
 p:=public.competencia_panel(p_reunion,p_desde,p_hasta)||jsonb_build_object('api_version',22);
 IF p_reunion IS NOT NULL THEN p:=jsonb_set(p,'{captura,unidades_guardadas}',to_jsonb(coalesce((SELECT unidades_guardadas FROM privado.competencia_hojas WHERE reunion=p_reunion),'{}'::text[])));END IF;
 IF p_reunion IS NOT NULL AND privado.es_directiva() THEN
 p:=p||jsonb_build_object('periodo_cuota',(SELECT periodo_cuota FROM privado.reuniones WHERE id=p_reunion),'pase',public.reunion_panel(p_reunion),'finanzas',public.cuotas_panel(),'epoca',(SELECT token FROM privado.cuota_epoca));
 END IF;
 RETURN p;
END $function$;

CREATE OR REPLACE FUNCTION public.reunion_panel(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    OR r.id IS NULL OR r.eliminado OR r.tipo<>'regular'
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
$function$;

CREATE OR REPLACE FUNCTION public.reuniones_listar()
 RETURNS TABLE(id uuid, fecha date, estado text, importada boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT r.id,r.fecha,r.estado,r.importada FROM privado.reuniones r
 WHERE NOT r.eliminado AND r.tipo='regular' AND (privado.es_directiva()
 OR (r.estado<>'anulada' AND EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND privado.ver_convocado(r.id,c.id_usuario))));
$function$;

CREATE OR REPLACE FUNCTION public.reuniones_listar_turnos()
 RETURNS TABLE(id uuid, fecha date, estado text, importada boolean, nombre text, numero integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 SELECT r.id,r.fecha,r.estado,r.importada,r.nombre,r.numero
 FROM privado.reuniones r JOIN public.reuniones_listar() visible ON visible.id=r.id;
$function$;

-- Defaults y restricciones. Las FK se agregan después de crear todas las tablas.

ALTER TABLE "privado"."asistencia_operaciones" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."bitacora_reuniones" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."bitacora_reuniones" ALTER COLUMN "fecha" SET DEFAULT now();

ALTER TABLE "privado"."competencia_config" ALTER COLUMN "id" SET DEFAULT true;

ALTER TABLE "privado"."competencia_config" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "privado"."competencia_config" ALTER COLUMN "justificados" SET DEFAULT true;

ALTER TABLE "privado"."competencia_cortes" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."competencia_cortes" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."competencia_criterios" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."competencia_criterios" ALTER COLUMN "fuente" SET DEFAULT 'manual'::text;

ALTER TABLE "privado"."competencia_criterios" ALTER COLUMN "valor" SET DEFAULT 5;

ALTER TABLE "privado"."competencia_criterios" ALTER COLUMN "activo" SET DEFAULT true;

ALTER TABLE "privado"."competencia_criterios" ALTER COLUMN "solo_conquistadores" SET DEFAULT false;

ALTER TABLE "privado"."competencia_extras" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."competencia_finales" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."competencia_hojas" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "privado"."competencia_hojas" ALTER COLUMN "cerrado" SET DEFAULT false;

ALTER TABLE "privado"."competencia_hojas" ALTER COLUMN "unidades_guardadas" SET DEFAULT '{}'::text[];

ALTER TABLE "privado"."competencia_marcas" ALTER COLUMN "cumplidos" SET DEFAULT '{}'::uuid[];

ALTER TABLE "privado"."competencia_operaciones" ALTER COLUMN "fecha" SET DEFAULT now();

ALTER TABLE "privado"."competencia_periodos" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."competencia_periodos" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."competencia_reaperturas" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."competencia_reaperturas" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."convocados" ALTER COLUMN "estado" SET DEFAULT 'falta'::text;

ALTER TABLE "privado"."convocados" ALTER COLUMN "exento_asistencia" SET DEFAULT false;

ALTER TABLE "privado"."cuentas_miembros" ALTER COLUMN "vinculado_en" SET DEFAULT now();

ALTER TABLE "privado"."cuota_cargos" ALTER COLUMN "cerrado" SET DEFAULT false;

ALTER TABLE "privado"."cuota_cuentas" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "privado"."cuota_epoca" ALTER COLUMN "unica" SET DEFAULT true;

ALTER TABLE "privado"."cuota_epoca" ALTER COLUMN "token" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."cuota_epoca" ALTER COLUMN "exigir" SET DEFAULT false;

ALTER TABLE "privado"."cuota_ingresos" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."cuota_ingresos" ALTER COLUMN "anulado" SET DEFAULT false;

ALTER TABLE "privado"."cuota_ingresos" ALTER COLUMN "nota" SET DEFAULT ''::text;

ALTER TABLE "privado"."cuota_ingresos" ALTER COLUMN "legado" SET DEFAULT false;

ALTER TABLE "privado"."cuota_operaciones" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "importe" SET DEFAULT 1000;

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "legado" SET DEFAULT false;

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "cancelado" SET DEFAULT false;

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "gestionado_calendario" SET DEFAULT false;

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "nombre" SET DEFAULT 'Cobro anterior'::text;

ALTER TABLE "privado"."cuota_periodos" ALTER COLUMN "hora" SET DEFAULT '09:00:00'::time without time zone;

ALTER TABLE "privado"."historial_asistencias" ALTER COLUMN "id_evento" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."historial_asistencias" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."historial_calendario" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."historial_calendario" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."historial_organizacion" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."historial_organizacion" ALTER COLUMN "fecha" SET DEFAULT now();

ALTER TABLE "privado"."historial_perfiles" ALTER COLUMN "id_evento" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."historial_perfiles" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."historial_vinculaciones" ALTER COLUMN "id_evento" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."historial_vinculaciones" ALTER COLUMN "creado_en" SET DEFAULT now();

ALTER TABLE "privado"."migraciones" ALTER COLUMN "aplicada_en" SET DEFAULT now();

ALTER TABLE "privado"."reuniones" ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

ALTER TABLE "privado"."reuniones" ALTER COLUMN "estado" SET DEFAULT 'borrador'::text;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "importada" SET DEFAULT false;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "nombre" SET DEFAULT 'General'::text;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "numero" SET DEFAULT 1;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "hora" SET DEFAULT '09:00:00'::time without time zone;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "tipo" SET DEFAULT 'regular'::text;

ALTER TABLE "privado"."reuniones" ALTER COLUMN "eliminado" SET DEFAULT false;

ALTER TABLE "privado"."unidades_revisadas" ALTER COLUMN "revisada" SET DEFAULT false;

ALTER TABLE "public"."asistencias" ALTER COLUMN "id_asistencia" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."asistencias" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "public"."ciclos" ALTER COLUMN "id_ciclo" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."ciclos" ALTER COLUMN "es_activo" SET DEFAULT false;

ALTER TABLE "public"."clases" ALTER COLUMN "id_clase" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."clases" ALTER COLUMN "es_activa" SET DEFAULT true;

ALTER TABLE "public"."clases" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "public"."conquistador_especialidades" ALTER COLUMN "fecha_obtencion" SET DEFAULT CURRENT_DATE;

ALTER TABLE "public"."cuotas" ALTER COLUMN "id_cuota" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."cuotas" ALTER COLUMN "monto_pagado" SET DEFAULT 0;

ALTER TABLE "public"."especialidades" ALTER COLUMN "id_especialidad" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."unidades" ALTER COLUMN "id_unidad" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."unidades" ALTER COLUMN "es_activa" SET DEFAULT true;

ALTER TABLE "public"."unidades" ALTER COLUMN "version" SET DEFAULT 1;

ALTER TABLE "public"."usuarios" ALTER COLUMN "id_usuario" SET DEFAULT gen_random_uuid();

ALTER TABLE "public"."usuarios" ALTER COLUMN "es_activo" SET DEFAULT true;

ALTER TABLE "public"."usuarios" ALTER COLUMN "version_perfil" SET DEFAULT 1;

ALTER TABLE "privado"."asistencia_operaciones" ADD CONSTRAINT "asistencia_operaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."bitacora_reuniones" ADD CONSTRAINT "bitacora_reuniones_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_config" ADD CONSTRAINT "competencia_config_id_check" CHECK (id);

ALTER TABLE "privado"."competencia_config" ADD CONSTRAINT "competencia_config_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_cortes" ADD CONSTRAINT "competencia_cortes_check" CHECK (hasta >= desde);

ALTER TABLE "privado"."competencia_cortes" ADD CONSTRAINT "competencia_cortes_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_criterios" ADD CONSTRAINT "competencia_criterios_fuente_check" CHECK (fuente = ANY (ARRAY['manual'::text, 'asistencia'::text, 'cuota'::text]));

ALTER TABLE "privado"."competencia_criterios" ADD CONSTRAINT "competencia_criterios_nombre_check" CHECK (length(btrim(nombre)) >= 1 AND length(btrim(nombre)) <= 60);

ALTER TABLE "privado"."competencia_criterios" ADD CONSTRAINT "competencia_criterios_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_criterios" ADD CONSTRAINT "competencia_criterios_valor_check" CHECK (valor >= 0 AND valor <= 10000);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_check" CHECK (id_usuario IS NOT NULL OR id_unidad IS NOT NULL);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_motivo_check" CHECK (length(btrim(motivo)) >= 1 AND length(btrim(motivo)) <= 300);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_puntos_check" CHECK (puntos >= 1 AND puntos <= 10000);

ALTER TABLE "privado"."competencia_finales" ADD CONSTRAINT "competencia_finales_pkey" PRIMARY KEY (id_ciclo);

ALTER TABLE "privado"."competencia_hojas" ADD CONSTRAINT "competencia_hojas_pkey" PRIMARY KEY (reunion);

ALTER TABLE "privado"."competencia_marcas" ADD CONSTRAINT "competencia_marcas_pkey" PRIMARY KEY (reunion, id_usuario);

ALTER TABLE "privado"."competencia_operaciones" ADD CONSTRAINT "competencia_operaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_check" CHECK (hasta >= desde);

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_corte_key" UNIQUE (corte);

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_nombre_check" CHECK (length(btrim(nombre)) >= 1 AND length(btrim(nombre)) <= 100);

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."competencia_reaperturas" ADD CONSTRAINT "competencia_reaperturas_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."convocados" ADD CONSTRAINT "convocados_estado_check" CHECK (estado = ANY (ARRAY['asistencia'::text, 'falta'::text, 'justificado'::text]));

ALTER TABLE "privado"."convocados" ADD CONSTRAINT "convocados_pkey" PRIMARY KEY (reunion, id_usuario);

ALTER TABLE "privado"."cuentas_miembros" ADD CONSTRAINT "cuentas_miembros_auth_id_key" UNIQUE (auth_id);

ALTER TABLE "privado"."cuentas_miembros" ADD CONSTRAINT "cuentas_miembros_pkey" PRIMARY KEY (id_usuario);

ALTER TABLE "privado"."cuota_aplicaciones" ADD CONSTRAINT "cuota_aplicaciones_importe_check" CHECK (importe > 0);

ALTER TABLE "privado"."cuota_aplicaciones" ADD CONSTRAINT "cuota_aplicaciones_pkey" PRIMARY KEY (ingreso, periodo);

ALTER TABLE "privado"."cuota_cargos" ADD CONSTRAINT "cuota_cargos_importe_check" CHECK (importe > 0);

ALTER TABLE "privado"."cuota_cargos" ADD CONSTRAINT "cuota_cargos_pkey" PRIMARY KEY (periodo, id_usuario);

ALTER TABLE "privado"."cuota_cuentas" ADD CONSTRAINT "cuota_cuentas_pkey" PRIMARY KEY (id_usuario, id_ciclo);

ALTER TABLE "privado"."cuota_epoca" ADD CONSTRAINT "cuota_epoca_pkey" PRIMARY KEY (unica);

ALTER TABLE "privado"."cuota_epoca" ADD CONSTRAINT "cuota_epoca_unica_check" CHECK (unica);

ALTER TABLE "privado"."cuota_ingresos" ADD CONSTRAINT "cuota_ingresos_importe_check" CHECK (importe > 0);

ALTER TABLE "privado"."cuota_ingresos" ADD CONSTRAINT "cuota_ingresos_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."cuota_operaciones" ADD CONSTRAINT "cuota_operaciones_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."cuota_periodos" ADD CONSTRAINT "cuota_periodos_actividad_key" UNIQUE (actividad);

ALTER TABLE "privado"."cuota_periodos" ADD CONSTRAINT "cuota_periodos_importe_check" CHECK (importe = 1000);

ALTER TABLE "privado"."cuota_periodos" ADD CONSTRAINT "cuota_periodos_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."historial_asistencias" ADD CONSTRAINT "historial_asistencias_pkey" PRIMARY KEY (id_evento);

ALTER TABLE "privado"."historial_calendario" ADD CONSTRAINT "historial_calendario_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."historial_organizacion" ADD CONSTRAINT "historial_organizacion_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."historial_perfiles" ADD CONSTRAINT "historial_perfiles_accion_check" CHECK (accion = ANY (ARRAY['crear'::text, 'editar'::text, 'activar'::text, 'desactivar'::text]));

ALTER TABLE "privado"."historial_perfiles" ADD CONSTRAINT "historial_perfiles_pkey" PRIMARY KEY (id_evento);

ALTER TABLE "privado"."historial_vinculaciones" ADD CONSTRAINT "historial_vinculaciones_accion_check" CHECK (accion = 'vincular'::text);

ALTER TABLE "privado"."historial_vinculaciones" ADD CONSTRAINT "historial_vinculaciones_pkey" PRIMARY KEY (id_evento);

ALTER TABLE "privado"."inscripciones" ADD CONSTRAINT "inscripciones_pkey" PRIMARY KEY (id_usuario, id_ciclo);

ALTER TABLE "privado"."migraciones" ADD CONSTRAINT "migraciones_pkey" PRIMARY KEY (version);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "actividad_formato" CHECK (fecha_fin >= fecha AND (tipo = 'evento'::text OR fecha_fin = fecha) AND (tipo = 'regular'::text OR periodo_cuota IS NULL) AND
CASE
    WHEN tipo = 'parcial'::text THEN num_nonnulls(destinatario_unidad, destinatario_clase) = 1
    ELSE num_nonnulls(destinatario_unidad, destinatario_clase) = 0
END);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_estado_check" CHECK (estado = ANY (ARRAY['borrador'::text, 'cerrada'::text, 'anulada'::text]));

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_pkey" PRIMARY KEY (id);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_tipo_check" CHECK (tipo = ANY (ARRAY['regular'::text, 'practica'::text, 'parcial'::text, 'evento'::text]));

ALTER TABLE "privado"."unidades_revisadas" ADD CONSTRAINT "unidades_revisadas_pkey" PRIMARY KEY (reunion, clave);

ALTER TABLE "privado"."usuarios_contacto" ADD CONSTRAINT "usuarios_contacto_pkey" PRIMARY KEY (id_usuario);

ALTER TABLE "privado"."usuarios_salud" ADD CONSTRAINT "usuarios_salud_pkey" PRIMARY KEY (id_usuario);

ALTER TABLE "public"."asistencias" ADD CONSTRAINT "asistencias_estado_check" CHECK (estado::text = ANY (ARRAY['asistencia'::character varying, 'falta'::character varying, 'justificado'::character varying]::text[]));

ALTER TABLE "public"."asistencias" ADD CONSTRAINT "asistencias_pkey" PRIMARY KEY (id_asistencia);

ALTER TABLE "public"."ciclos" ADD CONSTRAINT "ciclos_anio_key" UNIQUE (anio);

ALTER TABLE "public"."ciclos" ADD CONSTRAINT "ciclos_pkey" PRIMARY KEY (id_ciclo);

ALTER TABLE "public"."clases" ADD CONSTRAINT "clase_color_hex" CHECK (color_distintivo::text ~ '^#[0-9A-Fa-f]{6}$'::text AND color_distintivo IS NOT NULL);

ALTER TABLE "public"."clases" ADD CONSTRAINT "clases_pkey" PRIMARY KEY (id_clase);

ALTER TABLE "public"."conquistador_especialidades" ADD CONSTRAINT "conquistador_especialidades_pkey" PRIMARY KEY (id_usuario, id_especialidad);

ALTER TABLE "public"."cuotas" ADD CONSTRAINT "cuotas_id_usuario_fecha_semana_key" UNIQUE (id_usuario, fecha_semana);

ALTER TABLE "public"."cuotas" ADD CONSTRAINT "cuotas_monto_pagado_check" CHECK (monto_pagado >= 0);

ALTER TABLE "public"."cuotas" ADD CONSTRAINT "cuotas_pkey" PRIMARY KEY (id_cuota);

ALTER TABLE "public"."especialidades" ADD CONSTRAINT "especialidades_nombre_key" UNIQUE (nombre);

ALTER TABLE "public"."especialidades" ADD CONSTRAINT "especialidades_pkey" PRIMARY KEY (id_especialidad);

ALTER TABLE "public"."unidades" ADD CONSTRAINT "unidades_pkey" PRIMARY KEY (id_unidad);

ALTER TABLE "public"."usuarios" ADD CONSTRAINT "usuarios_pkey" PRIMARY KEY (id_usuario);

ALTER TABLE "public"."usuarios" ADD CONSTRAINT "usuarios_rol_check" CHECK (rol::text = ANY (ARRAY['directiva'::character varying, 'consejero'::character varying, 'capitan'::character varying, 'conquistador'::character varying]::text[]));

ALTER TABLE "privado"."bitacora_reuniones" ADD CONSTRAINT "bitacora_reuniones_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.reuniones(id);

ALTER TABLE "privado"."competencia_cortes" ADD CONSTRAINT "competencia_cortes_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_id_unidad_fkey" FOREIGN KEY (id_unidad) REFERENCES unidades(id_unidad);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."competencia_extras" ADD CONSTRAINT "competencia_extras_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.competencia_hojas(reunion);

ALTER TABLE "privado"."competencia_finales" ADD CONSTRAINT "competencia_finales_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."competencia_hojas" ADD CONSTRAINT "competencia_hojas_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."competencia_hojas" ADD CONSTRAINT "competencia_hojas_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.reuniones(id);

ALTER TABLE "privado"."competencia_marcas" ADD CONSTRAINT "competencia_marcas_id_unidad_fkey" FOREIGN KEY (id_unidad) REFERENCES unidades(id_unidad);

ALTER TABLE "privado"."competencia_marcas" ADD CONSTRAINT "competencia_marcas_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."competencia_marcas" ADD CONSTRAINT "competencia_marcas_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.competencia_hojas(reunion);

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_corte_fkey" FOREIGN KEY (corte) REFERENCES privado.competencia_cortes(id) ON DELETE CASCADE;

ALTER TABLE "privado"."competencia_periodos" ADD CONSTRAINT "competencia_periodos_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."competencia_reaperturas" ADD CONSTRAINT "competencia_reaperturas_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."convocados" ADD CONSTRAINT "convocados_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."convocados" ADD CONSTRAINT "convocados_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.reuniones(id);

ALTER TABLE "privado"."cuentas_miembros" ADD CONSTRAINT "cuentas_miembros_auth_id_fkey" FOREIGN KEY (auth_id) REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE "privado"."cuentas_miembros" ADD CONSTRAINT "cuentas_miembros_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT;

ALTER TABLE "privado"."cuota_aplicaciones" ADD CONSTRAINT "cuota_aplicaciones_ingreso_fkey" FOREIGN KEY (ingreso) REFERENCES privado.cuota_ingresos(id);

ALTER TABLE "privado"."cuota_aplicaciones" ADD CONSTRAINT "cuota_aplicaciones_periodo_id_usuario_fkey" FOREIGN KEY (periodo, id_usuario) REFERENCES privado.cuota_cargos(periodo, id_usuario);

ALTER TABLE "privado"."cuota_cargos" ADD CONSTRAINT "cuota_cargos_id_unidad_fkey" FOREIGN KEY (id_unidad) REFERENCES unidades(id_unidad);

ALTER TABLE "privado"."cuota_cargos" ADD CONSTRAINT "cuota_cargos_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."cuota_cargos" ADD CONSTRAINT "cuota_cargos_periodo_fkey" FOREIGN KEY (periodo) REFERENCES privado.cuota_periodos(id);

ALTER TABLE "privado"."cuota_cuentas" ADD CONSTRAINT "cuota_cuentas_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."cuota_cuentas" ADD CONSTRAINT "cuota_cuentas_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."cuota_ingresos" ADD CONSTRAINT "cuota_ingresos_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."cuota_ingresos" ADD CONSTRAINT "cuota_ingresos_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."cuota_periodos" ADD CONSTRAINT "cuota_periodos_actividad_fkey" FOREIGN KEY (actividad) REFERENCES privado.reuniones(id);

ALTER TABLE "privado"."cuota_periodos" ADD CONSTRAINT "cuota_periodos_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."historial_asistencias" ADD CONSTRAINT "historial_asistencias_id_asistencia_fkey" FOREIGN KEY (id_asistencia) REFERENCES asistencias(id_asistencia);

ALTER TABLE "privado"."inscripciones" ADD CONSTRAINT "inscripciones_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."inscripciones" ADD CONSTRAINT "inscripciones_id_clase_fkey" FOREIGN KEY (id_clase) REFERENCES clases(id_clase);

ALTER TABLE "privado"."inscripciones" ADD CONSTRAINT "inscripciones_id_unidad_fkey" FOREIGN KEY (id_unidad) REFERENCES unidades(id_unidad);

ALTER TABLE "privado"."inscripciones" ADD CONSTRAINT "inscripciones_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_destinatario_clase_fkey" FOREIGN KEY (destinatario_clase) REFERENCES clases(id_clase);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_destinatario_unidad_fkey" FOREIGN KEY (destinatario_unidad) REFERENCES unidades(id_unidad);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "privado"."reuniones" ADD CONSTRAINT "reuniones_periodo_cuota_fkey" FOREIGN KEY (periodo_cuota) REFERENCES privado.cuota_periodos(id);

ALTER TABLE "privado"."unidades_revisadas" ADD CONSTRAINT "unidades_revisadas_reunion_fkey" FOREIGN KEY (reunion) REFERENCES privado.reuniones(id);

ALTER TABLE "privado"."usuarios_contacto" ADD CONSTRAINT "usuarios_contacto_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT;

ALTER TABLE "privado"."usuarios_salud" ADD CONSTRAINT "usuarios_salud_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE RESTRICT;

ALTER TABLE "public"."asistencias" ADD CONSTRAINT "asistencias_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "public"."asistencias" ADD CONSTRAINT "asistencias_id_reunion_fkey" FOREIGN KEY (id_reunion) REFERENCES privado.reuniones(id);

ALTER TABLE "public"."asistencias" ADD CONSTRAINT "asistencias_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "public"."conquistador_especialidades" ADD CONSTRAINT "conquistador_especialidades_id_especialidad_fkey" FOREIGN KEY (id_especialidad) REFERENCES especialidades(id_especialidad);

ALTER TABLE "public"."conquistador_especialidades" ADD CONSTRAINT "conquistador_especialidades_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "public"."cuotas" ADD CONSTRAINT "cuotas_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "public"."cuotas" ADD CONSTRAINT "cuotas_id_usuario_fkey" FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario);

ALTER TABLE "public"."unidades" ADD CONSTRAINT "unidades_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "public"."usuarios" ADD CONSTRAINT "usuarios_id_ciclo_fkey" FOREIGN KEY (id_ciclo) REFERENCES ciclos(id_ciclo);

ALTER TABLE "public"."usuarios" ADD CONSTRAINT "usuarios_id_clase_fkey" FOREIGN KEY (id_clase) REFERENCES clases(id_clase);

ALTER TABLE "public"."usuarios" ADD CONSTRAINT "usuarios_id_unidad_fkey" FOREIGN KEY (id_unidad) REFERENCES unidades(id_unidad);

-- Índices no asociados a restricciones.

CREATE UNIQUE INDEX competencia_criterio_nombre ON privado.competencia_criterios USING btree (lower(btrim(nombre)));

CREATE UNIQUE INDEX competencia_fuente_auto ON privado.competencia_criterios USING btree (fuente) WHERE (fuente <> 'manual'::text);

CREATE INDEX capitanes_por_unidad ON privado.inscripciones USING btree (id_ciclo, id_unidad) WHERE (activo AND (rol = 'capitan'::text));

CREATE UNIQUE INDEX reunion_nombre_dia ON privado.reuniones USING btree (id_ciclo, fecha, lower(nombre)) WHERE (NOT eliminado);

CREATE UNIQUE INDEX reunion_numero_dia ON privado.reuniones USING btree (id_ciclo, fecha, numero);

CREATE UNIQUE INDEX asistencia_por_reunion ON public.asistencias USING btree (id_reunion, id_usuario);

CREATE UNIQUE INDEX un_ciclo_activo ON public.ciclos USING btree (es_activo) WHERE es_activo;

CREATE VIEW "privado"."convocados_asistencia" AS  SELECT c.reunion,
    c.id_usuario,
    c.id_unidad,
    c.unidad,
    c.estado,
    c.motivo,
    c.exento_asistencia
   FROM privado.convocados c
     JOIN usuarios u ON u.id_usuario = c.id_usuario
  WHERE NOT c.exento_asistencia AND u.rol::text <> 'directiva'::text;

-- Catálogos/configuración inicial: sin usuarios, contactos, pagos ni evaluaciones.

INSERT INTO public.ciclos ("id_ciclo","anio","es_activo") VALUES ('c0000000-0000-4000-8000-000000000001',extract(year FROM now() AT TIME ZONE 'America/Mexico_City')::integer,'true');

INSERT INTO public.clases ("id_clase","nombre","color_distintivo","url_foto","es_activa","version") VALUES ('b0000000-0000-4000-8000-000000000001','Amigo','#2454c6',NULL,'true','1');

INSERT INTO public.clases ("id_clase","nombre","color_distintivo","url_foto","es_activa","version") VALUES ('b0000000-0000-4000-8000-000000000002','Compañero','#c92a36',NULL,'true','1');

INSERT INTO public.especialidades ("id_especialidad","nombre","url_imagen") VALUES ('f0000000-0000-4000-8000-000000000001','Primeros Auxilios','img/especialidades/primeros_auxilios.png');

INSERT INTO public.especialidades ("id_especialidad","nombre","url_imagen") VALUES ('f0000000-0000-4000-8000-000000000002','Ejercicios y Marchas','img/especialidades/ejercicios_y_marchas.png');

INSERT INTO public.especialidades ("id_especialidad","nombre","url_imagen") VALUES ('f0000000-0000-4000-8000-000000000003','Nudos','img/especialidades/nudos.png');

INSERT INTO public.especialidades ("id_especialidad","nombre","url_imagen") VALUES ('f0000000-0000-4000-8000-000000000004','Astronomía','img/especialidades/astronomia.png');

INSERT INTO privado.competencia_config ("id","version","justificados") VALUES ('true','1','true');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('37f8d127-78d6-412d-a87b-3a914220842d','Biblia','manual','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('197cd1c2-7640-44a7-a8b3-8c3da297d70c','Puntualidad','manual','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('222af395-67bd-4cf8-a8e2-4a3bc18ea096','Versículo','manual','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('d05f8e3c-94a6-4e73-a34c-11f88e36eb53','Limpieza','manual','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('27bb59b7-c7bd-482b-bd4f-5e66bd608905','Asistencia','asistencia','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('64b25040-1851-4da7-9096-2b0bf028dd55','Cuota','cuota','5','true','false');

INSERT INTO privado.competencia_criterios ("id","nombre","fuente","valor","activo","solo_conquistadores") VALUES ('dbedb533-2b3b-4d39-9ee7-3085788545ff','Cuadernillo','manual','5','true','true');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('001_cuentas_y_datos_privados','2026-11-05T03:23:41.9+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('002_login_rls','2026-11-05T03:23:41.932+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('003_directorio_compartido','2026-11-05T03:23:41.99+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('004_administrar_integrantes','2026-11-05T03:23:41.993+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('005_portal_y_fotos','2026-11-05T03:23:41.998+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('006_asistencias','2026-11-05T03:23:42.004+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('007_reuniones','2026-11-05T03:23:42.012+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('008_matriz_asistencias','2026-11-05T03:23:42.036+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('009_pases_por_reunion','2026-11-05T03:23:42.04+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('010_cuotas','2026-11-05T03:23:42.094+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('011_calendario','2026-11-05T03:23:42.131+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('012_tipos_actividades','2026-11-05T03:23:42.145+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('013_cierre_cuotas','2026-11-05T03:23:42.191+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('014_organizacion','2026-11-05T03:23:42.199+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('015_perfiles_unidades','2026-11-05T03:23:42.217+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('016_asistencias_offline_colores','2026-11-05T03:23:42.219+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('017_altas_reuniones_pendientes','2026-11-05T03:23:42.225+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('018_competencia','2026-11-05T03:23:42.231+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('019_competencia_resultados','2026-11-05T03:23:42.254+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('020_competencia_integrada','2026-11-05T03:23:42.293+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('021_cierre_puntajes','2026-11-05T03:23:42.309+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('022_reunion_unificada','2026-11-05T03:23:42.321+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('023_captura_capitan','2026-11-05T03:23:42.332+00:00');

INSERT INTO privado.migraciones ("version","aplicada_en") VALUES ('024_capitanes_fotos','2026-11-05T03:23:42.34+00:00');

INSERT INTO privado.cuota_epoca DEFAULT VALUES;

-- Buckets privados; Auth/Storage son administrados por Supabase.

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('integrantes-fotos','integrantes-fotos',false,2097152,ARRAY['image/webp']) ON CONFLICT(id) DO UPDATE SET public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES('unidades-fotos','unidades-fotos',false,2097152,ARRAY['image/webp']) ON CONFLICT(id) DO UPDATE SET public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

-- Triggers finales (después de semillas para no producir registros ficticios).

CREATE TRIGGER actividad_fecha_fin BEFORE INSERT ON privado.reuniones FOR EACH ROW EXECUTE FUNCTION privado.actividad_fecha_fin();

CREATE TRIGGER competencia_proteger_fecha BEFORE UPDATE ON privado.reuniones FOR EACH ROW EXECUTE FUNCTION privado.competencia_proteger_fecha();

CREATE TRIGGER alta_bloquear_reuniones BEFORE INSERT ON usuarios FOR EACH ROW EXECUTE FUNCTION privado.bloquear_alta_reuniones();

CREATE TRIGGER alta_incorporar_reuniones AFTER INSERT ON usuarios FOR EACH ROW EXECUTE FUNCTION privado.incorporar_alta_reuniones();

CREATE TRIGGER incrementar_version_perfil BEFORE UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION privado.incrementar_version_perfil();

CREATE TRIGGER sincronizar_inscripcion AFTER INSERT OR UPDATE ON usuarios FOR EACH ROW EXECUTE FUNCTION privado.sincronizar_inscripcion();

CREATE TRIGGER validar_inscripcion BEFORE INSERT OR UPDATE OF id_ciclo, id_unidad, id_clase, rol, es_activo ON usuarios FOR EACH ROW EXECUTE FUNCTION privado.validar_inscripcion();

-- RLS y políticas, incluidas las políticas de archivos privados.

ALTER TABLE "privado"."asistencia_operaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."bitacora_reuniones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_config" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_cortes" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_criterios" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_extras" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_finales" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_hojas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_marcas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_operaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_periodos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."competencia_reaperturas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."convocados" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuentas_miembros" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_aplicaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_cargos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_cuentas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_epoca" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_ingresos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_operaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."cuota_periodos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."historial_asistencias" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."historial_calendario" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."historial_organizacion" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."historial_perfiles" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."historial_vinculaciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."inscripciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."migraciones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."reuniones" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."unidades_revisadas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."usuarios_contacto" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "privado"."usuarios_salud" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."asistencias" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."ciclos" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."clases" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."conquistador_especialidades" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."cuotas" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."especialidades" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."unidades" ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."usuarios" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "lectura_asistencias" ON "public"."asistencias" AS PERMISSIVE FOR SELECT TO "authenticated" USING (privado.pase_publicado(id_reunion, id_usuario));

CREATE POLICY "lectura_catalogo" ON "public"."ciclos" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.mi_id() AS mi_id) IS NOT NULL));

CREATE POLICY "lectura_catalogo" ON "public"."clases" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.mi_id() AS mi_id) IS NOT NULL));

CREATE POLICY "lectura_autorizada" ON "public"."conquistador_especialidades" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.es_directiva() AS es_directiva) OR (id_usuario = ( SELECT privado.mi_id() AS mi_id))));

CREATE POLICY "lectura_autorizada" ON "public"."cuotas" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.es_directiva() AS es_directiva) OR (id_usuario = ( SELECT privado.mi_id() AS mi_id))));

CREATE POLICY "lectura_catalogo" ON "public"."especialidades" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.mi_id() AS mi_id) IS NOT NULL));

CREATE POLICY "lectura_catalogo" ON "public"."unidades" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.mi_id() AS mi_id) IS NOT NULL));

CREATE POLICY "lectura_autorizada" ON "public"."usuarios" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((( SELECT privado.es_directiva() AS es_directiva) OR (id_usuario = ( SELECT privado.mi_id() AS mi_id))));

CREATE POLICY "fotos_alta" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((bucket_id = 'integrantes-fotos'::text) AND privado.es_directiva() AND (name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'::text)));

CREATE POLICY "fotos_lectura" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'integrantes-fotos'::text) AND privado.foto_visible(name)));

CREATE POLICY "fotos_limpieza" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((bucket_id = 'integrantes-fotos'::text) AND privado.es_directiva() AND (NOT (EXISTS ( SELECT 1
   FROM usuarios u
  WHERE (u.foto_path = objects.name))))));

CREATE POLICY "unidad_foto_leer" ON "storage"."objects" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((bucket_id = 'unidades-fotos'::text) AND (privado.mi_id() IS NOT NULL) AND (EXISTS ( SELECT 1
   FROM unidades
  WHERE (unidades.foto_path = objects.name)))));

CREATE POLICY "unidad_foto_limpiar" ON "storage"."objects" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((bucket_id = 'unidades-fotos'::text) AND privado.editar_unidad((split_part(name, '/'::text, 1))::uuid) AND (NOT (EXISTS ( SELECT 1
   FROM unidades
  WHERE (unidades.foto_path = objects.name))))));

CREATE POLICY "unidad_foto_subir" ON "storage"."objects" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((bucket_id = 'unidades-fotos'::text) AND (name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'::text) AND privado.editar_unidad((split_part(name, '/'::text, 1))::uuid)));

-- ACL efectivas: elimina grants implícitos de instalación antes de reproducir permisos.

REVOKE ALL ON SCHEMA "public" FROM PUBLIC,anon,authenticated;

GRANT USAGE ON SCHEMA "public" TO PUBLIC;

GRANT USAGE ON SCHEMA "public" TO "authenticated";

REVOKE ALL ON SCHEMA "privado" FROM PUBLIC,anon,authenticated;

GRANT USAGE ON SCHEMA "privado" TO "authenticated";

REVOKE ALL ON TABLE "privado"."asistencia_operaciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."bitacora_reuniones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_config" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_cortes" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_criterios" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_extras" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_finales" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_hojas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_marcas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_operaciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_periodos" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."competencia_reaperturas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."convocados" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuentas_miembros" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_aplicaciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_cargos" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_cuentas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_epoca" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_ingresos" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_operaciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."cuota_periodos" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."historial_asistencias" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."historial_calendario" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."historial_organizacion" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."historial_perfiles" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."historial_vinculaciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."inscripciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."migraciones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."reuniones" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."unidades_revisadas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."usuarios_contacto" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "privado"."usuarios_salud" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "public"."asistencias" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."asistencias" TO "authenticated";

REVOKE ALL ON TABLE "public"."ciclos" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."ciclos" TO "authenticated";

REVOKE ALL ON TABLE "public"."clases" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."clases" TO "authenticated";

REVOKE ALL ON TABLE "public"."conquistador_especialidades" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."conquistador_especialidades" TO "authenticated";

REVOKE ALL ON TABLE "public"."cuotas" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON TABLE "public"."especialidades" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."especialidades" TO "authenticated";

REVOKE ALL ON TABLE "public"."unidades" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."unidades" TO "authenticated";

REVOKE ALL ON TABLE "public"."usuarios" FROM PUBLIC,anon,authenticated;

GRANT SELECT ON TABLE "public"."usuarios" TO "authenticated";

REVOKE ALL ON TABLE "privado"."convocados_asistencia" FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."actividad_cobro"(p_actividad uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."actividad_fecha_fin"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."asistencia_publicada"(p_usuario uuid, p_ciclo uuid, p_fecha date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."asistencia_publicada"(p_usuario uuid, p_ciclo uuid, p_fecha date) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."bloquear_alta_reuniones"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."calendario_liberar_cobro"(p_periodo uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_asistencia"(p_reunion uuid, p_usuario uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_auto"(p_reunion uuid, p_usuario uuid, p_fuente text, p_justificados boolean) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_detalle"(p_ciclo uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_detalle_abierto"(p_ciclo uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_estadisticas"(p_ciclo uuid, p_desde date, p_hasta date, p_admin boolean, p_consejeros boolean) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_filas"(p_ciclo uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_guardar_019"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_guardar_020"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_panel_019"(p_reunion uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_panel_020"(p_reunion uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_presencial"(p_reunion uuid, p_usuario uuid, p_rol text, p_criterio jsonb) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_proteger_fecha"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_ranking"(p_ciclo uuid, p_desde date, p_hasta date, p_admin boolean) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."competencia_reuniones_visibles"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."cuota_aplicar"(p_usuario uuid, p_ciclo uuid, p_periodos uuid[], p_ingreso uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."cuota_visible"(p_usuario uuid, p_ciclo uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."cuotas_panel_019"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."cuotas_resumen_019"(p_usuario uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."editar_unidad"(p_id uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."editar_unidad"(p_id uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."es_directiva"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."es_directiva"() TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."foto_visible"(p_path text) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."foto_visible"(p_path text) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."incorporar_alta_reuniones"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."incorporar_integrante_pendientes"(p_usuario uuid, p_desde date) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."incrementar_version_perfil"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."mi_id"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."mi_id"() TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."pase_publicado"(p_reunion uuid, p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."pase_publicado"(p_reunion uuid, p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."publicar_reunion"(p_id uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."puede_ver_asistencia"(p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."puede_ver_asistencia"(p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."reuniones_unidad_visibles"(p_puntajes boolean) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."sincronizar_inscripcion"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."validar_inscripcion"() FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "privado"."ver_convocado"(p_reunion uuid, p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "privado"."ver_convocado"(p_reunion uuid, p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "privado"."vincular_cuenta"(p_id_usuario uuid, p_auth_id uuid) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "public"."admin_estado_integrante"(p_id_usuario uuid, p_version bigint, p_activo boolean) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."admin_estado_integrante"(p_id_usuario uuid, p_version bigint, p_activo boolean) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."admin_guardar_integrante"(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."admin_guardar_integrante"(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."admin_guardar_perfil"(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text, p_foto_path text) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."admin_guardar_perfil"(p_id_usuario uuid, p_version bigint, p_nombres text, p_apellido text, p_rol text, p_id_unidad uuid, p_id_clase uuid, p_url_foto text, p_foto_path text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."asistencia_operar"(p_operacion uuid, p_epoca uuid, p_id uuid, p_version bigint, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."asistencia_operar"(p_operacion uuid, p_epoca uuid, p_id uuid, p_version bigint, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."asistencia_resumen"(p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."asistencia_resumen"(p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."asistencias_bitacora"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."asistencias_bitacora"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."asistencias_contexto"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."asistencias_contexto"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."calendario_cancelar"(p_id uuid, p_version bigint, p_motivo text) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."calendario_cancelar"(p_id uuid, p_version bigint, p_motivo text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."calendario_eliminar"(p_id uuid, p_version bigint) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."calendario_eliminar"(p_id uuid, p_version bigint) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."calendario_guardar"(p_id uuid, p_version bigint, p_fecha date, p_hora time without time zone, p_nombre text, p_cobra boolean, p_tipo text, p_fecha_fin date, p_unidad uuid, p_clase uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."calendario_guardar"(p_id uuid, p_version bigint, p_fecha date, p_hora time without time zone, p_nombre text, p_cobra boolean, p_tipo text, p_fecha_fin date, p_unidad uuid, p_clase uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."calendario_listar"(p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."calendario_listar"(p_desde date, p_hasta date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."colores_integrantes"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."colores_integrantes"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."competencia_guardar"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."competencia_guardar"(p_operacion uuid, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."competencia_panel"(p_reunion uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."competencia_panel"(p_reunion uuid, p_desde date, p_hasta date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."competencia_perfil"(p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."competencia_perfil"(p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."competencia_publicacion"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."competencia_publicacion"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."competencia_unidad"(p_unidad uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."competencia_unidad"(p_unidad uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."cuotas_operar"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."cuotas_operar"(p_operacion uuid, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."cuotas_panel"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."cuotas_panel"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."cuotas_resumen"(p_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."cuotas_resumen"(p_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."directorio_integrantes"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."directorio_integrantes"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."directorio_portal"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."directorio_portal"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."especialidades_visibles"(p_id_usuario uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."especialidades_visibles"(p_id_usuario uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."guardar_asistencias"(p_fecha date, p_cambios jsonb) FROM PUBLIC,anon,authenticated;

REVOKE ALL ON FUNCTION "public"."historial_matriz"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."historial_matriz"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."historial_matriz_turnos"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."historial_matriz_turnos"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."integrantes_asistencias"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."integrantes_asistencias"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."mi_perfil"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."mi_perfil"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."organizacion_guardar"(p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."organizacion_guardar"(p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."organizacion_guardar_023"(p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."organizacion_guardar_023"(p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."organizacion_panel"(p_ciclo uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."organizacion_panel"(p_ciclo uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."presentacion_integrantes"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."presentacion_integrantes"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_accion"(p_id uuid, p_version bigint, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_accion"(p_id uuid, p_version bigint, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_crear"(p_fecha date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_crear"(p_fecha date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_crear_turno"(p_fecha date, p_nombre text) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_crear_turno"(p_fecha date, p_nombre text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_integrada_guardar"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_integrada_guardar"(p_operacion uuid, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_integrada_guardar_022"(p_operacion uuid, p_accion text, p_datos jsonb) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_integrada_guardar_022"(p_operacion uuid, p_accion text, p_datos jsonb) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_integrada_panel"(p_reunion uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_integrada_panel"(p_reunion uuid, p_desde date, p_hasta date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_integrada_panel_022"(p_reunion uuid, p_desde date, p_hasta date) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_integrada_panel_022"(p_reunion uuid, p_desde date, p_hasta date) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reunion_panel"(p_id uuid) FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reunion_panel"(p_id uuid) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reuniones_listar"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reuniones_listar"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."reuniones_listar_turnos"() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION "public"."reuniones_listar_turnos"() TO "authenticated";

NOTIFY pgrst, 'reload schema';
COMMIT;
