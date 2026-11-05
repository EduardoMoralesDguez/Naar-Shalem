-- Unifica el cargo actual. Los snapshots/bitácoras históricos no se reescriben.
BEGIN;
SELECT pg_advisory_xact_lock(728401);
SELECT pg_advisory_xact_lock(728402);
SELECT pg_advisory_xact_lock(728403);
SELECT pg_advisory_xact_lock(728404);
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='023_captura_capitan') THEN
 RAISE EXCEPTION 'Aplica primero 023_captura_capitan.sql'; END IF;
END $$;
DROP INDEX IF EXISTS privado.un_cargo_por_unidad;
CREATE OR REPLACE FUNCTION privado.validar_inscripcion() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM pg_advisory_xact_lock(728403);
 IF NEW.id_unidad IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.unidades WHERE id_unidad=NEW.id_unidad AND id_ciclo=NEW.id_ciclo AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una unidad activa del ciclo actual.' USING ERRCODE='22023'; END IF;
 IF NEW.id_clase IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.clases WHERE id_clase=NEW.id_clase AND es_activa) THEN
 RAISE EXCEPTION 'Selecciona una clase activa.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol='capitan' AND NEW.id_unidad IS NULL THEN
 RAISE EXCEPTION 'Asigna una unidad al capitán.' USING ERRCODE='22023'; END IF;
 IF NEW.es_activo AND NEW.rol='capitan' AND (SELECT count(*) FROM privado.inscripciones i WHERE i.id_ciclo=NEW.id_ciclo AND i.id_unidad=NEW.id_unidad AND i.rol='capitan' AND i.activo AND i.id_usuario<>NEW.id_usuario)>=2 THEN
 RAISE EXCEPTION 'La unidad ya tiene dos capitanes. Revoca un cargo antes de nombrar otro.' USING ERRCODE='23505'; END IF;
 RETURN NEW;
END $$;
-- La cuenta, UUID, fotos, puntos y pagos permanecen. El trigger actualiza la inscripción vigente.
UPDATE public.usuarios SET rol='capitan' WHERE rol='subcapitan';
ALTER TABLE public.usuarios DROP CONSTRAINT IF EXISTS usuarios_rol_check;
ALTER TABLE public.usuarios ADD CONSTRAINT usuarios_rol_check CHECK(rol IN ('directiva','consejero','capitan','conquistador'));
CREATE INDEX IF NOT EXISTS capitanes_por_unidad ON privado.inscripciones(id_ciclo,id_unidad) WHERE activo AND rol='capitan';

-- El cliente enlaza archivos estáticos de GitHub/publicación, sin enviar tokens al navegador.
DO $$ BEGIN
 IF to_regprocedure('public.organizacion_guardar_023(text,jsonb)') IS NULL THEN
 ALTER FUNCTION public.organizacion_guardar(text,jsonb) RENAME TO organizacion_guardar_023;
 END IF;
END $$;
CREATE OR REPLACE FUNCTION public.organizacion_guardar(p_accion text,p_datos jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE foto text:=nullif(btrim(p_datos->>'url_foto'),''); BEGIN
 IF p_accion IN ('unidad','identidad') AND p_datos ? 'url_foto' THEN
 IF foto IS NOT NULL AND (length(foto)>500 OR foto !~ '^img/unidades/[A-Za-z0-9_-]+\.(webp|png|jpg|jpeg)$') THEN
 RAISE EXCEPTION 'La foto debe ser una ruta img/unidades/archivo.webp, png o jpg.' USING ERRCODE='22023'; END IF;
 END IF;
 -- Conserva validación de rol/unidad, ciclo, versión, bitácora y campos de identidad.
 PERFORM public.organizacion_guardar_023(p_accion,p_datos);
 IF p_accion IN ('unidad','identidad') AND p_datos ? 'url_foto' THEN
 UPDATE public.unidades SET url_foto=foto,foto_path=NULL WHERE id_unidad=(p_datos->>'id')::uuid;
 END IF;
END $$;
REVOKE ALL ON FUNCTION public.organizacion_guardar(text,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organizacion_guardar(text,jsonb) TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('024_capitanes_fotos') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
