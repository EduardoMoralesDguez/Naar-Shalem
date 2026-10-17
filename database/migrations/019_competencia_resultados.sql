-- Competencia: presencia, categorías, periodos programados y publicación limitada.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='018_competencia') THEN RAISE EXCEPTION 'Ejecuta primero 018_competencia.sql'; END IF;
END $$;
ALTER TABLE privado.competencia_marcas ADD COLUMN IF NOT EXISTS rol TEXT;
UPDATE privado.competencia_marcas m SET rol=u.rol FROM public.usuarios u WHERE u.id_usuario=m.id_usuario AND m.rol IS NULL;
ALTER TABLE privado.competencia_cortes ADD COLUMN IF NOT EXISTS detalle JSONB;
ALTER TABLE privado.competencia_cortes ADD COLUMN IF NOT EXISTS publicado_hasta TIMESTAMPTZ;
UPDATE privado.competencia_cortes c SET resultados=coalesce((
 SELECT jsonb_agg(f||jsonb_build_object('rol',u.rol)) FROM jsonb_array_elements(c.resultados) f
 LEFT JOIN public.usuarios u ON u.id_usuario=(f->>'id_usuario')::uuid
),'[]'::jsonb) WHERE c.detalle IS NULL AND NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='019_competencia_resultados');
-- Los cortes anteriores conservan sus totales. No se inventa un desglose histórico.
CREATE TABLE IF NOT EXISTS privado.competencia_periodos(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),id_ciclo UUID NOT NULL REFERENCES public.ciclos,
 nombre TEXT NOT NULL CHECK(length(btrim(nombre)) BETWEEN 1 AND 100),desde DATE NOT NULL,hasta DATE NOT NULL CHECK(hasta>=desde),
 corte UUID UNIQUE REFERENCES privado.competencia_cortes ON DELETE CASCADE,creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE privado.competencia_periodos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.competencia_periodos FROM PUBLIC,anon,authenticated;
ALTER TABLE privado.competencia_criterios ADD COLUMN IF NOT EXISTS solo_conquistadores BOOLEAN NOT NULL DEFAULT false;
UPDATE privado.competencia_criterios SET solo_conquistadores=true WHERE lower(nombre)='cuadernillo';
INSERT INTO privado.competencia_criterios(nombre) SELECT 'Puntualidad' WHERE NOT EXISTS(SELECT 1 FROM privado.competencia_criterios WHERE lower(nombre)='puntualidad');

-- Un estado por defecto no es una falta confirmada: se exige que la unidad haya guardado el pase.
CREATE OR REPLACE FUNCTION privado.competencia_asistencia(p_reunion UUID,p_usuario UUID)
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT CASE WHEN r.estado='cerrada' OR coalesce(g.revisada,false) THEN c.estado ELSE NULL END
 FROM privado.convocados_asistencia c JOIN privado.reuniones r ON r.id=c.reunion
 LEFT JOIN privado.unidades_revisadas g ON g.reunion=c.reunion AND g.clave=coalesce(c.id_unidad::text,'sin-unidad')
 WHERE c.reunion=p_reunion AND c.id_usuario=p_usuario;
$$;
CREATE OR REPLACE FUNCTION privado.competencia_presencial(p_reunion UUID,p_usuario UUID,p_rol TEXT,p_criterio JSONB)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT coalesce(privado.competencia_asistencia(p_reunion,p_usuario),'asistencia')='asistencia'
 AND NOT (p_rol='consejero' AND (coalesce((p_criterio->>'solo_conquistadores')::boolean,false) OR lower(p_criterio->>'nombre')='cuadernillo'));
$$;
CREATE OR REPLACE FUNCTION privado.competencia_auto(p_reunion UUID,p_usuario UUID,p_fuente TEXT,p_justificados BOOLEAN)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;

CREATE OR REPLACE FUNCTION privado.competencia_detalle(p_ciclo UUID,p_desde DATE,p_hasta DATE)
RETURNS TABLE(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT,criterio TEXT,fuente TEXT,criterio_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;
CREATE OR REPLACE FUNCTION privado.competencia_filas(p_ciclo UUID,p_desde DATE,p_hasta DATE)
RETURNS TABLE(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT fecha,id_usuario,id_unidad,nombre,unidad,puntos FROM privado.competencia_detalle(p_ciclo,p_desde,p_hasta);
$$;
CREATE OR REPLACE FUNCTION privado.competencia_ranking(p_ciclo UUID,p_desde DATE,p_hasta DATE,p_admin BOOLEAN)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH filas AS (SELECT * FROM privado.competencia_detalle(p_ciclo,p_desde,p_hasta)),
 individuos AS (SELECT id_usuario,max(nombre) nombre,sum(puntos) puntos FROM filas WHERE id_usuario IS NOT NULL AND rol<>'consejero' GROUP BY id_usuario),
 consejeros AS (SELECT id_usuario,max(nombre) nombre,sum(puntos) puntos FROM filas WHERE id_usuario IS NOT NULL AND rol='consejero' GROUP BY id_usuario),
 unidades AS (SELECT id_unidad,max(unidad) nombre,sum(puntos) puntos FROM filas WHERE id_unidad IS NOT NULL GROUP BY id_unidad),
 destacados AS (SELECT id_usuario,nombre FROM individuos WHERE puntos>0 ORDER BY puntos DESC,id_usuario LIMIT 15)
 SELECT jsonb_build_object(
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u) ORDER BY puntos DESC,nombre,id_unidad) FROM unidades u),'[]'::jsonb),
 'individual',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY puntos DESC,nombre,id_usuario) FROM individuos i),'[]'::jsonb) ELSE '[]'::jsonb END,
 'consejeros',CASE WHEN p_admin THEN coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY puntos DESC,nombre,id_usuario) FROM consejeros i),'[]'::jsonb) ELSE '[]'::jsonb END,
 'destacados',coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY random()) FROM destacados d),'[]'::jsonb));
$$;
CREATE OR REPLACE FUNCTION privado.competencia_estadisticas(p_ciclo UUID,p_desde DATE,p_hasta DATE,p_admin BOOLEAN,p_consejeros BOOLEAN DEFAULT false)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;
CREATE OR REPLACE FUNCTION public.competencia_panel(p_reunion UUID DEFAULT NULL,p_desde DATE DEFAULT NULL,p_hasta DATE DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
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
END $$;

CREATE OR REPLACE FUNCTION public.competencia_guardar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;


CREATE OR REPLACE FUNCTION public.competencia_perfil(p_usuario UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE c privado.competencia_cortes%ROWTYPE;
BEGIN
 IF privado.mi_id() IS NULL OR (NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id()) THEN RAISE EXCEPTION 'Solo puedes consultar tu puntaje.' USING ERRCODE='42501'; END IF;
 SELECT cc.* INTO c FROM privado.competencia_cortes cc JOIN public.ciclos ci ON ci.id_ciclo=cc.id_ciclo WHERE ci.es_activo ORDER BY cc.creado_en DESC,cc.id LIMIT 1;
 IF c.id IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('nombre',c.nombre,'desde',c.desde,'hasta',c.hasta,'puntos',coalesce((SELECT sum(f.puntos) FROM privado.competencia_filas(c.id_ciclo,c.desde,c.hasta) f WHERE f.id_usuario=p_usuario),0));
END $$;
CREATE OR REPLACE FUNCTION public.competencia_publicacion()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 RETURN (SELECT jsonb_build_object('nombre',c.nombre,'desde',c.desde,'hasta',c.hasta,'publicado_hasta',c.publicado_hasta)
 FROM privado.competencia_cortes c JOIN public.ciclos ci ON ci.id_ciclo=c.id_ciclo
 WHERE ci.es_activo AND c.publicado_hasta>now() ORDER BY c.creado_en DESC,c.id LIMIT 1);
END $$;
-- Recupera grupos faltantes, incluido Sin unidad, sin cambiar pases ni historial.
INSERT INTO privado.unidades_revisadas(reunion,clave,nombre)
SELECT DISTINCT c.reunion,coalesce(c.id_unidad::text,'sin-unidad'),c.unidad FROM privado.convocados_asistencia c
ON CONFLICT(reunion,clave) DO NOTHING;
DO $$ DECLARE m RECORD; BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='019_competencia_resultados') THEN
 FOR m IN SELECT u.id_usuario FROM public.usuarios u JOIN public.ciclos c USING(id_ciclo) WHERE c.es_activo AND u.es_activo LOOP
 PERFORM privado.incorporar_integrante_pendientes(m.id_usuario,(now() AT TIME ZONE 'America/Mexico_City')::date);
 END LOOP; END IF;
END $$;

DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.competencia_asistencia(uuid,uuid)','privado.competencia_presencial(uuid,uuid,text,jsonb)','privado.competencia_auto(uuid,uuid,text,boolean)','privado.competencia_detalle(uuid,date,date)','privado.competencia_filas(uuid,date,date)','privado.competencia_ranking(uuid,date,date,boolean)','privado.competencia_estadisticas(uuid,date,date,boolean,boolean)','public.competencia_panel(uuid,date,date)','public.competencia_guardar(uuid,text,jsonb)','public.competencia_perfil(uuid)','public.competencia_publicacion()'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.competencia_panel(uuid,date,date),public.competencia_guardar(uuid,text,jsonb),public.competencia_perfil(uuid),public.competencia_publicacion() TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('019_competencia_resultados') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
