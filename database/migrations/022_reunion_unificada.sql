BEGIN;
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='021_cierre_puntajes') THEN RAISE EXCEPTION 'Aplica primero 021_cierre_puntajes.sql'; END IF;
END $$;
ALTER TABLE privado.competencia_hojas ADD COLUMN IF NOT EXISTS unidades_guardadas TEXT[] NOT NULL DEFAULT '{}';
CREATE OR REPLACE FUNCTION public.reunion_integrada_panel(p_reunion UUID DEFAULT NULL,p_desde DATE DEFAULT NULL,p_hasta DATE DEFAULT NULL)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p JSONB; BEGIN
 p:=public.competencia_panel(p_reunion,p_desde,p_hasta)||jsonb_build_object('api_version',22);
 IF p_reunion IS NOT NULL THEN p:=jsonb_set(p,'{captura,unidades_guardadas}',to_jsonb(coalesce((SELECT unidades_guardadas FROM privado.competencia_hojas WHERE reunion=p_reunion),'{}'::text[])));END IF;
 IF p_reunion IS NOT NULL AND privado.es_directiva() THEN
 p:=p||jsonb_build_object('periodo_cuota',(SELECT periodo_cuota FROM privado.reuniones WHERE id=p_reunion),'pase',public.reunion_panel(p_reunion),'finanzas',public.cuotas_panel(),'epoca',(SELECT token FROM privado.cuota_epoca));
 END IF;
 RETURN p;
END $$;
CREATE OR REPLACE FUNCTION public.reunion_integrada_guardar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
REVOKE ALL ON FUNCTION public.reunion_integrada_panel(uuid,date,date),public.reunion_integrada_guardar(uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reunion_integrada_panel(uuid,date,date),public.reunion_integrada_guardar(uuid,text,jsonb) TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('022_reunion_unificada') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
