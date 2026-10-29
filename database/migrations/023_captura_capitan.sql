BEGIN;
DO $$ BEGIN IF to_regprocedure('public.reunion_integrada_panel_022(uuid,date,date)') IS NULL THEN
ALTER FUNCTION public.reunion_integrada_panel(uuid,date,date) RENAME TO reunion_integrada_panel_022;
ALTER FUNCTION public.reunion_integrada_guardar(uuid,text,jsonb) RENAME TO reunion_integrada_guardar_022;
END IF; END $$;
CREATE OR REPLACE FUNCTION public.reunion_integrada_panel(p_reunion uuid DEFAULT NULL,p_desde date DEFAULT NULL,p_hasta date DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE p jsonb; f jsonb; u public.usuarios%ROWTYPE; r privado.reuniones%ROWTYPE; BEGIN
p:=public.reunion_integrada_panel_022(p_reunion,p_desde,p_hasta);
SELECT * INTO u FROM public.usuarios WHERE id_usuario=privado.mi_id();
SELECT * INTO r FROM privado.reuniones WHERE id=p_reunion;
IF u.rol='capitan' AND u.id_unidad IS NOT NULL AND r.id_ciclo=u.id_ciclo AND NOT r.eliminado AND r.estado<>'anulada' AND EXISTS(SELECT 1 FROM jsonb_array_elements(p->'captura'->'integrantes') x WHERE x->>'id_unidad'=u.id_unidad::text) THEN
p:=jsonb_set(p,'{captura,version_reunion}',to_jsonb(r.version));
f:=public.cuotas_panel();
p:=p||jsonb_build_object('capitan_captura',r.fecha=(now() AT TIME ZONE 'America/Mexico_City')::date AND NOT coalesce((p->'captura'->>'puntaje_cerrado')::boolean,false),'capitan_justifica',r.fecha=(now() AT TIME ZONE 'America/Mexico_City')::date,'periodo_cuota',r.periodo_cuota,'epoca',(SELECT token FROM privado.cuota_epoca),'finanzas',jsonb_build_object('periodos',coalesce((SELECT jsonb_agg(x) FROM jsonb_array_elements(f->'periodos') x WHERE x->>'id'=r.periodo_cuota::text),'[]'),'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',x->'id_usuario','periodo',x->'periodo','pagado',x->'pagado')) FROM jsonb_array_elements(f->'cargos') x WHERE x->>'periodo'=r.periodo_cuota::text),'[]'),'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',x->'id_usuario','version',x->'version')) FROM jsonb_array_elements(f->'integrantes') x),'[]')));
END IF;RETURN p;END $$;
CREATE OR REPLACE FUNCTION public.reunion_integrada_guardar(p_operacion uuid,p_accion text,p_datos jsonb) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
REVOKE ALL ON FUNCTION public.reunion_integrada_panel(uuid,date,date),public.reunion_integrada_guardar(uuid,text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.reunion_integrada_panel(uuid,date,date),public.reunion_integrada_guardar(uuid,text,jsonb) TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('023_captura_capitan') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
