-- database/migrations/001_cuentas_y_datos_privados.sql
-- Ejecutar desde SQL Editor de Supabase con el rol postgres.
-- Conserva los UUID y las relaciones existentes.
-- Esta migración puede volver a ejecutarse sin duplicar datos.

BEGIN;

SET LOCAL lock_timeout = '5s';

CREATE SCHEMA IF NOT EXISTS privado;

REVOKE ALL ON SCHEMA privado FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS privado.migraciones (
    version TEXT PRIMARY KEY,
    aplicada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

DO $migracion$
DECLARE
    v_columnas INTEGER;
    v_antes JSONB;
    v_despues JSONB;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM privado.migraciones
        WHERE version = '001_cuentas_y_datos_privados'
    ) THEN
        RAISE NOTICE 'La migración 001 ya estaba aplicada.';
        RETURN;
    END IF;

    -- Impide cambios concurrentes mientras se realiza la separación.
    -- Si las tablas están ocupadas, se cancela después de cinco segundos.
    LOCK TABLE
        public.usuarios,
        public.asistencias,
        public.cuotas,
        public.conquistador_especialidades
    IN ACCESS EXCLUSIVE MODE;

    SELECT count(*)
    INTO v_columnas
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'usuarios'
      AND column_name IN (
          'celular',
          'contacto_emergencia',
          'tipo_sangre',
          'alergias'
      );

    IF v_columnas <> 4 THEN
        RAISE EXCEPTION
            'El esquema no coincide con el esperado: faltan columnas privadas en public.usuarios. No se aplicaron cambios.';
    END IF;

    SELECT jsonb_build_object(
        'usuarios', (SELECT count(*) FROM public.usuarios),
        'asistencias', (SELECT count(*) FROM public.asistencias),
        'cuotas', (SELECT count(*) FROM public.cuotas),
        'insignias', (
            SELECT count(*)
            FROM public.conquistador_especialidades
        )
    )
    INTO v_antes;

    CREATE TABLE privado.usuarios_contacto (
        id_usuario UUID PRIMARY KEY
            REFERENCES public.usuarios(id_usuario)
            ON DELETE RESTRICT,
        celular VARCHAR(20),
        contacto_emergencia VARCHAR(255),
        nombre_tutor VARCHAR(150),
        celular_tutor VARCHAR(20)
    );

    CREATE TABLE privado.usuarios_salud (
        id_usuario UUID PRIMARY KEY
            REFERENCES public.usuarios(id_usuario)
            ON DELETE RESTRICT,
        tipo_sangre VARCHAR(5),
        alergias TEXT
    );

    CREATE TABLE privado.cuentas_miembros (
        id_usuario UUID PRIMARY KEY
            REFERENCES public.usuarios(id_usuario)
            ON DELETE RESTRICT,
        auth_id UUID NOT NULL UNIQUE
            REFERENCES auth.users(id)
            ON DELETE RESTRICT,
        vinculado_en TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    -- El historial permanece aunque en el futuro se retire un vínculo.
    CREATE TABLE privado.historial_vinculaciones (
        id_evento UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        id_usuario UUID NOT NULL,
        auth_id UUID NOT NULL,
        accion TEXT NOT NULL CHECK (accion = 'vincular'),
        ejecutado_por TEXT NOT NULL,
        creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    INSERT INTO privado.usuarios_contacto (
        id_usuario,
        celular,
        contacto_emergencia
    )
    SELECT
        id_usuario,
        celular,
        contacto_emergencia
    FROM public.usuarios;

    INSERT INTO privado.usuarios_salud (
        id_usuario,
        tipo_sangre,
        alergias
    )
    SELECT
        id_usuario,
        tipo_sangre,
        alergias
    FROM public.usuarios;

    -- Comprueba que todos los datos se copiaron, incluyendo los NULL.
    IF EXISTS (
        SELECT 1
        FROM public.usuarios u
        LEFT JOIN privado.usuarios_contacto c
            ON c.id_usuario = u.id_usuario
        LEFT JOIN privado.usuarios_salud s
            ON s.id_usuario = u.id_usuario
        WHERE c.id_usuario IS NULL
           OR s.id_usuario IS NULL
           OR c.celular IS DISTINCT FROM u.celular
           OR c.contacto_emergencia IS DISTINCT FROM u.contacto_emergencia
           OR s.tipo_sangre IS DISTINCT FROM u.tipo_sangre
           OR s.alergias IS DISTINCT FROM u.alergias
    ) THEN
        RAISE EXCEPTION
            'La copia de datos privados no coincide con el original. Se cancela la migración.';
    END IF;

    ALTER TABLE privado.usuarios_contacto ENABLE ROW LEVEL SECURITY;
    ALTER TABLE privado.usuarios_salud ENABLE ROW LEVEL SECURITY;
    ALTER TABLE privado.cuentas_miembros ENABLE ROW LEVEL SECURITY;
    ALTER TABLE privado.historial_vinculaciones ENABLE ROW LEVEL SECURITY;

    -- Sin CASCADE: una dependencia inesperada detendrá la migración
    -- en lugar de eliminar vistas u otros objetos.
    ALTER TABLE public.usuarios
        DROP COLUMN celular,
        DROP COLUMN contacto_emergencia,
        DROP COLUMN tipo_sangre,
        DROP COLUMN alergias;

    SELECT jsonb_build_object(
        'usuarios', (SELECT count(*) FROM public.usuarios),
        'asistencias', (SELECT count(*) FROM public.asistencias),
        'cuotas', (SELECT count(*) FROM public.cuotas),
        'insignias', (
            SELECT count(*)
            FROM public.conquistador_especialidades
        )
    )
    INTO v_despues;

    IF v_antes IS DISTINCT FROM v_despues THEN
        RAISE EXCEPTION
            'Los conteos de registros cambiaron. Se cancela la migración.';
    END IF;

    INSERT INTO privado.migraciones (version)
    VALUES ('001_cuentas_y_datos_privados');

    RAISE NOTICE
        'Migración completada. Registros conservados: %',
        v_despues;
END;
$migracion$;

-- Vinculación administrativa.
-- No crea cuentas Auth, no modifica contraseñas y no reemplaza vínculos.
-- Se ejecuta desde SQL Editor; no está disponible para el frontend.
CREATE OR REPLACE FUNCTION privado.vincular_cuenta(
    p_id_usuario UUID,
    p_auth_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $funcion$
DECLARE
    v_auth_actual UUID;
    v_es_activo BOOLEAN;
BEGIN
    IF p_id_usuario IS NULL OR p_auth_id IS NULL THEN
        RAISE EXCEPTION
            'Debes indicar el UUID del miembro y el UUID de su cuenta Auth.';
    END IF;

    SELECT u.es_activo
    INTO v_es_activo
    FROM public.usuarios u
    WHERE u.id_usuario = p_id_usuario
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe el miembro indicado.';
    END IF;

    IF NOT v_es_activo THEN
        RAISE EXCEPTION
            'El miembro está inactivo. Revisa su expediente antes de vincularlo.';
    END IF;

    PERFORM 1
    FROM auth.users a
    WHERE a.id = p_auth_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe esa cuenta en Supabase Auth. Créala primero en Authentication > Users.';
    END IF;

    SELECT cm.auth_id
    INTO v_auth_actual
    FROM privado.cuentas_miembros cm
    WHERE cm.id_usuario = p_id_usuario;

    IF FOUND THEN
        IF v_auth_actual = p_auth_id THEN
            RAISE NOTICE 'Esta cuenta ya estaba vinculada al miembro.';
            RETURN;
        END IF;

        RAISE EXCEPTION
            'El miembro ya tiene otra cuenta vinculada. No se reemplazó el vínculo.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM privado.cuentas_miembros cm
        WHERE cm.auth_id = p_auth_id
    ) THEN
        RAISE EXCEPTION
            'Esa cuenta Auth ya pertenece a otro miembro.';
    END IF;

    INSERT INTO privado.cuentas_miembros (id_usuario, auth_id)
    VALUES (p_id_usuario, p_auth_id);

    INSERT INTO privado.historial_vinculaciones (
        id_usuario,
        auth_id,
        accion,
        ejecutado_por
    )
    VALUES (
        p_id_usuario,
        p_auth_id,
        'vincular',
        current_user
    );
END;
$funcion$;

-- Los datos privados se administran desde SQL Editor por ahora.
-- No se otorgan permisos al navegador, ni siquiera con sesión iniciada.
ALTER TABLE privado.migraciones ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON SCHEMA privado
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL TABLES IN SCHEMA privado
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL SEQUENCES IN SCHEMA privado
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA privado
FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT version, aplicada_en
FROM privado.migraciones
WHERE version = '001_cuentas_y_datos_privados';