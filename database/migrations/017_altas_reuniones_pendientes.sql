-- Altas posteriores a la programación. Ejecutar después de 016.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='016_asistencias_offline_colores') THEN
 RAISE EXCEPTION 'Ejecuta primero 016_asistencias_offline_colores.sql'; END IF;
END $$;

-- Solo completa faltantes: nunca mueve convocatorias, cambia marcas ni aplica saldos.
CREATE OR REPLACE FUNCTION privado.incorporar_integrante_pendientes(p_usuario UUID,p_desde DATE)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE u public.usuarios%ROWTYPE; r RECORD; nombre_unidad TEXT; filas INTEGER;
BEGIN
 PERFORM pg_advisory_xact_lock(728401);
 PERFORM pg_advisory_xact_lock(728402);
 PERFORM pg_advisory_xact_lock(728403);
 SELECT * INTO u FROM public.usuarios WHERE id_usuario=p_usuario;
 IF u.id_usuario IS NULL OR NOT u.es_activo OR u.rol='directiva'
 OR NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=u.id_ciclo AND es_activo) THEN RETURN; END IF;
 SELECT coalesce((SELECT nombre FROM public.unidades WHERE id_unidad=u.id_unidad),'Sin unidad') INTO nombre_unidad;
 FOR r IN SELECT * FROM privado.reuniones
 WHERE id_ciclo=u.id_ciclo AND fecha>=p_desde AND tipo='regular'
 AND NOT eliminado AND NOT importada AND estado<>'anulada' ORDER BY fecha,id LOOP
  IF r.estado='borrador' THEN
   INSERT INTO privado.convocados(reunion,id_usuario,id_unidad,unidad)
   VALUES(r.id,u.id_usuario,u.id_unidad,nombre_unidad) ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS filas=ROW_COUNT;
   IF filas>0 THEN
    INSERT INTO privado.unidades_revisadas(reunion,clave,nombre,revisada)
    VALUES(r.id,coalesce(u.id_unidad::text,'sin-unidad'),nombre_unidad,false)
    ON CONFLICT(reunion,clave) DO UPDATE SET revisada=false;
    UPDATE privado.reuniones SET version=version+1 WHERE id=r.id;
    INSERT INTO privado.bitacora_reuniones(reunion,auth_id,accion,datos)
    VALUES(r.id,auth.uid(),'incorporar',jsonb_build_object('id_usuario',u.id_usuario,'motivo','Alta en reunión pendiente'));
   END IF;
  END IF;
  -- El cierre de cuotas es independiente del pase de asistencia y se realiza por unidad.
  IF u.rol IN ('conquistador','capitan','subcapitan') AND EXISTS(
   SELECT 1 FROM privado.cuota_periodos p WHERE p.id=r.periodo_cuota AND p.actividad=r.id
   AND NOT p.cancelado AND NOT p.legado
  ) AND NOT EXISTS(
   SELECT 1 FROM privado.cuota_cargos c WHERE c.periodo=r.periodo_cuota
   AND c.id_unidad IS NOT DISTINCT FROM u.id_unidad AND c.cerrado
  ) THEN
   INSERT INTO privado.cuota_cargos(periodo,id_usuario,id_unidad,importe)
   VALUES(r.periodo_cuota,u.id_usuario,u.id_unidad,1000) ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS filas=ROW_COUNT;
   IF filas>0 THEN
    INSERT INTO privado.cuota_cuentas(id_usuario,id_ciclo) VALUES(u.id_usuario,u.id_ciclo)
    ON CONFLICT(id_usuario,id_ciclo) DO UPDATE SET version=privado.cuota_cuentas.version+1;
   END IF;
  END IF;
 END LOOP;
END $$;

-- Tomar los bloqueos antes de validar_inscripcion (que toma 728403).
CREATE OR REPLACE FUNCTION privado.bloquear_alta_reuniones() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(728401);PERFORM pg_advisory_xact_lock(728402);PERFORM pg_advisory_xact_lock(728403);
 RETURN NEW;
END $$;
CREATE OR REPLACE FUNCTION privado.incorporar_alta_reuniones() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM privado.incorporar_integrante_pendientes(NEW.id_usuario,(now() AT TIME ZONE 'America/Mexico_City')::date);
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS alta_bloquear_reuniones ON public.usuarios;
CREATE TRIGGER alta_bloquear_reuniones BEFORE INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION privado.bloquear_alta_reuniones();
DROP TRIGGER IF EXISTS alta_incorporar_reuniones ON public.usuarios;
CREATE TRIGGER alta_incorporar_reuniones AFTER INSERT ON public.usuarios FOR EACH ROW EXECUTE FUNCTION privado.incorporar_alta_reuniones();
REVOKE ALL ON FUNCTION privado.incorporar_integrante_pendientes(uuid,date),privado.bloquear_alta_reuniones(),privado.incorporar_alta_reuniones() FROM PUBLIC,anon,authenticated;

-- Reparación inicial, una sola vez. No se deducen fechas históricas de ingreso:
-- se completan únicamente actividades de hoy en adelante para miembros activos.
DO $$ DECLARE miembro RECORD; BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='017_altas_reuniones_pendientes') THEN
  FOR miembro IN SELECT u.id_usuario FROM public.usuarios u JOIN public.ciclos c USING(id_ciclo) WHERE c.es_activo AND u.es_activo LOOP
   PERFORM privado.incorporar_integrante_pendientes(miembro.id_usuario,(now() AT TIME ZONE 'America/Mexico_City')::date);
  END LOOP;
 END IF;
END $$;
INSERT INTO privado.migraciones(version) VALUES('017_altas_reuniones_pendientes') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
