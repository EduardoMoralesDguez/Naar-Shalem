BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='015_perfiles_unidades') THEN RAISE EXCEPTION 'Ejecuta primero 015_perfiles_unidades.sql'; END IF;
END $$;
UPDATE public.clases SET color_distintivo=CASE lower(btrim(color_distintivo))
 WHEN 'azul' THEN '#2454c6' WHEN 'rojo' THEN '#c92a36' WHEN 'verde' THEN '#23854a' WHEN 'amarillo' THEN '#c28a00' WHEN 'gris' THEN '#687080' WHEN 'vino' THEN '#802848'
 ELSE CASE WHEN color_distintivo ~ '^#[0-9A-Fa-f]{6}$' THEN lower(color_distintivo) ELSE '#302ca0' END END
 WHERE color_distintivo IS NULL OR color_distintivo !~ '^#[0-9A-Fa-f]{6}$';
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='clase_color_hex') THEN
 ALTER TABLE public.clases ADD CONSTRAINT clase_color_hex CHECK(color_distintivo ~ '^#[0-9A-Fa-f]{6}$' AND color_distintivo IS NOT NULL);
END IF;END $$;
CREATE OR REPLACE FUNCTION public.colores_integrantes() RETURNS TABLE(id_usuario UUID,color_clase TEXT)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT u.id_usuario,c.color_distintivo::text FROM public.usuarios u LEFT JOIN public.clases c USING(id_clase)
 WHERE privado.mi_id() IS NOT NULL AND (u.es_activo OR privado.es_directiva());
$$;
CREATE TABLE IF NOT EXISTS privado.asistencia_operaciones(
 id UUID PRIMARY KEY,auth_id UUID NOT NULL,reunion UUID NOT NULL,version BIGINT NOT NULL,accion TEXT NOT NULL,datos JSONB NOT NULL,epoca UUID NOT NULL,creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE privado.asistencia_operaciones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON privado.asistencia_operaciones FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION public.asistencias_contexto() RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF privado.mi_id() IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('epoca',(SELECT token FROM privado.cuota_epoca),'ciclo',(SELECT id_ciclo FROM public.ciclos WHERE es_activo));
END $$;
CREATE OR REPLACE FUNCTION public.asistencia_operar(p_operacion UUID,p_epoca UUID,p_id UUID,p_version BIGINT,p_accion TEXT,p_datos JSONB DEFAULT '{}')
 RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
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
END $$;
CREATE OR REPLACE FUNCTION public.asistencias_bitacora() RETURNS TABLE(id UUID,fecha TIMESTAMPTZ,autor TEXT,reunion TEXT,accion TEXT,datos JSONB)
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NOT privado.es_directiva() THEN RAISE EXCEPTION 'Solo directiva consulta la bitácora.' USING ERRCODE='42501'; END IF;
 RETURN QUERY SELECT b.id,b.fecha,coalesce(u.nombres||' '||u.apellido,'Registro anterior'),r.fecha::text||' · '||r.nombre,b.accion,b.datos
 FROM privado.bitacora_reuniones b JOIN privado.reuniones r ON r.id=b.reunion JOIN public.ciclos c USING(id_ciclo)
 LEFT JOIN privado.cuentas_miembros cm ON cm.auth_id=b.auth_id LEFT JOIN public.usuarios u ON u.id_usuario=cm.id_usuario
 WHERE c.es_activo ORDER BY b.fecha DESC,b.id;
END $$;
DO $$ DECLARE f TEXT; BEGIN
 FOREACH f IN ARRAY ARRAY['public.colores_integrantes()','public.asistencias_contexto()','public.asistencia_operar(uuid,uuid,uuid,bigint,text,jsonb)','public.asistencias_bitacora()'] LOOP
 EXECUTE 'ALTER FUNCTION '||f||' OWNER TO postgres';EXECUTE 'REVOKE ALL ON FUNCTION '||f||' FROM PUBLIC,anon,authenticated';EXECUTE 'GRANT EXECUTE ON FUNCTION '||f||' TO authenticated';
 END LOOP;
END $$;
INSERT INTO privado.migraciones(version) VALUES('016_asistencias_offline_colores') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
