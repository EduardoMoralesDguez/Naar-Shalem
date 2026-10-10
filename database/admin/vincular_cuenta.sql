-- database/admin/vincular_cuenta.sql
-- Uso administrativo desde SQL Editor de Supabase.
-- No ejecutar desde JavaScript ni con la clave pública.
--
-- PASO 1: ejecutar las dos consultas siguientes para identificar
-- al miembro y a su cuenta Auth.
--
-- PASO 2: reemplazar los dos marcadores de la llamada final.
-- Revisar nombre y correo antes de ejecutar la vinculación.

SELECT
    id_usuario,
    nombres,
    apellido,
    rol,
    es_activo
FROM public.usuarios
ORDER BY nombres, apellido;

SELECT
    id AS auth_id,
    email,
    email_confirmed_at,
    created_at
FROM auth.users
ORDER BY created_at DESC;

-- Sustituir el primer marcador por id_usuario de public.usuarios.
-- Sustituir el segundo marcador por auth_id de auth.users.
-- Conservar las comillas.
SELECT privado.vincular_cuenta(
    'PEGA_AQUI_EL_ID_USUARIO'::UUID,
    'PEGA_AQUI_EL_AUTH_ID'::UUID
);