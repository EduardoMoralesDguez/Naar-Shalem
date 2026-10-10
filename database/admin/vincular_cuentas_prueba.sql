-- database/admin/vincular_cuentas_prueba.sql
-- Primero crea estas tres cuentas en Authentication > Users.
-- Ejecutar como postgres en SQL Editor. No ejecutar desde el navegador.
-- Se usan los correos en el orden indicado: Ana, Laura y Daniel.
-- No cambia nombres, roles, contraseñas ni registros de los miembros.

BEGIN;

SET LOCAL lock_timeout = '5s';

DO $$
DECLARE
  v RECORD;
  v_auth_id UUID;
  v_coincidencias INTEGER;
BEGIN
  FOR v IN
    SELECT *
    FROM (VALUES
      (
        'd0000000-0000-4000-8000-000000000003'::UUID,
        'Ana',
        'Pérez',
        'conquistador',
        'ezequieleduardom4@gmail.com'
      ),
      (
        'd0000000-0000-4000-8000-000000000001'::UUID,
        'Laura',
        'Mendoza',
        'consejero',
        'pauletteelenamoralesdominguez@gmail.com'
      ),
      (
        'd0000000-0000-4000-8000-000000000002'::UUID,
        'Daniel',
        'Torres',
        'capitan',
        'zS24016723@estudiantes.uv.mx'
      )
    ) AS datos(id_usuario, nombres, apellido, rol, correo)
  LOOP
    PERFORM 1
    FROM public.usuarios u
    WHERE u.id_usuario = v.id_usuario
      AND u.nombres = v.nombres
      AND u.apellido = v.apellido
      AND u.rol = v.rol
      AND u.es_activo = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION
        'El perfil de % % no coincide con el UUID, rol o estado esperado. No se aplicaron vínculos.',
        v.nombres,
        v.apellido;
    END IF;

    SELECT count(*)
    INTO v_coincidencias
    FROM auth.users a
    WHERE lower(btrim(a.email)) = lower(btrim(v.correo));

    IF v_coincidencias <> 1 THEN
      RAISE EXCEPTION
        'Se esperaba una cuenta Auth para %, pero se encontraron %. Revisa Authentication > Users. No se aplicaron vínculos.',
        v.correo,
        v_coincidencias;
    END IF;

    SELECT a.id
    INTO v_auth_id
    FROM auth.users a
    WHERE lower(btrim(a.email)) = lower(btrim(v.correo));

    IF v_auth_id = '523c7eee-7b51-4595-b7c1-353a62526456'::UUID THEN
      RAISE EXCEPTION
        'La cuenta de directiva de Ezequiel no debe reasignarse.';
    END IF;

    -- Rechaza cuentas o perfiles ya vinculados a otra persona.
    -- Si el vínculo ya es el correcto, no lo duplica.
    PERFORM privado.vincular_cuenta(v.id_usuario, v_auth_id);
  END LOOP;
END;
$$;

COMMIT;

SELECT
  u.nombres,
  u.apellido,
  u.rol,
  a.email AS correo,
  a.id AS auth_id
FROM privado.cuentas_miembros cm
JOIN public.usuarios u
  ON u.id_usuario = cm.id_usuario
JOIN auth.users a
  ON a.id = cm.auth_id
WHERE u.id_usuario IN (
  'd0000000-0000-4000-8000-000000000003'::UUID,
  'd0000000-0000-4000-8000-000000000001'::UUID,
  'd0000000-0000-4000-8000-000000000002'::UUID
)
ORDER BY u.nombres;