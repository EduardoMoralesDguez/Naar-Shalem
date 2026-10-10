-- database/migrations/004_administrar_integrantes.sql
-- Ejecutar en SQL Editor como postgres, después de la migración 003.

BEGIN;

SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM privado.migraciones
    WHERE version = '003_directorio_compartido'
  ) THEN
    RAISE EXCEPTION
      'Primero ejecuta la migración 003_directorio_compartido.';
  END IF;
END;
$$;

-- Permite detectar si otra persona modificó el perfil
-- mientras el formulario estaba abierto.
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS version_perfil BIGINT NOT NULL DEFAULT 1;

CREATE OR REPLACE FUNCTION privado.incrementar_version_perfil()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.version_perfil := OLD.version_perfil + 1;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION privado.incrementar_version_perfil()
FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS incrementar_version_perfil
ON public.usuarios;

CREATE TRIGGER incrementar_version_perfil
BEFORE UPDATE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION privado.incrementar_version_perfil();

-- Registra quién realizó cada alta o edición.
CREATE TABLE IF NOT EXISTS privado.historial_perfiles (
  id_evento UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  id_usuario UUID NOT NULL,
  auth_id UUID NOT NULL,
  accion TEXT NOT NULL CHECK (accion IN ('crear', 'editar')),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE privado.historial_perfiles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE privado.historial_perfiles
FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_guardar_integrante(
  p_id_usuario UUID,
  p_version BIGINT,
  p_nombres TEXT,
  p_apellido TEXT,
  p_rol TEXT,
  p_id_unidad UUID,
  p_id_clase UUID,
  p_url_foto TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actual public.usuarios%ROWTYPE;
  v_ciclos UUID[];
  v_nombres TEXT := btrim(p_nombres);
  v_apellido TEXT := btrim(p_apellido);
  v_foto TEXT := nullif(btrim(p_url_foto), '');
BEGIN
  IF NOT privado.es_directiva() THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'Solo la directiva puede administrar integrantes.';
  END IF;

  IF p_id_usuario IS NULL
    OR coalesce(length(v_nombres), 0) NOT BETWEEN 1 AND 100
    OR coalesce(length(v_apellido), 0) NOT BETWEEN 1 AND 100
    OR p_rol IS NULL
    OR p_rol NOT IN (
      'directiva',
      'consejero',
      'capitan',
      'conquistador'
    )
  THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'Revisa el nombre, los apellidos y el rol del integrante.';
  END IF;

  IF v_foto IS NOT NULL AND (
    length(v_foto) > 500
    OR NOT (
      v_foto ~ '^https://[^[:space:]]+$'
      OR (
        v_foto ~ '^img/[[:alnum:]_./%-]+$'
        AND v_foto !~ '(^|/)\.\.(/|$)'
      )
    )
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La foto debe ser una URL https:// o una ruta dentro de img/, de hasta 500 caracteres.';
  END IF;

  IF p_id_unidad IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.unidades
    WHERE id_unidad = p_id_unidad
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La unidad seleccionada ya no existe.';
  END IF;

  IF p_id_clase IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.clases
    WHERE id_clase = p_id_clase
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'La clase seleccionada ya no existe.';
  END IF;

  IF p_version IS NULL THEN
    SELECT array_agg(id_ciclo)
    INTO v_ciclos
    FROM public.ciclos
    WHERE es_activo = TRUE;

    IF coalesce(cardinality(v_ciclos), 0) <> 1 THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'Debe existir exactamente un ciclo activo para registrar integrantes.';
    END IF;

    -- Un reintento con el mismo identificador no duplica el registro.
    IF EXISTS (
      SELECT 1
      FROM public.usuarios
      WHERE id_usuario = p_id_usuario
    ) THEN
      RAISE EXCEPTION USING
        ERRCODE = '23505',
        MESSAGE = 'Este registro ya existe. Cierra el formulario y recarga la página para comprobarlo.';
    END IF;

    INSERT INTO public.usuarios (
      id_usuario,
      id_ciclo,
      nombres,
      apellido,
      rol,
      id_unidad,
      id_clase,
      url_foto,
      es_activo
    )
    VALUES (
      p_id_usuario,
      v_ciclos[1],
      v_nombres,
      v_apellido,
      p_rol,
      p_id_unidad,
      p_id_clase,
      v_foto,
      TRUE
    );

    INSERT INTO privado.usuarios_contacto (id_usuario)
    VALUES (p_id_usuario);

    INSERT INTO privado.usuarios_salud (id_usuario)
    VALUES (p_id_usuario);
  ELSE
    SELECT *
    INTO v_actual
    FROM public.usuarios
    WHERE id_usuario = p_id_usuario
    FOR UPDATE;

    IF NOT FOUND OR NOT v_actual.es_activo THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'El integrante no existe o está inactivo.';
    END IF;

    IF v_actual.version_perfil <> p_version THEN
      RAISE EXCEPTION USING
        ERRCODE = '40001',
        MESSAGE = 'El perfil cambió mientras lo editabas. Cierra y vuelve a abrir el formulario.';
    END IF;

    IF v_actual.rol = 'directiva' AND p_rol <> 'directiva' THEN
      RAISE EXCEPTION USING
        ERRCODE = '22023',
        MESSAGE = 'El rol de una cuenta de directiva no se cambia desde este formulario.';
    END IF;

    UPDATE public.usuarios
    SET
      nombres = v_nombres,
      apellido = v_apellido,
      rol = p_rol,
      id_unidad = p_id_unidad,
      id_clase = p_id_clase,
      url_foto = v_foto
    WHERE id_usuario = p_id_usuario;
  END IF;

  INSERT INTO privado.historial_perfiles (
    id_usuario,
    auth_id,
    accion
  )
  VALUES (
    p_id_usuario,
    auth.uid(),
    CASE
      WHEN p_version IS NULL THEN 'crear'
      ELSE 'editar'
    END
  );

  RETURN p_id_usuario;
END;
$$;

ALTER FUNCTION public.admin_guardar_integrante(
  UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT
)
OWNER TO postgres;

REVOKE ALL ON FUNCTION public.admin_guardar_integrante(
  UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT
)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.admin_guardar_integrante(
  UUID, BIGINT, TEXT, TEXT, TEXT, UUID, UUID, TEXT
)
TO authenticated;

-- Las escrituras directas del navegador siguen bloqueadas.
-- No se crean cuentas Auth ni vínculos en cuentas_miembros.
INSERT INTO privado.migraciones (version)
VALUES ('004_administrar_integrantes')
ON CONFLICT (version) DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;