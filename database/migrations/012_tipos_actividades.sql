-- 012_tipos_actividades.sql | Ejecutar después de 011, como postgres.
-- No borra datos. La limpieza opcional está en database/admin/limpiar_actividad.sql.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='011_calendario') THEN
 RAISE EXCEPTION 'Ejecuta primero la migración 011.'; END IF;
END $$;
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS tipo TEXT NOT NULL DEFAULT 'regular'
 CHECK(tipo IN ('regular','practica','parcial','evento'));
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS fecha_fin DATE;
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS destinatario_unidad UUID REFERENCES public.unidades;
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS destinatario_clase UUID REFERENCES public.clases;
ALTER TABLE privado.reuniones ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT false;
UPDATE privado.reuniones SET fecha_fin=fecha WHERE fecha_fin IS NULL;
ALTER TABLE privado.reuniones ALTER COLUMN fecha_fin SET NOT NULL;
-- Valores por defecto para RPC de compatibilidad anteriores a Calendario.
CREATE OR REPLACE FUNCTION privado.actividad_fecha_fin() RETURNS trigger
LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 IF NEW.fecha_fin IS NULL THEN NEW.fecha_fin:=NEW.fecha; END IF; RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS actividad_fecha_fin ON privado.reuniones;
CREATE TRIGGER actividad_fecha_fin BEFORE INSERT ON privado.reuniones
 FOR EACH ROW EXECUTE FUNCTION privado.actividad_fecha_fin();
ALTER TABLE privado.reuniones DROP CONSTRAINT IF EXISTS actividad_formato;
ALTER TABLE privado.reuniones ADD CONSTRAINT actividad_formato CHECK(
 fecha_fin>=fecha AND (tipo='evento' OR fecha_fin=fecha)
 AND (tipo='regular' OR periodo_cuota IS NULL)
 AND (CASE WHEN tipo='parcial' THEN num_nonnulls(destinatario_unidad,destinatario_clase)=1
 ELSE num_nonnulls(destinatario_unidad,destinatario_clase)=0 END));
DROP INDEX IF EXISTS privado.reunion_nombre_dia;
CREATE UNIQUE INDEX reunion_nombre_dia ON privado.reuniones(id_ciclo,fecha,lower(nombre)) WHERE NOT eliminado;
ALTER TABLE privado.cuota_periodos DROP CONSTRAINT IF EXISTS cuota_periodos_id_ciclo_fecha_key;
ALTER TABLE privado.cuota_periodos ADD COLUMN IF NOT EXISTS actividad UUID UNIQUE REFERENCES privado.reuniones;
ALTER TABLE privado.cuota_periodos ADD COLUMN IF NOT EXISTS nombre TEXT NOT NULL DEFAULT 'Cobro anterior';
ALTER TABLE privado.cuota_periodos ADD COLUMN IF NOT EXISTS hora TIME NOT NULL DEFAULT '09:00';
-- Conserva cobros compartidos antiguos, sin generar deudas nuevas al migrar.
UPDATE privado.cuota_periodos p SET actividad=r.id,nombre=r.nombre,hora=r.hora
 FROM privado.reuniones r WHERE p.id=r.periodo_cuota AND p.actividad IS NULL
 AND (SELECT count(*) FROM privado.reuniones otra WHERE otra.periodo_cuota=p.id)=1;
CREATE TABLE IF NOT EXISTS privado.cuota_epoca(
 unica BOOLEAN PRIMARY KEY DEFAULT true CHECK(unica), token UUID NOT NULL DEFAULT gen_random_uuid(),
 exigir BOOLEAN NOT NULL DEFAULT false
);
INSERT INTO privado.cuota_epoca(unica) VALUES(true) ON CONFLICT DO NOTHING;
ALTER TABLE privado.cuota_epoca ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.cuota_epoca FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION privado.cuota_aplicar(p_usuario UUID,p_ciclo UUID,p_periodos UUID[],p_ingreso UUID DEFAULT NULL)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$ DECLARE cargo RECORD; pago RECORD; falta INTEGER; abono INTEGER; BEGIN
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
 'cargos',coalesce((SELECT jsonb_agg(jsonb_build_object('periodo',c.periodo,'id_usuario',c.id_usuario,'importe',c.importe,
 'pagado',coalesce((SELECT sum(a.importe) FROM privado.cuota_aplicaciones a WHERE a.periodo=c.periodo AND a.id_usuario=c.id_usuario),0)))
 FROM privado.cuota_cargos c JOIN privado.cuota_periodos p ON p.id=c.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(c.id_usuario,ciclo)),'[]'::jsonb),
 'ingresos',coalesce((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('registrado_por',coalesce((SELECT u.nombres||' '||u.apellido FROM privado.cuentas_miembros cm JOIN public.usuarios u USING(id_usuario) WHERE cm.auth_id=i.auth_id),'Registro anterior')) ORDER BY i.creado_en DESC)
 FROM privado.cuota_ingresos i WHERE i.id_ciclo=ciclo AND privado.cuota_visible(i.id_usuario,ciclo)),'[]'::jsonb),
 'bitacora',CASE WHEN actor.rol='directiva' THEN coalesce((SELECT jsonb_agg(jsonb_build_object('fecha',o.creado_en,'accion',o.accion,'id_usuario',o.datos->>'id_usuario','motivo',o.datos->>'motivo','autor',coalesce(u.nombres||' '||u.apellido,o.auth_id::text)) ORDER BY o.creado_en DESC) FROM privado.cuota_operaciones o LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=o.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario WHERE o.datos->>'id_ciclo'=ciclo::text),'[]'::jsonb) ELSE '[]'::jsonb END,
 'aplicaciones',coalesce((SELECT jsonb_agg(to_jsonb(a)) FROM privado.cuota_aplicaciones a JOIN privado.cuota_periodos p ON p.id=a.periodo WHERE NOT p.cancelado AND p.id_ciclo=ciclo AND privado.cuota_visible(a.id_usuario,ciclo)),'[]'::jsonb));
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
 IF p_accion='periodo' THEN
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

-- Un período por actividad nueva, sin exclusividad por día ni día de la semana.
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
 UPDATE privado.cuota_periodos SET cancelado=false WHERE id=p.id;
 FOR u IN SELECT id_usuario FROM privado.cuota_cargos WHERE periodo=p.id LOOP
 INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,r.id_ciclo) ON CONFLICT DO NOTHING;
 PERFORM privado.cuota_aplicar(u.id_usuario,r.id_ciclo,ARRAY[p.id]);
 UPDATE privado.cuota_cuentas SET version=version+1 WHERE id_usuario=u.id_usuario AND id_ciclo=r.id_ciclo;
 END LOOP;
 RETURN p.id;
END $$;
DROP FUNCTION IF EXISTS privado.calendario_cobro(uuid,date);

DROP FUNCTION IF EXISTS public.calendario_listar(date,date);
CREATE FUNCTION public.calendario_listar(p_desde DATE,p_hasta DATE)
RETURNS TABLE(id UUID,fecha DATE,hora TEXT,nombre TEXT,estado TEXT,version BIGINT,cobra_cuota BOOLEAN,cobro_compartido BOOLEAN,
 tipo TEXT,fecha_fin DATE,destinatario_unidad UUID,destinatario_clase UUID,destinatario TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
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
$$;
DROP FUNCTION IF EXISTS public.calendario_guardar(uuid,bigint,date,time,text,boolean);
CREATE OR REPLACE FUNCTION public.calendario_guardar(
 p_id UUID,p_version BIGINT,p_fecha DATE,p_hora TIME,p_nombre TEXT,p_cobra BOOLEAN,
 p_tipo TEXT,p_fecha_fin DATE,p_unidad UUID,p_clase UUID)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
$$;
CREATE OR REPLACE FUNCTION public.reunion_panel(p_id UUID)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.reuniones_listar()
RETURNS TABLE(id UUID,fecha DATE,estado TEXT,importada BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT r.id,r.fecha,r.estado,r.importada FROM privado.reuniones r
 WHERE NOT r.eliminado AND r.tipo='regular' AND (privado.es_directiva()
 OR (r.estado<>'anulada' AND EXISTS(SELECT 1 FROM privado.convocados_asistencia c WHERE c.reunion=r.id AND privado.ver_convocado(r.id,c.id_usuario))));
$$;
CREATE OR REPLACE FUNCTION public.calendario_eliminar(p_id UUID,p_version BIGINT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;

DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['privado.actividad_cobro(uuid)','privado.actividad_fecha_fin()',
 'public.calendario_listar(date,date)','public.calendario_guardar(uuid,bigint,date,time,text,boolean,text,date,uuid,uuid)',
 'public.calendario_eliminar(uuid,bigint)'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';
 EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';
 IF f LIKE 'public.%' THEN EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated'; END IF;
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('012_tipos_actividades') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
