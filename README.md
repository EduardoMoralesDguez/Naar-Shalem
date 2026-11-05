# Naar-Shalem

Portal del Club de Conquistadores. Frontend estático con JavaScript (módulos ES), HTML y CSS, Supabase Auth/PostgreSQL/Storage y PWA. No hay servidor Express, React, TypeScript, framework de componentes ni bundler. Node se usa para generar el service worker y ejecutar pruebas.

## Qué está disponible

- Directorio, perfiles y administración de integrantes, salud/contactos privados, fotografías.
- Clases y unidades independientes, identidad de unidad, colores de clase, hasta dos capitanes por unidad y ciclos anuales.
- Calendario de reuniones, prácticas, eventos y avisos segmentados.
- Competencia: matriz por reunión/unidad con asistencia, cuota de $10, criterios, extras y cierre transaccional.
- Clasificación, cortes, publicaciones temporales, acumulado anual y estadísticas.
- Historial financiero, abonos, correcciones, consulta de insignias y porcentajes de progreso.
- Captura offline de directiva y sincronización con control de conflictos; no envío garantizado con la app cerrada.

No están completos cuadernillos/tareas, otorgamiento de insignias, biblioteca, retos, turnos de programa, preinscripción, mapa ni push. La [auditoría y matriz de cumplimiento](docs/AUDITORIA.md) distingue lo probado de lo pendiente. Las [reglas operativas](docs/OPERACION.md) documentan permisos, cálculos, históricos y resolución de conflictos.

## Estructura

```text
frontend/             aplicación estática que se publica
  js/app.js           sesión y rutas hash
  js/modules/         vistas e interacción
  js/services/        RPC, consultas, fotografías y sincronización
  js/lib/             cliente Supabase, RPC, DOM, colores e IndexedDB
  vendor/             Supabase JS 2.49.8 y licencia MIT
supabase/schema.sql   instalación NUEVA: estado final consolidado
database/            historia de esquema/migraciones y administración (ver abajo)
scripts/              build PWA, verificación y consolidación desde catálogo
tests/               PostgreSQL PGlite, interfaz Chromium y RPC
docs/                operación y auditoría técnica
```

## Instalar y ejecutar

Requisitos de desarrollo: Node 22 o posterior, npm y Python 3 para el servidor estático opcional. Las pruebas de interfaz usan Chromium en `/usr/bin/chromium` y WebSocket/CDP. No hay comprobación de TypeScript porque el proyecto no usa TypeScript.

```bash
npm ci
npm run build
python3 -m http.server 8080 --directory frontend
```

Abrir `http://localhost:8080`. No usar `file://`: módulos ES, Auth y service worker requieren un origen HTTP/HTTPS. Para otras máquinas y producción usar HTTPS.

### Configuración pública

`frontend/js/config.js` define `SUPABASE_URL`, `SUPABASE_PUBLIC_KEY`, meta de cuotas, paginación y formato monetario. Introducir la URL del proyecto y su clave publicable/anon. Este cliente estático no lee `process.env`; crear variables en Vercel por sí solo no cambia ese archivo. Nunca introducir claves secret, service_role, contraseña PostgreSQL ni credenciales de correo en el frontend. Esta refactorización no modifica los valores existentes.

La aplicación utiliza un único cliente Supabase y la distribución local UMD `@supabase/supabase-js@2.49.8`. Origen del archivo: `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.8/dist/umd/supabase.js`. Licencia: `frontend/vendor/SUPABASE-LICENSE`. Se sirve localmente para funcionar sin CDN; para actualizar, revisar compatibilidad, cambiar referencia de `index.html` y regenerar el SW.

### Supabase nuevo: un solo SQL

1. Crear un proyecto Supabase vacío con Auth y Storage habilitados.
2. Ejecutar **`supabase/schema.sql` completo** en SQL Editor como administrador/postgres. No ejecutar antes `database/schema.sql` ni las migraciones históricas. El maestro crea tablas, restricciones, índices, funciones, triggers, RLS, permisos y buckets privados. Incluye ciclo del año actual de Ciudad de México, catálogos iniciales y criterios; no crea personas, cuentas Auth ni pagos ficticios.
3. Crear la primera cuenta en Supabase **Authentication → Users**. Configurar Site URL y Redirect URLs de Auth para localhost y la publicación HTTPS; verificar el flujo de recuperación con correo real.
4. Crear su perfil de directiva y vincularlo desde SQL Editor, reemplazando el UUID de ejemplo por el ID real de esa cuenta:

```sql
DO $$
DECLARE miembro uuid; cuenta uuid := 'REEMPLAZAR_POR_UUID_DE_AUTH';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id=cuenta) THEN
    RAISE EXCEPTION 'Cuenta Auth inexistente';
  END IF;
  IF EXISTS (SELECT 1 FROM privado.cuentas_miembros WHERE auth_id=cuenta) THEN
    RAISE EXCEPTION 'Esta cuenta ya está vinculada';
  END IF;
  INSERT INTO public.usuarios(id_ciclo,nombres,apellido,rol)
  SELECT id_ciclo,'Tu nombre','Tu apellido','directiva'
  FROM public.ciclos WHERE es_activo RETURNING id_usuario INTO miembro;
  PERFORM privado.vincular_cuenta(miembro,cuenta);
END $$;
```

5. Configurar el frontend, iniciar sesión, crear unidades y completar integrantes. Cada miembro necesita una cuenta Auth y una vinculación independiente; registrar un perfil no crea su cuenta automáticamente. `database/admin/vincular_cuenta.sql` contiene las consultas administrativas para identificar los UUID.

Los buckets `integrantes-fotos` y `unidades-fotos` se conservan privados para mostrar fotos anteriores. Las nuevas fotos se enlazan como archivos estáticos del repositorio, sin subirlas a Storage. No exponer el esquema `privado` en PostgREST. `gen_random_uuid()` es nativo de PostgreSQL 13+; no se requiere instalar una extensión adicional. Auth/Storage y sus roles son provistos por Supabase, no recreados por el maestro.

**El maestro es para instalaciones nuevas.** Se detiene si detecta tablas de una instalación existente y se ejecuta en una transacción. No es un script de actualización ni un respaldo. La validación local usa PostgreSQL PGlite con un contrato mínimo de Auth/Storage; falta validación de servicios alojados en un proyecto Supabase real.

### Base existente y scripts históricos

Conservar los datos existentes: no ejecutar el maestro encima. Consultar `privado.migraciones` y aplicar únicamente migraciones faltantes en orden. El estado consolidado corresponde a **001–024**. Si ya aplicaste 023, ejecuta únicamente **`database/migrations/024_capitanes_fotos.sql`**. Convierte subcapitanes a capitanes sin cambiar sus UUID ni movimientos y admite hasta dos capitanes activos por unidad. Cierra sesión y vuelve a entrar después.

`database/schema.sql` y `database/migrations/` se conservan como referencia histórica y para probar equivalencia/upgrades. En la secuencia histórica, 002 requiere vincular previamente una directiva después de 001; el maestro elimina ese paso intermedio de instalación. Las migraciones incluyen importaciones de modelos anteriores que no se necesitan al iniciar vacío.

Los cuatro archivos `database/admin/` son herramientas manuales, fuera de la instalación: vincular una cuenta, vincular cuentas de prueba, limpiar actividad o limpiar cuotas/asistencias. Los dos de limpieza son destructivos y requieren revisar alcance, copias de seguridad y pendientes de todos los teléfonos. No se ejecutan desde build, Vercel ni la instalación nueva.

## Publicar en Vercel

Importar el repositorio y seleccionar la rama a probar. Configuración recomendada: raíz del proyecto en el repositorio, preset **Other**, instalación `npm ci`, build `npm run build`, directorio de salida **frontend**. No hace falta fallback SPA porque las rutas usan `#`. Mantener juntos HTML, JS, CSS, `vendor`, imágenes, manifest y SW. La configuración de Vercel está en el panel; no se afirma que exista un `vercel.json` en este repositorio.

Git y Vercel no ejecutan SQL automáticamente. Configurar en Supabase las URLs permitidas de la publicación. Tras desplegar, cerrar todas las ventanas de la PWA y volver a abrir con conexión. No borrar IndexedDB si hay capturas pendientes. La interfaz debe conservar «Siervo de Dios», «Un sentimiento que se lleva en el corazón», azul `#292C98`, oro `#FFCA00`, rojo `#FF1A10` y blanco.

## Fotos desde GitHub

1. Colocar la imagen en **`frontend/img/perfiles/`** (integrante) o **`frontend/img/unidades/`** (unidad). En GitHub se puede usar *Add file → Upload files* dentro de esa carpeta; publicar el commit en la rama que despliega Vercel.
2. Usar nombres sin espacios ni acentos, por ejemplo `ana.webp` o el UUID del integrante. Se aceptan `.webp`, `.png`, `.jpg`, `.jpeg`; recomendado máximo 640×640 y menos de 200 KB.
3. Esperar el despliegue. En **Editar integrante → Foto de perfil** escribir `ana.webp` o `img/perfiles/ana.webp`. Para una unidad usar `img/unidades/jaspe.webp` en **Editar unidad**. No pegar la página `github.com/.../blob/...`.
4. Guardar. La base solo guarda la ruta y Vercel sirve el archivo del repositorio; no se necesita token GitHub en el navegador. «Quitar foto» desvincula la imagen, no borra el archivo ni una foto antigua de Storage.

Las fotos publicadas son accesibles por URL, como las insignias; no tienen la privacidad de Storage firmado. Usa esta carpeta solo para imágenes que quieras publicar. Las fotos antiguas siguen funcionando y no se copian automáticamente; para sustituirlas, publicar su archivo y cambiar la ruta. Para actualizar una foto usa un nombre nuevo (`ana-2.webp`) y evita cachés antiguos. Las fotos nuevas no se precargan masivamente en el paquete offline.

La interfaz incorpora navegación lateral con búsqueda, paneles de bordes discretos y menú móvil, conservando la paleta azul, oro y blanco. Las operaciones siguen protegidas por sus permisos actuales.

## Validación y mantenimiento

```bash
npm run build          # genera SW a partir de los assets actuales
npm run check          # sintaxis JS, imports y archivos estáticos
npm test               # SQL histórico/maestro, RPC, capitanes y rutas de fotos
npm run test:ui        # calendario, organización y competencia en Chromium
npm run test:schema    # restauración limpia, catálogo, RLS y flujo operativo
```

`npm run db:consolidar` reconstruye el estado histórico en una base PGlite efímera y extrae definiciones finales de PostgreSQL. No concatena archivos ni se conecta a tu Supabase. Después de modificar SQL, regenerar el maestro y ejecutar `test:schema`; los UUID de semillas pueden variar entre generaciones. No editar copias de funciones a mano en ambos sitios.

Las pruebas SQL y de navegador son locales; las de navegador sustituyen servicios por fixtures. No certifican email, Storage alojado, Vercel, rendimiento 3G ni instalación en iOS. Los resultados y límites de esta auditoría están en `docs/AUDITORIA.md`.

Para validar la rama en tu proyecto de pruebas, sigue [la lista manual por rol](docs/PRUEBAS_MANUALES.md).
