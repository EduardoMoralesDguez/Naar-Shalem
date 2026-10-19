-- Competencia integrada, lectura por unidad, privacidad financiera y cierres reversibles.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);SELECT pg_advisory_xact_lock(728402);SELECT pg_advisory_xact_lock(728403);SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='019_competencia_resultados') THEN RAISE EXCEPTION 'Ejecuta primero 019_competencia_resultados.sql'; END IF;
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='020_competencia_integrada') THEN
 ALTER FUNCTION public.competencia_panel(uuid,date,date) SET SCHEMA privado;
 ALTER FUNCTION privado.competencia_panel(uuid,date,date) RENAME TO competencia_panel_019;
 ALTER FUNCTION public.competencia_guardar(uuid,text,jsonb) SET SCHEMA privado;
 ALTER FUNCTION privado.competencia_guardar(uuid,text,jsonb) RENAME TO competencia_guardar_019;
 ALTER FUNCTION public.cuotas_panel() SET SCHEMA privado;
 ALTER FUNCTION privado.cuotas_panel() RENAME TO cuotas_panel_019;
 ALTER FUNCTION public.cuotas_resumen(uuid) SET SCHEMA privado;
 ALTER FUNCTION privado.cuotas_resumen(uuid) RENAME TO cuotas_resumen_019;
 END IF;
END $$;
REVOKE ALL ON FUNCTION privado.competencia_panel_019(uuid,date,date),privado.competencia_guardar_019(uuid,text,jsonb),privado.cuotas_panel_019(),privado.cuotas_resumen_019(uuid) FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS privado.competencia_finales(id_ciclo UUID PRIMARY KEY REFERENCES public.ciclos,desde DATE NOT NULL,hasta DATE NOT NULL,detalle JSONB NOT NULL,creado_en TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS privado.competencia_reaperturas(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),id_ciclo UUID NOT NULL REFERENCES public.ciclos,datos JSONB NOT NULL,creado_en TIMESTAMPTZ NOT NULL DEFAULT now());
ALTER TABLE privado.competencia_finales ENABLE ROW LEVEL SECURITY;
ALTER TABLE privado.competencia_reaperturas ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.competencia_finales,privado.competencia_reaperturas FROM PUBLIC,anon,authenticated;
-- Ni las tablas de cuotas antiguas ni las RPC deben revelar acumulados fuera de directiva.
REVOKE ALL ON public.cuotas FROM anon,authenticated;
CREATE OR REPLACE FUNCTION public.cuotas_resumen(p_usuario UUID) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p JSONB; BEGIN
 p:=privado.cuotas_resumen_019(p_usuario);
 RETURN CASE WHEN privado.es_directiva() THEN p ELSE jsonb_build_object('porcentaje',p->'porcentaje') END;
END $$;
CREATE OR REPLACE FUNCTION public.cuotas_panel() RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
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
END $$;
CREATE OR REPLACE FUNCTION privado.competencia_detalle_abierto(p_ciclo UUID,p_desde DATE,p_hasta DATE)
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

CREATE OR REPLACE FUNCTION privado.competencia_detalle(p_ciclo UUID,p_desde DATE,p_hasta DATE)
RETURNS TABLE(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT,criterio TEXT,fuente TEXT,criterio_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM privado.competencia_detalle_abierto(p_ciclo,p_desde,p_hasta) WHERE NOT EXISTS(SELECT 1 FROM privado.competencia_finales WHERE id_ciclo=p_ciclo)
 UNION ALL SELECT f.* FROM privado.competencia_finales c CROSS JOIN LATERAL jsonb_to_recordset(c.detalle) AS f(fecha DATE,id_usuario UUID,id_unidad UUID,nombre TEXT,unidad TEXT,puntos BIGINT,rol TEXT,criterio TEXT,fuente TEXT,criterio_id UUID)
 WHERE c.id_ciclo=p_ciclo AND f.fecha BETWEEN p_desde AND p_hasta;
$$;
CREATE OR REPLACE FUNCTION privado.competencia_ranking(p_ciclo UUID,p_desde DATE,p_hasta DATE,p_admin BOOLEAN)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.competencia_publicacion() RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ciclo UUID; anio INTEGER; f privado.competencia_finales%ROWTYPE; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo,c.anio INTO ciclo,anio FROM public.ciclos c WHERE es_activo;
 SELECT * INTO f FROM privado.competencia_finales WHERE id_ciclo=ciclo;
 IF FOUND THEN RETURN jsonb_build_object('nombre','Ciclo '||anio,'desde',f.desde,'hasta',f.hasta,'anual',true,'publicado_hasta',NULL); END IF;
 RETURN (SELECT jsonb_build_object('nombre',nombre,'desde',desde,'hasta',hasta,'anual',false,'publicado_hasta',publicado_hasta) FROM privado.competencia_cortes WHERE id_ciclo=ciclo AND publicado_hasta>now() ORDER BY creado_en DESC,id LIMIT 1);
END $$;
-- Lectura de la última reunión calificada para esa unidad y posteriores sin calificar.
CREATE OR REPLACE FUNCTION privado.competencia_reuniones_visibles() RETURNS SETOF privado.reuniones LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 WITH actor AS (SELECT * FROM public.usuarios WHERE id_usuario=privado.mi_id()), elegibles AS (
 SELECT r.* FROM privado.reuniones r JOIN public.ciclos ci ON ci.id_ciclo=r.id_ciclo AND ci.es_activo
 WHERE r.tipo='regular' AND NOT r.eliminado AND NOT r.importada AND r.estado<>'anulada'
 AND EXISTS(SELECT 1 FROM privado.convocados_asistencia c,actor a WHERE c.reunion=r.id AND (a.id_unidad IS NOT NULL AND c.id_unidad=a.id_unidad OR a.id_unidad IS NULL AND c.id_usuario=a.id_usuario))
 ), ultima AS (SELECT r.* FROM elegibles r WHERE EXISTS(SELECT 1 FROM privado.competencia_hojas h WHERE h.reunion=r.id) ORDER BY fecha DESC,hora DESC,numero DESC LIMIT 1)
 SELECT r.* FROM elegibles r WHERE r.id=(SELECT id FROM ultima) OR (NOT EXISTS(SELECT 1 FROM privado.competencia_hojas h WHERE h.reunion=r.id) AND (NOT EXISTS(SELECT 1 FROM ultima) OR (r.fecha,r.hora,r.numero)>=(SELECT fecha,hora,numero FROM ultima)));
$$;
CREATE OR REPLACE FUNCTION public.competencia_panel(p_reunion UUID DEFAULT NULL,p_desde DATE DEFAULT NULL,p_hasta DATE DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
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
END $$;

CREATE OR REPLACE FUNCTION public.competencia_guardar(p_operacion UUID,p_accion TEXT,p_datos JSONB) RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
CREATE OR REPLACE FUNCTION public.competencia_perfil(p_usuario UUID) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE pub JSONB; ciclo UUID; c privado.competencia_cortes%ROWTYPE; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 pub:=public.competencia_publicacion();
 IF pub IS NOT NULL THEN RETURN pub||jsonb_build_object('puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,(pub->>'desde')::date,(pub->>'hasta')::date) WHERE id_usuario=p_usuario),0)); END IF;
 IF NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id() THEN RETURN NULL; END IF;
 SELECT * INTO c FROM privado.competencia_cortes WHERE id_ciclo=ciclo ORDER BY creado_en DESC,id LIMIT 1;
 IF c.id IS NULL THEN RETURN NULL; END IF;
 RETURN jsonb_build_object('nombre',c.nombre,'desde',c.desde,'hasta',c.hasta,'puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,c.desde,c.hasta) WHERE id_usuario=p_usuario),0));
END $$;
CREATE OR REPLACE FUNCTION public.competencia_unidad(p_unidad UUID) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE pub JSONB; ciclo UUID; BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.unidades WHERE id_unidad=p_unidad;
 IF NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo) THEN RETURN NULL; END IF;
 pub:=public.competencia_publicacion();
 IF pub IS NULL THEN SELECT jsonb_build_object('nombre',nombre,'desde',desde,'hasta',hasta) INTO pub FROM privado.competencia_cortes WHERE id_ciclo=ciclo ORDER BY creado_en DESC,id LIMIT 1; END IF;
 IF pub IS NULL THEN RETURN NULL; END IF;
 RETURN pub||jsonb_build_object('puntos',coalesce((SELECT sum(puntos) FROM privado.competencia_filas(ciclo,(pub->>'desde')::date,(pub->>'hasta')::date) WHERE id_unidad=p_unidad),0));
END $$;
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['public.cuotas_panel()','public.cuotas_resumen(uuid)','privado.competencia_detalle_abierto(uuid,date,date)','privado.competencia_detalle(uuid,date,date)','privado.competencia_ranking(uuid,date,date,boolean)','privado.competencia_reuniones_visibles()','public.competencia_panel(uuid,date,date)','public.competencia_guardar(uuid,text,jsonb)','public.competencia_perfil(uuid)','public.competencia_unidad(uuid)','public.competencia_publicacion()'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('020_competencia_integrada') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
