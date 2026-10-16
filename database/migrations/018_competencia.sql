-- Competencia: capturas por reunión y cortes que conservan el acumulado anual.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='017_altas_reuniones_pendientes') THEN RAISE EXCEPTION 'Ejecuta primero 017_altas_reuniones_pendientes.sql'; END IF;
END $$;
CREATE TABLE IF NOT EXISTS privado.competencia_config(id BOOLEAN PRIMARY KEY DEFAULT true CHECK(id),version BIGINT NOT NULL DEFAULT 1,justificados BOOLEAN NOT NULL DEFAULT true);
INSERT INTO privado.competencia_config(id) VALUES(true) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS privado.competencia_criterios(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),nombre TEXT NOT NULL CHECK(length(btrim(nombre)) BETWEEN 1 AND 60),
 fuente TEXT NOT NULL DEFAULT 'manual' CHECK(fuente IN ('manual','asistencia','cuota')),
 valor INTEGER NOT NULL DEFAULT 5 CHECK(valor BETWEEN 0 AND 10000),activo BOOLEAN NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX IF NOT EXISTS competencia_criterio_nombre ON privado.competencia_criterios(lower(btrim(nombre)));
CREATE UNIQUE INDEX IF NOT EXISTS competencia_fuente_auto ON privado.competencia_criterios(fuente) WHERE fuente<>'manual';
INSERT INTO privado.competencia_criterios(nombre,fuente) SELECT nombre,fuente FROM (VALUES
 ('Biblia','manual'),('Puntualidad','manual'),('Versículo','manual'),('Cuadernillo','manual'),('Limpieza','manual'),('Asistencia','asistencia'),('Cuota','cuota')) v(nombre,fuente)
 WHERE NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='018_competencia') ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS privado.competencia_hojas(
 reunion UUID PRIMARY KEY REFERENCES privado.reuniones,id_ciclo UUID NOT NULL REFERENCES public.ciclos,
 fecha DATE NOT NULL,criterios JSONB NOT NULL,justificados BOOLEAN NOT NULL,version BIGINT NOT NULL DEFAULT 1
);
CREATE TABLE IF NOT EXISTS privado.competencia_marcas(
 reunion UUID NOT NULL REFERENCES privado.competencia_hojas,id_usuario UUID NOT NULL REFERENCES public.usuarios,
 id_unidad UUID REFERENCES public.unidades,nombre TEXT NOT NULL,unidad TEXT NOT NULL,cumplidos UUID[] NOT NULL DEFAULT '{}',automaticos_corte UUID[],
 PRIMARY KEY(reunion,id_usuario)
);
CREATE TABLE IF NOT EXISTS privado.competencia_extras(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),reunion UUID NOT NULL REFERENCES privado.competencia_hojas,
 id_usuario UUID REFERENCES public.usuarios,id_unidad UUID REFERENCES public.unidades,nombre TEXT,unidad TEXT NOT NULL,
 puntos INTEGER NOT NULL CHECK(puntos BETWEEN 1 AND 10000),motivo TEXT NOT NULL CHECK(length(btrim(motivo)) BETWEEN 1 AND 300),
 CHECK(id_usuario IS NOT NULL OR id_unidad IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS privado.competencia_cortes(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),id_ciclo UUID NOT NULL REFERENCES public.ciclos,nombre TEXT NOT NULL,
 desde DATE NOT NULL,hasta DATE NOT NULL CHECK(hasta>=desde),resultados JSONB NOT NULL,auth_id UUID NOT NULL,creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS privado.competencia_operaciones(
 id UUID PRIMARY KEY,auth_id UUID NOT NULL,accion TEXT NOT NULL,datos JSONB NOT NULL,fecha TIMESTAMPTZ NOT NULL DEFAULT now()
);
DO $$ DECLARE t TEXT; BEGIN
 FOREACH t IN ARRAY ARRAY['competencia_config','competencia_criterios','competencia_hojas','competencia_marcas','competencia_extras','competencia_cortes','competencia_operaciones'] LOOP
 EXECUTE 'ALTER TABLE privado.'||t||' ENABLE ROW LEVEL SECURITY';
 EXECUTE 'REVOKE ALL ON privado.'||t||' FROM PUBLIC,anon,authenticated';
 END LOOP;
END $$;

CREATE OR REPLACE FUNCTION privado.competencia_auto(p_reunion UUID,p_usuario UUID,p_fuente TEXT,p_justificados BOOLEAN)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT CASE p_fuente WHEN 'asistencia' THEN EXISTS(
  SELECT 1 FROM privado.reuniones r JOIN privado.convocados_asistencia c ON c.reunion=r.id
  WHERE r.id=p_reunion AND r.estado='cerrada' AND c.id_usuario=p_usuario
  AND (c.estado='asistencia' OR (p_justificados AND c.estado='justificado'))
 ) WHEN 'cuota' THEN EXISTS(
  SELECT 1 FROM privado.reuniones r JOIN privado.cuota_periodos p ON p.id=r.periodo_cuota
  JOIN privado.cuota_cargos c ON c.periodo=p.id
  WHERE r.id=p_reunion AND NOT p.cancelado AND c.id_usuario=p_usuario
  AND coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)>=c.importe
 ) ELSE false END;
$$;
CREATE OR REPLACE FUNCTION privado.competencia_filas(p_ciclo UUID,p_desde DATE,p_hasta DATE)
RETURNS TABLE(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH abiertas AS (
  SELECT h.* FROM privado.competencia_hojas h JOIN privado.reuniones r ON r.id=h.reunion
  WHERE h.id_ciclo=p_ciclo AND h.fecha BETWEEN p_desde AND p_hasta AND r.tipo='regular' AND NOT r.eliminado AND r.estado<>'anulada'
  AND NOT EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=p_ciclo AND h.fecha BETWEEN c.desde AND c.hasta)
 )
 SELECT h.fecha,m.id_usuario,m.id_unidad,m.nombre,m.unidad,coalesce((SELECT sum((k->>'valor')::integer) FROM jsonb_array_elements(h.criterios) k
 WHERE CASE WHEN k->>'fuente'='manual' THEN (k->>'id')::uuid=ANY(m.cumplidos)
 ELSE privado.competencia_auto(h.reunion,m.id_usuario,k->>'fuente',h.justificados) END),0)::bigint
 FROM abiertas h JOIN privado.competencia_marcas m ON m.reunion=h.reunion
 UNION ALL SELECT h.fecha,e.id_usuario,e.id_unidad,e.nombre,e.unidad,e.puntos::bigint FROM abiertas h JOIN privado.competencia_extras e ON e.reunion=h.reunion
 UNION ALL SELECT f.fecha,f.id_usuario,f.id_unidad,f.nombre,f.unidad,f.puntos
 FROM privado.competencia_cortes c CROSS JOIN LATERAL jsonb_to_recordset(c.resultados) AS f(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT)
 WHERE c.id_ciclo=p_ciclo AND f.fecha BETWEEN p_desde AND p_hasta;
$$;
CREATE OR REPLACE FUNCTION privado.competencia_ranking(p_ciclo UUID,p_desde DATE,p_hasta DATE,p_admin BOOLEAN)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH filas AS (SELECT * FROM privado.competencia_filas(p_ciclo,p_desde,p_hasta)),
 individuos AS (SELECT id_usuario,max(nombre) nombre,sum(puntos) puntos FROM filas WHERE id_usuario IS NOT NULL GROUP BY id_usuario),
 unidades AS (SELECT id_unidad,max(unidad) nombre,sum(puntos) puntos FROM filas WHERE id_unidad IS NOT NULL GROUP BY id_unidad),
 destacados AS (SELECT id_usuario,nombre FROM individuos WHERE puntos>0 ORDER BY puntos DESC,id_usuario LIMIT 15)
 SELECT jsonb_build_object(
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u) ORDER BY puntos DESC,nombre,id_unidad) FROM unidades u),'[]'::jsonb),
 'individual',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY puntos DESC,nombre,id_usuario) FROM individuos i),'[]'::jsonb) ELSE '[]'::jsonb END,
 'destacados',coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY random()) FROM destacados d),'[]'::jsonb));
$$;

CREATE OR REPLACE FUNCTION public.competencia_panel(p_reunion UUID DEFAULT NULL,p_desde DATE DEFAULT NULL,p_hasta DATE DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ciclo UUID; anio INTEGER; es_admin BOOLEAN; hoy DATE:=(now() AT TIME ZONE 'America/Mexico_City')::date;
 desde DATE; hasta DATE; r privado.reuniones%ROWTYPE; h privado.competencia_hojas%ROWTYPE; criterios JSONB; justificados BOOLEAN; captura JSONB;
BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 es_admin:=privado.es_directiva();
 SELECT id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 IF ciclo IS NULL THEN RAISE EXCEPTION 'No hay ciclo activo.' USING ERRCODE='22023'; END IF;
 desde:=coalesce(p_desde,(SELECT max(c.hasta)+1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo),greatest(make_date(anio,1,1),least(date_trunc('month',hoy)::date,make_date(anio,12,1))));
 IF p_desde IS NULL AND desde>make_date(anio,12,31) THEN desde:=make_date(anio,1,1); END IF;
 hasta:=coalesce(p_hasta,greatest(desde,least(hoy,make_date(anio,12,31))));
 IF desde<make_date(anio,1,1) OR hasta>make_date(anio,12,31) OR hasta<desde THEN RAISE EXCEPTION 'Selecciona fechas del ciclo actual.' USING ERRCODE='22023'; END IF;
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
    'cumplidos',coalesce(m.cumplidos,'{}'::uuid[]),'automaticos',coalesce(to_jsonb(m.automaticos_corte),(SELECT jsonb_agg(k->>'id') FROM jsonb_array_elements(criterios) k WHERE k->>'fuente'<>'manual' AND privado.competencia_auto(r.id,u.id_usuario,k->>'fuente',justificados)),'[]'::jsonb),
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
  'resultados',privado.competencia_ranking(ciclo,desde,hasta,es_admin),
  'anual',CASE WHEN es_admin THEN privado.competencia_ranking(ciclo,make_date(anio,1,1),make_date(anio,12,31),true) ELSE NULL END,
  'bitacora',CASE WHEN es_admin THEN coalesce((SELECT jsonb_agg(jsonb_build_object('id',o.id,'fecha',o.fecha,'accion',o.accion,'autor',coalesce(u.nombres||' '||u.apellido,'Directiva')) ORDER BY o.fecha DESC,o.id)
   FROM privado.competencia_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u USING(id_usuario) WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END);
END $$;

CREATE OR REPLACE FUNCTION public.competencia_guardar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE ciclo UUID; anio INTEGER; anterior privado.competencia_operaciones%ROWTYPE; r privado.reuniones%ROWTYPE; h privado.competencia_hojas%ROWTYPE;
 criterios JSONB; dato JSONB; participante RECORD; criterio_id UUID; fuente TEXT; v_desde DATE; v_hasta DATE; resultados JSONB;
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
  DELETE FROM privado.competencia_marcas WHERE reunion=r.id;
  FOR dato IN SELECT * FROM jsonb_array_elements(p_datos->'integrantes') LOOP
   IF jsonb_typeof(dato->'cumplidos') IS DISTINCT FROM 'array' OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(dato->'cumplidos') x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(criterios) k WHERE k->>'id'=x AND k->>'fuente'='manual')) THEN RAISE EXCEPTION 'Criterio inválido. Asistencia y cuota se calculan automáticamente.' USING ERRCODE='22023'; END IF;
   INSERT INTO privado.competencia_marcas(reunion,id_usuario,id_unidad,nombre,unidad,cumplidos)
   SELECT r.id,c.id_usuario,c.id_unidad,u.nombres||' '||u.apellido,c.unidad,ARRAY(SELECT DISTINCT x::uuid FROM jsonb_array_elements_text(dato->'cumplidos') x)
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
 ELSIF p_accion='corte' THEN
  v_desde:=(p_datos->>'desde')::date;v_hasta:=(p_datos->>'hasta')::date;
  IF v_desde IS NULL OR v_hasta IS NULL OR v_hasta<v_desde OR v_desde<make_date(anio,1,1) OR v_hasta>make_date(anio,12,31) OR v_hasta>(now() AT TIME ZONE 'America/Mexico_City')::date OR length(btrim(coalesce(p_datos->>'nombre',''))) NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'Revisa el nombre y las fechas del corte.' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM privado.competencia_cortes c WHERE c.id_ciclo=ciclo AND c.desde<=v_hasta AND c.hasta>=v_desde) THEN RAISE EXCEPTION 'Las fechas ya pertenecen a otro corte.' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM privado.reuniones rr LEFT JOIN privado.competencia_hojas hh ON hh.reunion=rr.id WHERE rr.id_ciclo=ciclo AND rr.fecha BETWEEN v_desde AND v_hasta AND rr.tipo='regular' AND NOT rr.importada AND NOT rr.eliminado AND rr.estado<>'anulada' AND
   (hh.reunion IS NULL OR rr.estado<>'cerrada' OR EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=rr.id AND NOT EXISTS(SELECT 1 FROM privado.competencia_marcas m WHERE m.reunion=rr.id AND m.id_usuario=c.id_usuario))
    OR EXISTS(SELECT 1 FROM privado.cuota_cargos cc JOIN privado.cuota_periodos cp ON cp.id=cc.periodo WHERE cc.periodo=rr.periodo_cuota AND NOT cp.cancelado AND NOT cc.cerrado))) THEN RAISE EXCEPTION 'Completa los puntajes y cierra las asistencias y cobros del periodo antes del corte.' USING ERRCODE='22023'; END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(f)),'[]'::jsonb) INTO resultados FROM privado.competencia_filas(ciclo,v_desde,v_hasta) f;
  UPDATE privado.competencia_marcas m SET automaticos_corte=ARRAY(SELECT (k->>'id')::uuid FROM jsonb_array_elements(hh.criterios) k WHERE k->>'fuente'<>'manual' AND privado.competencia_auto(hh.reunion,m.id_usuario,k->>'fuente',hh.justificados))
  FROM privado.competencia_hojas hh WHERE hh.reunion=m.reunion AND hh.id_ciclo=ciclo AND hh.fecha BETWEEN v_desde AND v_hasta;
  INSERT INTO privado.competencia_cortes(id_ciclo,nombre,desde,hasta,resultados,auth_id) VALUES(ciclo,btrim(p_datos->>'nombre'),v_desde,v_hasta,resultados,auth.uid());
 ELSE RAISE EXCEPTION 'Acción no disponible.' USING ERRCODE='22023'; END IF;
 INSERT INTO privado.competencia_operaciones(id,auth_id,accion,datos) VALUES(p_operacion,auth.uid(),p_accion,p_datos);
END $$;

DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.competencia_auto(uuid,uuid,text,boolean)','privado.competencia_filas(uuid,date,date)','privado.competencia_ranking(uuid,date,date,boolean)','public.competencia_panel(uuid,date,date)','public.competencia_guardar(uuid,text,jsonb)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 END LOOP;
END $$;

-- Una fecha con puntajes no se puede trasladar a otro periodo mediante Calendario.
CREATE OR REPLACE FUNCTION privado.competencia_proteger_fecha() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF (NEW.fecha IS DISTINCT FROM OLD.fecha OR NEW.tipo IS DISTINCT FROM OLD.tipo OR NEW.id_ciclo IS DISTINCT FROM OLD.id_ciclo)
 AND EXISTS(SELECT 1 FROM privado.competencia_hojas WHERE reunion=OLD.id) THEN
 RAISE EXCEPTION 'La actividad ya tiene puntajes. Conserva su fecha y tipo.' USING ERRCODE='22023'; END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS competencia_proteger_fecha ON privado.reuniones;
CREATE TRIGGER competencia_proteger_fecha BEFORE UPDATE ON privado.reuniones FOR EACH ROW EXECUTE FUNCTION privado.competencia_proteger_fecha();
REVOKE ALL ON FUNCTION privado.competencia_proteger_fecha() FROM PUBLIC,anon,authenticated;

GRANT EXECUTE ON FUNCTION public.competencia_panel(uuid,date,date),public.competencia_guardar(uuid,text,jsonb) TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('018_competencia') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
