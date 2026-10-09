-- ==========================================================
-- Naar-Shalem | Fase 1 y 2: Catálogo Base + Progreso
-- Tablas: CICLOS, UNIDADES, CLASES, USUARIOS, ASISTENCIAS, CUOTAS
-- Motor: PostgreSQL 13+ (gen_random_uuid() viene incluido)
-- Ejecutar en DBeaver conectado a la base "naar_shalem"
-- (Alt + X = ejecutar script completo)
-- ==========================================================

-- Limpieza para poder re-ejecutar el script sin errores
DROP TABLE IF EXISTS asistencias CASCADE;
DROP TABLE IF EXISTS cuotas   CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS clases   CASCADE;
DROP TABLE IF EXISTS unidades CASCADE;
DROP TABLE IF EXISTS ciclos   CASCADE;

-- ----------------------------------------------------------
-- BLOQUE 1: NÚCLEO ORGANIZACIONAL (según Diagrama ER)
-- ----------------------------------------------------------

CREATE TABLE ciclos (
    id_ciclo  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anio      INT     NOT NULL UNIQUE,
    es_activo BOOLEAN NOT NULL DEFAULT FALSE  -- cuál es el año en curso
);

CREATE TABLE unidades (
    id_unidad UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre    VARCHAR(100) NOT NULL,          -- Ej. Jaspe, Diamante
    lema      VARCHAR(255),
    porra     TEXT,
    url_foto  VARCHAR(500)
);

CREATE TABLE clases (
    id_clase         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre           VARCHAR(100) NOT NULL,   -- Ej. Amigo, Compañero
    color_distintivo VARCHAR(50),
    url_foto         VARCHAR(500)
);

-- NOTA: en el documento, id_usuario está "vinculado a Supabase Auth".
-- En local no existe Supabase, así que es un UUID normal autogenerado.
-- Al migrar a Supabase, este id se reemplaza por el de auth.users.
CREATE TABLE usuarios (
    id_usuario          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_ciclo            UUID NOT NULL REFERENCES ciclos(id_ciclo),
    id_unidad           UUID REFERENCES unidades(id_unidad),  -- nulo al iniciar el año
    id_clase            UUID REFERENCES clases(id_clase),     -- nulo al iniciar el año
    rol                 VARCHAR(20) NOT NULL
                        CHECK (rol IN ('directiva', 'consejero', 'capitan', 'conquistador')),
    nombres             VARCHAR(100) NOT NULL,
    apellido            VARCHAR(100) NOT NULL,
    celular             VARCHAR(20),
    url_foto            VARCHAR(500),
    tipo_sangre         VARCHAR(5),    -- Dato sensible (RLS)
    alergias            TEXT,          -- Dato sensible (RLS)
    contacto_emergencia VARCHAR(255),  -- Dato sensible (RLS)
    es_activo           BOOLEAN NOT NULL DEFAULT TRUE  -- bajas sin borrar el registro
);

-- ----------------------------------------------------------
-- DATOS DE PRUEBA
-- ----------------------------------------------------------

-- 1 Ciclo activo
INSERT INTO ciclos (id_ciclo, anio, es_activo) VALUES
('c0000000-0000-4000-8000-000000000001', 2026, TRUE);

-- 2 Unidades
INSERT INTO unidades (id_unidad, nombre, lema, porra) VALUES
('a0000000-0000-4000-8000-000000000001', 'Jaspe',    'Firmes en la roca',  'Jaspe, Jaspe, ¡siempre al frente!'),
('a0000000-0000-4000-8000-000000000002', 'Diamante', 'Brillamos en la luz', 'Diamante, Diamante, ¡fuerte y constante!');

-- 2 Clases
INSERT INTO clases (id_clase, nombre, color_distintivo) VALUES
('b0000000-0000-4000-8000-000000000001', 'Amigo',     'Azul'),
('b0000000-0000-4000-8000-000000000002', 'Compañero', 'Rojo');

-- 3 Usuarios distintos
INSERT INTO usuarios
    (id_usuario, id_ciclo, id_unidad, id_clase, rol, nombres, apellido, celular, tipo_sangre, alergias, contacto_emergencia, es_activo)
VALUES
('d0000000-0000-4000-8000-000000000001',
 'c0000000-0000-4000-8000-000000000001',
 'a0000000-0000-4000-8000-000000000001',
 'b0000000-0000-4000-8000-000000000002',
 'consejero', 'Laura', 'Mendoza', '9211234567', 'O+', 'Ninguna', 'Carlos Mendoza - 9217654321', TRUE),

('d0000000-0000-4000-8000-000000000002',
 'c0000000-0000-4000-8000-000000000001',
 'a0000000-0000-4000-8000-000000000001',
 'b0000000-0000-4000-8000-000000000001',
 'capitan', 'Daniel', 'Torres', '9219876543', 'A+', 'Penicilina', 'Rosa Torres - 9211112233', TRUE),

('d0000000-0000-4000-8000-000000000003',
 'c0000000-0000-4000-8000-000000000001',
 'a0000000-0000-4000-8000-000000000002',
 'b0000000-0000-4000-8000-000000000002',
 'conquistador', 'Ana', 'Pérez', NULL, 'B+', 'Maní', 'Luis Pérez - 9214445566', TRUE);

-- ==========================================================
-- FASE 2: ASISTENCIAS Y CUOTAS
-- ==========================================================

CREATE TABLE asistencias (
    id_asistencia UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario    UUID NOT NULL REFERENCES usuarios(id_usuario),
    id_ciclo      UUID NOT NULL REFERENCES ciclos(id_ciclo),
    fecha         DATE NOT NULL,
    estado        VARCHAR(15) NOT NULL
                  CHECK (estado IN ('asistencia', 'falta', 'justificado')),
    UNIQUE (id_usuario, fecha)
);

CREATE TABLE cuotas (
    id_cuota      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_usuario    UUID NOT NULL REFERENCES usuarios(id_usuario),
    id_ciclo      UUID NOT NULL REFERENCES ciclos(id_ciclo),
    fecha_semana  DATE NOT NULL,
    monto_pagado  INT  NOT NULL DEFAULT 0 CHECK (monto_pagado >= 0),
    UNIQUE (id_usuario, fecha_semana)
);

-- Asistencias (Laura 100% | Daniel 75% | Ana 50%)
INSERT INTO asistencias (id_usuario, id_ciclo, fecha, estado) VALUES
-- Laura Mendoza
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'asistencia'),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'asistencia'),
-- Daniel Torres
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'asistencia'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'falta'),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'justificado'),
-- Ana Pérez
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 'asistencia'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 'falta'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 'falta'),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 'asistencia');

-- Cuotas semanales de $10 (Laura $40 | Daniel $30 | Ana $20)
INSERT INTO cuotas (id_usuario, id_ciclo, fecha_semana, monto_pagado) VALUES
-- Laura Mendoza
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 10),
('d0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10),
-- Daniel Torres
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 10),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 0),
('d0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10),
-- Ana Pérez
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-05', 10),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-12', 0),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-19', 0),
('d0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000001', '2026-09-26', 10);

-- Verificación rápida (opcional)
-- SELECT u.nombres, u.apellido, u.rol, un.nombre AS unidad, c.nombre AS clase
-- FROM usuarios u
-- LEFT JOIN unidades un ON un.id_unidad = u.id_unidad
-- LEFT JOIN clases   c  ON c.id_clase   = u.id_clase;
