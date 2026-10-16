-- limpiar_actividad.sql
-- OPCIONAL Y DESTRUCTIVO: borra actividades, asistencias, cuotas, ingresos,
-- saldos y sus bitácoras de TODOS los ciclos. No borra integrantes, cuentas,
-- datos privados, unidades, clases, insignias ni migraciones.
-- Ejecutar como postgres después de 012_tipos_actividades.sql.
-- Cierra la app en todos los dispositivos mientras lo ejecutas.
BEGIN;
SET LOCAL lock_timeout='5s';
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='012_tipos_actividades') THEN
 RAISE EXCEPTION 'Ejecuta primero 012_tipos_actividades.sql.'; END IF;
END $$;
-- Impide que los pagos offline anteriores vuelvan a entrar tras la limpieza.
UPDATE privado.cuota_epoca SET token=gen_random_uuid(),exigir=true;
DELETE FROM privado.cuota_aplicaciones;
DELETE FROM privado.cuota_operaciones;
DO $$ BEGIN
 IF to_regclass('privado.asistencia_operaciones') IS NOT NULL THEN DELETE FROM privado.asistencia_operaciones; END IF;
END $$;
DELETE FROM privado.cuota_ingresos;
DELETE FROM privado.cuota_cargos;
DELETE FROM privado.cuota_cuentas;
UPDATE privado.reuniones SET periodo_cuota=NULL;
DELETE FROM privado.cuota_periodos;
DELETE FROM public.cuotas;
DELETE FROM privado.historial_asistencias;
DELETE FROM public.asistencias;
DELETE FROM privado.bitacora_reuniones;
DELETE FROM privado.unidades_revisadas;
DELETE FROM privado.convocados;
DELETE FROM privado.historial_calendario;
DELETE FROM privado.reuniones;
COMMIT;
SELECT 'Actividades' AS registro,count(*) AS cantidad FROM privado.reuniones
UNION ALL SELECT 'Asistencias',count(*) FROM public.asistencias
UNION ALL SELECT 'Cobros',count(*) FROM privado.cuota_periodos
UNION ALL SELECT 'Ingresos',count(*) FROM privado.cuota_ingresos
UNION ALL SELECT 'Cuotas anteriores',count(*) FROM public.cuotas;
-- Al abrir la versión nueva de la app, actualiza Cuotas con conexión.
-- Los pendientes de antes de esta limpieza darán conflicto: descártalos con
-- Resolver registro si pertenecen a estas pruebas borradas. No se reenvían.
