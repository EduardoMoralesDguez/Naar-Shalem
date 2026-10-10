-- database/migrations/002_login_rls.sql
BEGIN;

SET LOCAL lock_timeout = '5s';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM privado.migraciones
    WHERE version = '001_cuentas_y_datos_privados'
  ) THEN
    RAISE EXCEPTION 'Primero ejecuta la migración 001.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM privado.cuentas_miembros cm
    JOIN public.usuarios u ON u.id_usuario = cm.id_usuario
    WHERE u.rol = 'directiva'
      AND u.es_activo
  ) THEN
    RAISE EXCEPTION
      'Primero vincula una cuenta activa de directiva.';
  END IF;
END;
$$;

-- Retira permisos y políticas anteriores de las tablas del módulo.
-- Incluye permisos específicos por columna, si existieran.
DO $$
DECLARE
  t TEXT;
  p RECORD;
  columnas TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'usuarios',
    'ciclos',
    'unidades',
    'clases',
    'asistencias',
    'cuotas',
    'especialidades',
    'conquistador_especialidades'
  ] LOOP
    EXECUTE format(
      'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
      t
    );

    FOR p IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = t
    LOOP
      EXECUTE format(
        'DROP POLICY %I ON public.%I',
        p.policyname,
        t
      );
    END LOOP;

    EXECUTE format(
      'REVOKE ALL PRIVILEGES ON TABLE public.%I FROM PUBLIC, anon, authenticated',
      t
    );

    SELECT string_agg(quote_ident(column_name), ', ')
    INTO columnas
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = t;

    EXECUTE format(
      'REVOKE ALL PRIVILEGES (%s) ON TABLE public.%I FROM PUBLIC, anon, authenticated',
      columnas,
      t
    );

    EXECUTE format(
      'GRANT SELECT ON TABLE public.%I TO authenticated',
      t
    );
  END LOOP;
END;
$$;

-- Identifica al miembro de la cuenta autenticada.
-- No confía en nombres, correos ni metadatos editables.
CREATE OR REPLACE FUNCTION privado.mi_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id_usuario
  FROM privado.cuentas_miembros cm
  JOIN public.usuarios u ON u.id_usuario = cm.id_usuario
  WHERE cm.auth_id = (SELECT auth.uid())
    AND u.es_activo = TRUE;
$$;

-- Comprueba el rol guardado en la base de datos.
CREATE OR REPLACE FUNCTION privado.es_directiva()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM privado.cuentas_miembros cm
    JOIN public.usuarios u ON u.id_usuario = cm.id_usuario
    WHERE cm.auth_id = (SELECT auth.uid())
      AND u.es_activo = TRUE
      AND u.rol = 'directiva'
  );
$$;

ALTER FUNCTION privado.mi_id() OWNER TO postgres;
ALTER FUNCTION privado.es_directiva() OWNER TO postgres;

-- El navegador no obtiene acceso a las tablas privadas.
-- Solo puede ejecutar los dos helpers usados por las políticas.
REVOKE ALL ON SCHEMA privado
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL TABLES IN SCHEMA privado
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA privado
FROM PUBLIC, anon, authenticated;

GRANT USAGE ON SCHEMA privado TO authenticated;

GRANT EXECUTE ON FUNCTION privado.mi_id()
TO authenticated;

GRANT EXECUTE ON FUNCTION privado.es_directiva()
TO authenticated;

GRANT USAGE ON SCHEMA public TO authenticated;

-- Expedientes y registros:
-- lectura para su propietario o para directiva.
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'usuarios',
    'asistencias',
    'cuotas',
    'conquistador_especialidades'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY lectura_autorizada
       ON public.%I
       FOR SELECT
       TO authenticated
       USING (
         (SELECT privado.es_directiva())
         OR id_usuario = (SELECT privado.mi_id())
       )',
      t
    );
  END LOOP;

  -- Los catálogos requieren una cuenta vinculada a un miembro activo.
  FOREACH t IN ARRAY ARRAY[
    'ciclos',
    'unidades',
    'clases',
    'especialidades'
  ] LOOP
    EXECUTE format(
      'CREATE POLICY lectura_catalogo
       ON public.%I
       FOR SELECT
       TO authenticated
       USING ((SELECT privado.mi_id()) IS NOT NULL)',
      t
    );
  END LOOP;
END;
$$;

-- No añadas privado a los esquemas expuestos de Supabase.
-- Salud, contactos y vínculos siguen fuera de la API pública.

-- Devuelve exclusivamente el perfil de quien realiza la petición.
-- No acepta un identificador de otra persona como parámetro.
CREATE OR REPLACE FUNCTION public.mi_perfil()
RETURNS TABLE (
  id_usuario UUID,
  nombres TEXT,
  apellido TEXT,
  rol TEXT,
  unidad TEXT,
  clase TEXT
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT
    u.id_usuario,
    u.nombres::TEXT,
    u.apellido::TEXT,
    u.rol::TEXT,
    un.nombre::TEXT,
    cl.nombre::TEXT
  FROM public.usuarios u
  LEFT JOIN public.unidades un
    ON un.id_unidad = u.id_unidad
  LEFT JOIN public.clases cl
    ON cl.id_clase = u.id_clase
  WHERE u.id_usuario = (SELECT privado.mi_id());
$$;

REVOKE ALL ON FUNCTION public.mi_perfil()
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.mi_perfil()
TO authenticated;

INSERT INTO privado.migraciones (version)
VALUES ('002_login_rls')
ON CONFLICT (version) DO NOTHING;

NOTIFY pgrst, 'reload schema';

COMMIT;