-- database/migrations/003_directorio_compartido.sql
-- Ejecutar en SQL Editor de Supabase como postgres, después de la 002.

BEGIN;

SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM privado.migraciones
    WHERE version = '002_login_rls'
  ) THEN
    RAISE EXCEPTION 'Primero ejecuta la migración 002_login_rls.';
  END IF;
END;
$$;

-- La tabla usuarios mantiene su RLS de propietario/directiva.
-- Esta función expone únicamente los campos del directorio.
CREATE OR REPLACE FUNCTION public.directorio_integrantes()
RETURNS TABLE (
  id_usuario UUID,
  nombres TEXT,
  apellido TEXT,
  url_foto TEXT,
  unidad TEXT,
  clase TEXT,
  rol TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    u.url_foto::TEXT,
    un.nombre::TEXT,
    cl.nombre::TEXT,
    CASE
      WHEN (SELECT privado.es_directiva())
        OR u.id_usuario = (SELECT privado.mi_id())
      THEN u.rol::TEXT
      ELSE NULL::TEXT
    END
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE (SELECT privado.mi_id()) IS NOT NULL
    AND u.es_activo = TRUE
    AND (
      u.id_usuario = (SELECT privado.mi_id())
      OR EXISTS (
        SELECT 1
        FROM public.ciclos c
        WHERE c.id_ciclo = u.id_ciclo
          AND c.es_activo = TRUE
      )
    );
$$;

CREATE OR REPLACE FUNCTION public.especialidades_visibles(
  p_id_usuario UUID
)
RETURNS TABLE (
  id_especialidad UUID,
  nombre TEXT,
  url_imagen TEXT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    e.id_especialidad,
    e.nombre::TEXT,
    e.url_imagen::TEXT
  FROM public.conquistador_especialidades ce
  JOIN public.especialidades e
    ON e.id_especialidad = ce.id_especialidad
  WHERE ce.id_usuario = p_id_usuario
    AND EXISTS (
      SELECT 1
      FROM public.directorio_integrantes() d
      WHERE d.id_usuario = p_id_usuario
    );
$$;

ALTER FUNCTION public.directorio_integrantes()
OWNER TO postgres;

ALTER FUNCTION public.especialidades_visibles(UUID)
OWNER TO postgres;

REVOKE ALL ON FUNCTION public.directorio_integrantes()
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.especialidades_visibles(UUID)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.directorio_integrantes()
TO authenticated;

GRANT EXECUTE ON FUNCTION public.especialidades_visibles(UUID)
TO authenticated;

-- Asistencias, cuotas, contactos, salud y vínculos
-- conservan sus permisos anteriores.
INSERT INTO privado.migraciones (version)
VALUES ('003_directorio_compartido')
ON CONFLICT (version) DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;