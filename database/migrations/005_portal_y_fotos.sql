-- database/migrations/005_portal_y_fotos.sql

BEGIN;
SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM privado.migraciones
    WHERE version = '004_administrar_integrantes'
  ) THEN
    RAISE EXCEPTION 'Primero ejecuta la migración 004.';
  END IF;
END;
$$;

ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS foto_path TEXT;

ALTER TABLE privado.historial_perfiles
  DROP CONSTRAINT IF EXISTS historial_perfiles_accion_check;

ALTER TABLE privado.historial_perfiles
  ADD CONSTRAINT historial_perfiles_accion_check
  CHECK (accion IN ('crear', 'editar', 'activar', 'desactivar'));

CREATE OR REPLACE FUNCTION public.directorio_portal()
RETURNS TABLE (
  id_usuario UUID,
  nombres TEXT,
  apellido TEXT,
  rol TEXT,
  unidad TEXT,
  clase TEXT,
  url_foto TEXT,
  foto_path TEXT,
  es_activo BOOLEAN
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
    CASE
      WHEN privado.es_directiva()
        OR u.id_usuario = privado.mi_id()
      THEN u.rol::TEXT
    END,
    un.nombre::TEXT,
    cl.nombre::TEXT,
    u.url_foto::TEXT,
    u.foto_path,
    u.es_activo
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE privado.mi_id() IS NOT NULL
    AND (u.es_activo OR privado.es_directiva())
    AND (
      u.id_usuario = privado.mi_id()
      OR EXISTS (
        SELECT 1
        FROM public.ciclos c
        WHERE c.id_ciclo = u.id_ciclo
          AND c.es_activo
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
      FROM public.directorio_portal() d
      WHERE d.id_usuario = p_id_usuario
    );
$$;

CREATE OR REPLACE FUNCTION public.admin_estado_integrante(
  p_id_usuario UUID,
  p_version BIGINT,
  p_activo BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v public.usuarios%ROWTYPE;
BEGIN
  -- Serializa cambios de estado y comprueba nuevamente quién actúa.
  PERFORM pg_catalog.pg_advisory_xact_lock(728401);

  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede cambiar el estado.';
  END IF;

  IF p_id_usuario = privado.mi_id() THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'No puedes desactivar tu propio perfil.';
  END IF;

  SELECT *
  INTO v
  FROM public.usuarios
  WHERE id_usuario = p_id_usuario
  FOR UPDATE;

  IF NOT FOUND OR p_activo IS NULL OR p_version IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Integrante o estado inválido.';
  END IF;

  IF v.version_perfil <> p_version THEN
    RAISE EXCEPTION USING
      ERRCODE = '40001',
      MESSAGE = 'El perfil cambió. Vuelve a abrirlo e inténtalo otra vez.';
  END IF;

  IF v.es_activo = p_activo THEN
    RETURN;
  END IF;

  UPDATE public.usuarios
  SET es_activo = p_activo
  WHERE id_usuario = p_id_usuario;

  INSERT INTO privado.historial_perfiles (
    id_usuario,
    auth_id,
    accion
  )
  VALUES (
    p_id_usuario,
    auth.uid(),
    CASE WHEN p_activo THEN 'activar' ELSE 'desactivar' END
  );
END;
$$;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'integrantes-fotos',
  'integrantes-fotos',
  FALSE,
  2097152,
  ARRAY['image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
  public = FALSE,
  file_size_limit = 2097152,
  allowed_mime_types = ARRAY['image/webp'];

CREATE OR REPLACE FUNCTION privado.foto_visible(p_path TEXT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT privado.es_directiva() OR EXISTS (
    SELECT 1
    FROM public.directorio_portal() d
    WHERE d.foto_path = p_path
  );
$$;

REVOKE ALL ON FUNCTION privado.foto_visible(TEXT)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION privado.foto_visible(TEXT)
TO authenticated;

DROP POLICY IF EXISTS fotos_lectura ON storage.objects;

CREATE POLICY fotos_lectura
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'integrantes-fotos'
  AND privado.foto_visible(name)
);

DROP POLICY IF EXISTS fotos_alta ON storage.objects;

CREATE POLICY fotos_alta
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'integrantes-fotos'
  AND privado.es_directiva()
  AND name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'
);

DROP POLICY IF EXISTS fotos_limpieza ON storage.objects;

CREATE POLICY fotos_limpieza
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'integrantes-fotos'
  AND privado.es_directiva()
  AND NOT EXISTS (
    SELECT 1
    FROM public.usuarios u
    WHERE u.foto_path = name
  )
);

CREATE OR REPLACE FUNCTION public.admin_guardar_perfil(
  p_id_usuario UUID,
  p_version BIGINT,
  p_nombres TEXT,
  p_apellido TEXT,
  p_rol TEXT,
  p_id_unidad UUID,
  p_id_clase UUID,
  p_url_foto TEXT,
  p_foto_path TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede guardar perfiles.';
  END IF;

  IF p_foto_path IS NOT NULL AND (
    split_part(p_foto_path, '/', 1) <> p_id_usuario::TEXT
    OR NOT EXISTS (
      SELECT 1
      FROM storage.objects
      WHERE bucket_id = 'integrantes-fotos'
        AND name = p_foto_path
    )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La foto no pertenece a este perfil o no terminó de subirse.';
  END IF;

  PERFORM public.admin_guardar_integrante(
    p_id_usuario,
    p_version,
    p_nombres,
    p_apellido,
    p_rol,
    p_id_unidad,
    p_id_clase,
    p_url_foto
  );

  UPDATE public.usuarios
  SET foto_path = p_foto_path
  WHERE id_usuario = p_id_usuario
    AND foto_path IS DISTINCT FROM p_foto_path;

  RETURN p_id_usuario;
END;
$$;

ALTER FUNCTION public.directorio_portal()
OWNER TO postgres;

ALTER FUNCTION public.especialidades_visibles(UUID)
OWNER TO postgres;

ALTER FUNCTION privado.foto_visible(TEXT)
OWNER TO postgres;

ALTER FUNCTION public.admin_estado_integrante(UUID, BIGINT, BOOLEAN)
OWNER TO postgres;

ALTER FUNCTION public.admin_guardar_perfil(
  UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT, TEXT
)
OWNER TO postgres;

REVOKE ALL ON FUNCTION
  public.directorio_portal(),
  public.especialidades_visibles(UUID),
  public.admin_estado_integrante(UUID, BIGINT, BOOLEAN),
  public.admin_guardar_perfil(
    UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT, TEXT
  )
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION
  public.directorio_portal(),
  public.especialidades_visibles(UUID),
  public.admin_estado_integrante(UUID, BIGINT, BOOLEAN),
  public.admin_guardar_perfil(
    UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT, TEXT
  )
TO authenticated;

INSERT INTO privado.migraciones (version)
VALUES ('005_portal_y_fotos')
ON CONFLICT DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;