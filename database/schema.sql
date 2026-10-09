-- schema.sql
-- Naar-Shalem | Fases 1, 2 y 3 | PostgreSQL 13+
-- Conserva los datos existentes y permite repetir los INSERT de prueba.

BEGIN;

CREATE TABLE IF NOT EXISTS ciclos (
    id_ciclo UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anio INT NOT NULL UNIQUE,
    es_activo BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS unidades (
    id_unidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL,
    lema VARCHAR(255),
    porra TEXT,
    url_foto VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS clases (
    id_clase UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL,
    color_distintivo VARCHAR(50),
    url_foto VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_ciclo UUID NOT NULL REFERENCES ciclos(id_ciclo),
    id_unidad UUID REFERENCES unidades(id_unidad),
    id_clase UUID REFERENCES clases(id_clase),
    rol VARCHAR(20) NOT NULL
        CHECK (rol IN ('directiva', 'consejero', 'capitan', 'conquistador')),
    nombres VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    celular VARCHAR(20),
    url_foto VARCHAR(500),
    tipo_sangre VARCHAR(5),
    alergias TEXT,
    contacto_emergencia VARCHAR(255),
    es_activo BOOLEAN NOT NULL DEFAULT TRUE
);

-- FASE 1: DATOS DE PRUEBA

INSERT INTO ciclos (id_ciclo, anio, es_activo) VALUES
('c0000000-0000-4000-8000-000000000001', 2026, TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO unidades (id_unidad, nombre, lema, porra) VALUES
('a0000000-0000-4000-8000-000000000001', 'Jaspe', 'Firmes en la roca', 'Jaspe, Jaspe, ¡siempre al frente!'),
('a0000000-0000-4000-8000-000000000002', 'Diamante', 'Brillamos en la luz', 'Diamante, Diamante, ¡fuerte y constante!')
ON CONFLICT DO NOTHING;

INSERT INTO clases (id_clase, nombre, color_distintivo) VALUES
('b0000000-0000-4000-8000-000000000001', 'Amigo', 'Azul'),
('b0000000-0000-4000-8000-000000000002', 'Compañero', 'Rojo')
ON CONFLICT DO NOTHING;

INSERT INTO usuarios (
    id_usuario, id_ciclo, id_unidad, id_clase, rol,
    nombres, apellido, celular, tipo_sangre, alergias,
    contacto_emergencia, es_activo
) VALUES
(
    'd0000000-0000-4000-8000-000000000001',
    'c0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000002',
    'consejero', 'Laura', 'Mendoza', '9211234567',
    'O+', 'Ninguna', 'Carlos Mendoza - 9217654321', TRUE
),
(
    'd0000000-0000-4000-8000-000000000002',
    'c0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000001',
    'b0000000-0000-4000-8000-000000000001',
    'capitan', 'Daniel', 'Torres', '9219876543',
    'A+', 'Penicilina', 'Rosa Torres - 9211112233', TRUE
),
(
    'd0000000-0000-4000-8000-000000000003',
    'c0000000-0000-4000-8000-000000000001',
    'a0000000-0000-4000-8000-000000000002',
    'b0000000-0000-4000-8000-000000000002',
    'conquistador', 'Ana', 'Pérez', NULL,
    'B+', 'Maní', 'Luis Pérez - 9214445566', TRUE
)
ON CONFLICT DO NOTHING;

-- FASE 2: ASISTENCIAS Y CUOTAS

CREATE TABLE IF NOT EXISTS asistencias (
    id_asistencia UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL REFERENCES usuarios(id_usuario),
    id_ciclo UUID NOT NULL REFERENCES ciclos(id_ciclo),
    fecha DATE NOT NULL,
    estado VARCHAR(15) NOT NULL
        CHECK (estado IN ('asistencia', 'falta', 'justificado')),
    UNIQUE (id_usuario, fecha)
);

CREATE TABLE IF NOT EXISTS cuotas (
    id_cuota UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario UUID NOT NULL REFERENCES usuarios(id_usuario),
    id_ciclo UUID NOT NULL REFERENCES ciclos(id_ciclo),
    fecha_semana DATE NOT NULL,
    monto_pagado INT NOT NULL DEFAULT 0 CHECK (monto_pagado >= 0),
    UNIQUE (id_usuario, fecha_semana)
);

INSERT INTO asistencias (id_usuario, id_ciclo, fecha, estado) VALUES
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'asistencia'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'asistencia'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'falta'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'justificado'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'falta'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'falta'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'asistencia')
ON CONFLICT DO NOTHING;

INSERT INTO cuotas (id_usuario, id_ciclo, fecha_semana, monto_pagado) VALUES
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 10),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 0),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 0),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 0),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10)
ON CONFLICT DO NOTHING;

-- FASE 3: BANDA VIRTUAL DE ESPECIALIDADES

CREATE TABLE IF NOT EXISTS especialidades (
    id_especialidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre VARCHAR(100) NOT NULL UNIQUE,
    url_imagen VARCHAR(500) NOT NULL
);

-- Compatibilidad con la versión anterior que usaba colores.
ALTER TABLE especialidades
    ADD COLUMN IF NOT EXISTS url_imagen VARCHAR(500);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'especialidades'
          AND column_name = 'categoria'
    ) THEN
        ALTER TABLE especialidades
            ALTER COLUMN categoria SET DEFAULT 'General';
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS conquistador_especialidades (
    id_usuario UUID NOT NULL REFERENCES usuarios(id_usuario),
    id_especialidad UUID NOT NULL REFERENCES especialidades(id_especialidad),
    fecha_obtencion DATE NOT NULL DEFAULT CURRENT_DATE,
    PRIMARY KEY (id_usuario, id_especialidad)
);

-- Actualiza la imagen si la especialidad ya existe por nombre.
INSERT INTO especialidades (id_especialidad, nombre, url_imagen) VALUES
(
    'f0000000-0000-4000-8000-000000000001',
    'Primeros Auxilios',
    'img/especialidades/primeros_auxilios.png'
),
(
    'f0000000-0000-4000-8000-000000000002',
    'Ejercicios y Marchas',
    'img/especialidades/ejercicios_y_marchas.png'
),
(
    'f0000000-0000-4000-8000-000000000003',
    'Nudos',
    'img/especialidades/nudos.png'
),
(
    'f0000000-0000-4000-8000-000000000004',
    'Astronomía',
    'img/especialidades/astronomia.png'
)
ON CONFLICT (nombre) DO UPDATE
SET url_imagen = EXCLUDED.url_imagen;

-- Busca las especialidades por nombre para conservar sus UUID existentes.
INSERT INTO conquistador_especialidades (id_usuario, id_especialidad)
SELECT asignacion.id_usuario, especialidad.id_especialidad
FROM (
    VALUES
    ('d0000000-0000-4000-8000-000000000001'::UUID, 'Primeros Auxilios'),
    ('d0000000-0000-4000-8000-000000000001'::UUID, 'Ejercicios y Marchas'),
    ('d0000000-0000-4000-8000-000000000002'::UUID, 'Nudos'),
    ('d0000000-0000-4000-8000-000000000002'::UUID, 'Ejercicios y Marchas'),
    ('d0000000-0000-4000-8000-000000000003'::UUID, 'Nudos'),
    ('d0000000-0000-4000-8000-000000000003'::UUID, 'Astronomía')
) AS asignacion(id_usuario, nombre)
JOIN especialidades especialidad
    ON especialidad.nombre = asignacion.nombre
ON CONFLICT DO NOTHING;

COMMIT;