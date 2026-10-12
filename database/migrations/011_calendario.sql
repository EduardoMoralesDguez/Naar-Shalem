-- 011_calendario.sql | Ejecutar después de 010, como postgres.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='010_cuotas') THEN
 RAISE EXCEPTION 'Ejecuta primero la migración 010.'; END IF;
END $$;
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS hora TIME NOT NULL DEFAULT '09:00';
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS periodo_cuota UUID REFERENCES privado.cuota_periodos(id);
ALTER TABLE privado.cuota_periodos ADD COLUMN IF NOT EXISTS cancelado BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE privado.cuota_periodos ADD COLUMN IF NOT EXISTS gestionado_calendario BOOLEAN NOT NULL DEFAULT false;
CREATE TABLE IF NOT EXISTS privado.historial_calendario(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), auth_id UUID, accion TEXT NOT NULL,
 datos JSONB NOT NULL, creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE privado.historial_calendario ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.historial_calendario FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION privado.cuota_aplicar(p_usuario UUID,p_ciclo UUID,p_periodos UUID[],p_ingreso UUID DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE cargo RECORD; pago RECORD; falta INTEGER; abono INTEGER; BEGIN
 FOR cargo IN SELECT c.*,p.fecha FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo
 WHERE c.id_usuario=p_usuario AND p.id_ciclo=p_ciclo AND NOT p.cancelado AND c.periodo=ANY(p_periodos) ORDER BY p.fecha,p.id LOOP
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
 'periodos',coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.fecha DESC) FROM privado.cuota_periodos p WHERE NOT p.cancelado AND p.id_ciclo=ciclo),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',u.id_usuario,'nombre',u.nombres||' '||u.apellido,
 'unidad',coalesce(un.nombre,'Sin unidad'),'id_unidad',u.id_unidad,'version',coalesce(c.version,1),
 'saldo',coalesce((SELECT sum(i.importe) FROM privado.cuota_ingresos i WHERE i.id_usuario=u.id_usuario AND i.id_ciclo=ciclo AND NOT i.anulado),0)
 -coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE a.id_usuario=u.id_usuario AND p.id_ciclo=ciclo),0)) ORDER BY u.apellido,u.nombres)
 FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad) LEFT JOIN privado.cuota_cuentas c ON c.id_usuario=u.id_usuario AND c.id_ciclo=ciclo
 WHERE u.id_ciclo=ciclo AND privado.cuota_visible(u.id_usuario,ciclo) AND (u.es_activo OR actor.rol='directiva')),'[]'::jsonb),
 'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('periodo',c.periodo,'id_usuario',c.id_usuario,'importe',c.importe,
 'pagado',coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)))
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(c.id_usuario,ciclo)),'[]'::jsonb),
 'ingresos',coalesce((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('registrado_por',coalesce((SELECT u.nombres||' '||u.apellido FROM privado.cuentas_miembros cm JOIN public.usuarios u USING(id_usuario) WHERE cm.auth_id=i.auth_id),'Registro anterior')) ORDER BY i.creado_en DESC)
 FROM privado.cuota_ingresos i WHERE i.id_ciclo=ciclo AND privado.cuota_visible(i.id_usuario,ciclo)),'[]'::jsonb),
 'bitacora',CASE WHEN actor.rol='directiva' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('fecha',o.creado_en,'accion',o.accion,'id_usuario',o.datos->>'id_usuario','motivo',o.datos->>'motivo','autor',coalesce(u.nombres||' '||u.apellido,o.auth_id::text)) ORDER BY o.creado_en DESC) FROM privado.cuota_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END,
 'aplicaciones',coalesce((SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(a.id_usuario,ciclo)),'[]'::jsonb));
END $$;

CREATE OR REPLACE FUNCTION public.cuotas_resumen(p_usuario UUID)
RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $$ DECLARE ciclo UUID; total INTEGER; pagadas INTEGER; dinero BIGINT; BEGIN
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 IF NOT privado.es_directiva() AND p_usuario IS DISTINCT FROM privado.mi_id() THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 IF NOT privado.cuota_visible(p_usuario,ciclo) THEN RAISE EXCEPTION 'No autorizado.' USING ERRCODE='42501'; END IF;
 SELECT count(*),count(*) FILTER(WHERE c.importe<=coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)) INTO total,pagadas
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=p_usuario AND p.id_ciclo=ciclo AND NOT p.cancelado AND p.fecha<=(now() AT TIME ZONE 'America/Mexico_City')::date;
 SELECT coalesce(sum(importe),0) INTO dinero FROM privado.cuota_ingresos WHERE id_usuario=p_usuario AND id_ciclo=ciclo AND NOT anulado;
 RETURN jsonb_build_object('total_pagado',dinero/100.0,'semanas_pagadas',pagadas,'semanas_registradas',total,'porcentaje',CASE WHEN total=0 THEN 0 ELSE round(100.0*pagadas/total) END);
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
 IF EXISTS(SELECT 1 FROM unnest(periodos) x WHERE NOT EXISTS(SELECT 1 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE c.id_usuario=u.id_usuario AND p.id_ciclo=ciclo AND NOT p.cancelado AND c.periodo=x)) THEN
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

-- Activa un cobro compartido. Solo los períodos creados desde calendario
-- se cancelan automáticamente; los anteriores conservan su administración.
CREATE OR REPLACE FUNCTION privado.calendario_cobro(p_ciclo UUID,p_fecha DATE)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE periodo privado.cuota_periodos%ROWTYPE; c RECORD; BEGIN
 SELECT * INTO periodo FROM privado.cuota_periodos WHERE id_ciclo=p_ciclo AND fecha=p_fecha;
 IF periodo.id IS NULL THEN
 PERFORM public.cuotas_operar(gen_random_uuid(),'periodo',jsonb_build_object('id_ciclo',p_ciclo,'fecha',p_fecha));
 UPDATE privado.cuota_periodos SET gestionado_calendario=true WHERE id_ciclo=p_ciclo AND fecha=p_fecha RETURNING * INTO periodo;
 ELSIF periodo.cancelado THEN
 UPDATE privado.cuota_periodos SET cancelado=false WHERE id=periodo.id;
 FOR c IN SELECT id_usuario FROM privado.cuota_cargos WHERE cuota_cargos.periodo=periodo.id LOOP
 PERFORM privado.cuota_aplicar(c.id_usuario,p_ciclo,ARRAY[periodo.id]);
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=c.id_usuario AND id_ciclo=p_ciclo;
 END LOOP;
 END IF;
 RETURN periodo.id;
END $$;

CREATE OR REPLACE FUNCTION privado.calendario_liberar_cobro(p_periodo UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE p privado.cuota_periodos%ROWTYPE; BEGIN
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
END $$;

CREATE OR REPLACE FUNCTION public.calendario_listar(p_desde DATE,p_hasta DATE)
RETURNS TABLE(id UUID,fecha DATE,hora TEXT,nombre TEXT,estado TEXT,version BIGINT,cobra_cuota BOOLEAN,cobro_compartido BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
 SELECT r.id,r.fecha,to_char(r.hora,'HH24:MI'),r.nombre,r.estado,r.version,r.periodo_cuota IS NOT NULL,
 EXISTS(SELECT 1 FROM privado.reuniones otra WHERE otra.id<>r.id AND otra.periodo_cuota=r.periodo_cuota AND otra.estado<>'anulada')
 FROM privado.reuniones r JOIN public.ciclos c ON c.id_ciclo=r.id_ciclo
 WHERE privado.mi_id() IS NOT NULL AND c.es_activo AND r.fecha BETWEEN p_desde AND p_hasta
 AND p_hasta-p_desde BETWEEN 0 AND 366 ORDER BY r.fecha,r.hora,r.numero;
$$;

CREATE OR REPLACE FUNCTION public.calendario_guardar(p_id UUID,p_version BIGINT,p_fecha DATE,p_hora TIME,p_nombre TEXT,p_cobra BOOLEAN)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE r privado.reuniones%ROWTYPE; ciclo UUID; nombre_limpio TEXT; cobro UUID; anterior JSONB; miembro RECORD; BEGIN
 PERFORM pg_advisory_xact_lock(728401); PERFORM pg_advisory_xact_lock(728402);
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva organiza actividades.' USING ERRCODE='42501'; END IF;
 IF (SELECT count(*) FROM public.ciclos WHERE es_activo)<>1 THEN RAISE EXCEPTION 'Debe existir un ciclo activo.'; END IF;
 SELECT id_ciclo INTO ciclo FROM public.ciclos WHERE es_activo;
 nombre_limpio:=btrim(regexp_replace(p_nombre,'\s+',' ','g'));
 IF p_id IS NULL OR nombre_limpio IS NULL OR length(nombre_limpio) NOT BETWEEN 1 AND 60 OR p_hora IS NULL OR p_fecha IS NULL OR p_cobra IS NULL
 OR extract(year FROM p_fecha)<>(SELECT anio FROM public.ciclos WHERE id_ciclo=ciclo) THEN
 RAISE EXCEPTION 'Indica nombre, fecha del ciclo activo y hora.' USING ERRCODE='22023'; END IF;
 IF p_cobra AND extract(dow FROM p_fecha)<>0 THEN RAISE EXCEPTION 'La cuota semanal solo se cobra en domingo.' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM privado.reuniones WHERE id=p_id FOR UPDATE;
 IF p_version IS NULL THEN
 IF r.id IS NOT NULL THEN
 IF r.id_ciclo=ciclo AND r.nombre=nombre_limpio AND r.fecha=p_fecha AND r.hora=p_hora AND (r.periodo_cuota IS NOT NULL)=p_cobra AND r.estado<>'anulada' THEN RETURN r.id; END IF;
 RAISE EXCEPTION 'Este intento ya creó una actividad. Recarga el calendario.' USING ERRCODE='40001'; END IF;
 IF p_fecha<(now() AT TIME ZONE 'America/Mexico_City')::date THEN RAISE EXCEPTION 'Crea actividades de hoy o futuras.' USING ERRCODE='22023'; END IF;
 ELSE
 IF r.id IS NULL OR r.id_ciclo<>ciclo OR r.version<>p_version OR r.estado='anulada' THEN
 RAISE EXCEPTION 'La actividad cambió o está cancelada. Recarga antes de editar.' USING ERRCODE='40001'; END IF;
 IF r.fecha<>p_fecha AND (r.estado<>'borrador' OR r.fecha<(now() AT TIME ZONE 'America/Mexico_City')::date
 OR p_fecha<(now() AT TIME ZONE 'America/Mexico_City')::date OR EXISTS(SELECT 1 FROM privado.unidades_revisadas WHERE reunion=p_id AND revisada)
 OR EXISTS(SELECT 1 FROM privado.convocados WHERE reunion=p_id AND estado<>'falta')) THEN
 RAISE EXCEPTION 'No se puede mover una actividad con asistencia registrada o pasada. Cancélala y crea otra si corresponde.' USING ERRCODE='22023'; END IF;
 anterior:=to_jsonb(r);
 END IF;
 IF EXISTS(SELECT 1 FROM privado.reuniones WHERE id<>p_id AND id_ciclo=ciclo AND fecha=p_fecha AND lower(nombre)=lower(nombre_limpio)) THEN
 RAISE EXCEPTION 'Ya existe una actividad con ese nombre en la fecha. Usa un nombre distinto.' USING ERRCODE='23505'; END IF;
 IF p_cobra THEN cobro:=privado.calendario_cobro(ciclo,p_fecha); END IF;
 IF p_version IS NULL THEN
 INSERT INTO privado.reuniones(id,id_ciclo,fecha,hora,nombre,numero,periodo_cuota)
 SELECT p_id,ciclo,p_fecha,p_hora,nombre_limpio,coalesce(max(numero),0)+1,cobro FROM privado.reuniones WHERE id_ciclo=ciclo AND fecha=p_fecha;
 INSERT INTO privado.convocados(reunion,id_usuario,id_unidad,unidad)
 SELECT p_id,u.id_usuario,u.id_unidad,coalesce(un.nombre,'Sin unidad') FROM public.usuarios u LEFT JOIN public.unidades un USING(id_unidad)
 WHERE u.es_activo AND u.id_ciclo=ciclo AND u.rol<>'directiva';
 INSERT INTO privado.unidades_revisadas(reunion,clave,nombre)
 SELECT DISTINCT p_id,coalesce(id_unidad::text,'sin-unidad'),unidad FROM privado.convocados WHERE reunion=p_id;
 ELSE
 UPDATE privado.reuniones SET fecha=p_fecha,hora=p_hora,nombre=nombre_limpio,periodo_cuota=cobro,version=version+1,
 numero=CASE WHEN fecha<>p_fecha THEN (SELECT coalesce(max(n.numero),0)+1 FROM privado.reuniones n WHERE n.id_ciclo=ciclo AND n.fecha=p_fecha) ELSE numero END WHERE id=p_id;
 IF r.periodo_cuota IS DISTINCT FROM cobro THEN
 PERFORM privado.calendario_liberar_cobro(r.periodo_cuota);
 IF cobro IS NOT NULL THEN
 FOR miembro IN SELECT id_usuario FROM privado.cuota_cargos WHERE periodo=cobro LOOP
 PERFORM privado.cuota_aplicar(miembro.id_usuario,ciclo,ARRAY[cobro]);
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=miembro.id_usuario AND id_ciclo=ciclo;
 END LOOP;
 END IF;
 END IF;
 END IF;
 INSERT INTO privado.historial_calendario(auth_id,accion,datos) VALUES(auth.uid(),CASE WHEN p_version IS NULL THEN 'crear' ELSE 'editar' END,
 jsonb_build_object('actividad',p_id,'anterior',anterior,'fecha',p_fecha,'hora',p_hora,'nombre',nombre_limpio,'periodo_cuota',cobro));
 RETURN p_id;
END $$;

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
    PERFORM privado.calendario_liberar_cobro(r.periodo_cuota);

  ELSIF p_accion = 'restaurar' AND r.estado = 'anulada' THEN
    UPDATE privado.reuniones
    SET estado = 'borrador'
    WHERE id = p_id;

    IF r.periodo_cuota IS NOT NULL THEN PERFORM privado.calendario_cobro(r.id_ciclo,r.fecha); END IF;
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

CREATE OR REPLACE FUNCTION public.calendario_cancelar(p_id UUID,p_version BIGINT,p_motivo TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva cancela actividades.' USING ERRCODE='42501'; END IF;
 PERFORM public.reunion_accion(p_id,p_version,'anular',jsonb_build_object('motivo',p_motivo));
END $$;
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.calendario_cobro(uuid,date)','privado.calendario_liberar_cobro(uuid)',
 'public.calendario_listar(date,date)','public.calendario_guardar(uuid,bigint,date,time,text,boolean)','public.calendario_cancelar(uuid,bigint,text)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
 EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('011_calendario') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
