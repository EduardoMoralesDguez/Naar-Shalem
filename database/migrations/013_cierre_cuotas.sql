-- 013: Cobro por unidad; anticipos disponibles hasta el cierre.
BEGIN;
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='012_tipos_actividades') THEN RAISE EXCEPTION 'Ejecuta primero 012_tipos_actividades.sql'; END IF;
END $$;
ALTER TABLE privado.cuota_cargos ADD COLUMN IF NOT EXISTS cerrado BOOLEAN NOT NULL DEFAULT false;
-- Una sola vez: preservar cobros históricos y liberar anticipos automáticos de hoy/futuros.
-- No elimina ingresos ni modifica su importe. Las versiones invalidan capturas desactualizadas.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='013_cierre_cuotas') THEN
 UPDATE privado.cuota_cargos c SET cerrado=true FROM privado.cuota_periodos p
 WHERE c.periodo=p.id AND (p.legado OR p.fecha<(now() AT TIME ZONE 'America/Mexico_City')::date);
 DELETE FROM privado.cuota_aplicaciones a USING privado.cuota_periodos p,privado.cuota_ingresos i
 WHERE a.periodo=p.id AND a.ingreso=i.id AND NOT p.legado AND p.fecha>=(now() AT TIME ZONE 'America/Mexico_City')::date
 AND (i.fecha<p.fecha OR NOT EXISTS(SELECT 1 FROM privado.cuota_operaciones o WHERE o.id=i.id AND o.accion='pago' AND (o.datos->'periodos') ? p.id::text));
 UPDATE privado.cuota_cuentas SET version=version+1;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.cuotas_panel()
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; BEGIN
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
END $$;
CREATE OR REPLACE FUNCTION public.cuotas_operar(p_operacion UUID,p_accion TEXT,p_datos JSONB)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE actor public.usuarios%ROWTYPE; ciclo UUID; previa privado.cuota_operaciones%ROWTYPE;
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
END $$;
CREATE OR REPLACE FUNCTION privado.actividad_cobro(p_actividad UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;

REVOKE ALL ON FUNCTION public.cuotas_operar(uuid,text,jsonb),public.cuotas_panel() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.cuotas_operar(uuid,text,jsonb),public.cuotas_panel() TO authenticated;
REVOKE ALL ON FUNCTION privado.actividad_cobro(uuid) FROM PUBLIC,anon,authenticated;
INSERT INTO privado.migraciones(version) VALUES('013_cierre_cuotas') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
