-- Consulta por unidad y cierre independiente de puntajes por reunión.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='020_competencia_integrada') THEN
 RAISE EXCEPTION 'Aplica primero 020_competencia_integrada.sql (después de 019).'; END IF;
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='021_cierre_puntajes') THEN
 ALTER FUNCTION public.competencia_panel(uuid,date,date) SET SCHEMA privado;
 ALTER FUNCTION privado.competencia_panel(uuid,date,date) RENAME TO competencia_panel_020;
 ALTER FUNCTION public.competencia_guardar(uuid,text,jsonb) SET SCHEMA privado;
 ALTER FUNCTION privado.competencia_guardar(uuid,text,jsonb) RENAME TO competencia_guardar_020;
 END IF;
END $$;
REVOKE ALL ON FUNCTION privado.competencia_panel_020(uuid,date,date),privado.competencia_guardar_020(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
ALTER TABLE privado.competencia_hojas ADD COLUMN IF NOT EXISTS cerrado BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE privado.competencia_hojas ADD COLUMN IF NOT EXISTS cerrado_en TIMESTAMPTZ;

-- Todos los abiertos, aunque sean futuros, y solo el último cerrado de su unidad.
CREATE OR REPLACE FUNCTION privado.reuniones_unidad_visibles(p_puntajes BOOLEAN)
RETURNS SETOF privado.reuniones LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;
CREATE OR REPLACE FUNCTION privado.ver_convocado(p_reunion UUID,p_usuario UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT EXISTS(SELECT 1 FROM public.usuarios a JOIN privado.convocados_asistencia c ON c.reunion=p_reunion AND c.id_usuario=p_usuario
 WHERE a.id_usuario=privado.mi_id() AND a.es_activo AND
 (a.rol='directiva' OR (EXISTS(SELECT 1 FROM privado.reuniones_unidad_visibles(false) r WHERE r.id=p_reunion)
 AND (a.id_unidad IS NOT NULL AND a.id_unidad=c.id_unidad OR a.id_unidad IS NULL AND a.id_usuario=p_usuario))));
$$;
CREATE OR REPLACE FUNCTION privado.competencia_reuniones_visibles()
RETURNS SETOF privado.reuniones LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM privado.reuniones_unidad_visibles(true);
$$;

CREATE OR REPLACE FUNCTION public.competencia_panel(p_reunion UUID DEFAULT NULL,p_desde DATE DEFAULT NULL,p_hasta DATE DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
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
END $$;
CREATE OR REPLACE FUNCTION public.competencia_guardar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
-- El perfil conserva el acumulado, sin entregar las filas históricas ocultas.
CREATE OR REPLACE FUNCTION public.asistencia_resumen(p_usuario UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE total BIGINT; presentes BIGINT; justificados BIGINT; BEGIN
 IF privado.mi_id() IS NULL OR (NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id()) THEN
 RAISE EXCEPTION 'Solo puedes consultar tu propio progreso.' USING ERRCODE='42501'; END IF;
 SELECT count(*),count(*) FILTER(WHERE a.estado='asistencia'),count(*) FILTER(WHERE a.estado='justificado')
 INTO total,presentes,justificados FROM public.asistencias a JOIN privado.reuniones r ON r.id=a.id_reunion
 JOIN public.ciclos ci ON ci.id_ciclo=r.id_ciclo AND ci.es_activo JOIN public.usuarios u ON u.id_usuario=a.id_usuario
 WHERE a.id_usuario=p_usuario AND u.rol<>'directiva' AND r.estado='cerrada' AND NOT r.eliminado AND r.tipo='regular';
 RETURN jsonb_build_object('asistencias',presentes,'justificados',justificados,'faltas',total-presentes-justificados,'total_registros',total,
 'porcentaje',CASE WHEN total=0 THEN 0 ELSE round(100.0*(presentes+justificados)/total) END);
END $$;
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['public.asistencia_resumen(uuid)','privado.reuniones_unidad_visibles(boolean)','privado.ver_convocado(uuid,uuid)','privado.competencia_reuniones_visibles()','public.competencia_panel(uuid,date,date)','public.competencia_guardar(uuid,text,jsonb)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
 EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
 -- Used by existing row-level security policies.
 GRANT EXECUTE ON FUNCTION privado.ver_convocado(uuid,uuid) TO authenticated;
END $$;
INSERT INTO privado.migraciones(version) VALUES('021_cierre_puntajes') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
