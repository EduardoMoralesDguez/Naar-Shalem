-- OPCIONAL: borra TODOS los pagos, saldos y asistencias de TODOS los ciclos.
-- Conserva integrantes, Auth, unidades, clases, especialidades y calendario.
-- Deja reuniones regulares no anuladas en borrador, con faltas pendientes y
-- unidades sin revisar; conserva sus convocatorias y los cargos de $10 sin pago.
-- Ejecutar como postgres después de 013. Cerrar la app en todos los dispositivos.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='013_cierre_cuotas') THEN RAISE EXCEPTION 'Ejecuta primero 013_cierre_cuotas.sql'; END IF;
END $$;
UPDATE privado.cuota_epoca SET token=gen_random_uuid(),exigir=true;
DELETE FROM privado.cuota_aplicaciones;
DELETE FROM privado.cuota_operaciones;
DO $$ BEGIN
 IF to_regclass('privado.asistencia_operaciones') IS NOT NULL THEN DELETE FROM privado.asistencia_operaciones; END IF;
END $$;
DELETE FROM privado.cuota_ingresos;
DELETE FROM public.cuotas;
UPDATE privado.cuota_cargos SET cerrado=false;
UPDATE privado.cuota_cuentas SET version=version+1;
DELETE FROM privado.historial_asistencias;
DELETE FROM public.asistencias;
DELETE FROM privado.bitacora_reuniones;
UPDATE privado.convocados SET estado='falta',motivo=NULL;
UPDATE privado.unidades_revisadas SET revisada=false;
UPDATE privado.reuniones SET estado=CASE WHEN estado='cerrada' THEN 'borrador' ELSE estado END,version=version+1 WHERE tipo='regular';
COMMIT;
SELECT 'Asistencias guardadas' AS registro,count(*) AS cantidad FROM public.asistencias
UNION ALL SELECT 'Ingresos',count(*) FROM privado.cuota_ingresos
UNION ALL SELECT 'Aplicaciones de dinero',count(*) FROM privado.cuota_aplicaciones
UNION ALL SELECT 'Cuotas antiguas',count(*) FROM public.cuotas;
-- Los pagos offline anteriores se rechazarán al sincronizar. Solo si pertenecen
-- a estas pruebas borradas, descártalos con Resolver registro y Actualizar.
