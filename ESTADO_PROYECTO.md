<!-- ESTADO_PROYECTO.md -->
# Naar-Shalem

Frontend Vanilla JS con módulos ES, Supabase Auth/PostgreSQL/Storage y publicación estática en Vercel. La aplicación se desarrolla como PWA; no dar por implementados offline, instalación o service worker sin verificarlos.

## Arquitectura y permisos

- `frontend/js/app.js`: sesión, navegación y coordinación.
- `frontend/js/services/`: consultas y RPC de Supabase.
- `frontend/js/modules/`: vistas e interacción.
- Perfiles y cuentas Auth se crean/vinculan por separado.
- Los permisos se comprueban en PostgreSQL; el esquema `privado` no se expone en la API.
- Todos los miembros autenticados pueden consultar perfiles básicos. Expedientes y cuotas mantienen sus permisos restringidos.
- Fotografías en el bucket privado `integrantes-fotos`; las insignias son imágenes estáticas del frontend.
- Conservar los textos “Siervo de Dios” y “Un sentimiento que se lleva en el corazón”, la paleta y el diseño responsivo.

## Asistencias: pases por reunión

- Reunión: directiva crea pases de hoy con nombre (por ejemplo, Mañana y Tarde). Se permiten varios por fecha; repetir el mismo nombre abre el existente y evita duplicados por reintentos. Los demás ven el día más reciente no futuro y no anulado. Los botones permiten elegir entre los pases de ese día.
- Cada asistencia se identifica por reunión e integrante, no por fecha. Corregir o anular un pase no afecta a otro del mismo día.
- Pase en tabla con botones A/J/F; todas las unidades y “Sin unidad” deben revisarse antes de cerrar. Los no marcados quedan con falta.
- Historial: matriz de integrantes por fecha y nombre del pase, A verde/J amarilla/F roja y porcentaje `(A + J) / registros`. “—” significa no convocado y no cuenta como falta.
- Solo reuniones cerradas cuentan en la matriz y el dashboard.
- Directiva filtra por unidad y edita celdas con control de versión. Los borradores y reuniones anteriores se administran desde Historial.
- Capitán: solo convierte F en J para su unidad durante el mismo día, sin aprobación. No puede cambiar una A existente. Se valida en SQL con `America/Mexico_City`.
- Consejero: consulta de su unidad. Conquistador: consulta propia.
- La convocatoria conserva los integrantes y unidades de su creación; las altas posteriores no modifican automáticamente reuniones programadas anteriormente.
- La directiva está exenta de asistencia: no aparece en convocatorias, pases, matriz ni dashboard de asistencia de su perfil. Los registros anteriores se conservan, pero no se muestran ni cuentan. Los grupos vacíos de reuniones antiguas no bloquean su cierre.
- “Sin unidad” sigue disponible para integrantes sujetos a asistencia que no tengan unidad.
- Los directivos no muestran unidad/clase en tarjetas y perfiles. Solo conquistadores y capitanes muestran cuotas; los consejeros conservan únicamente asistencia.
- Las cuotas históricas se conservan. Esta iteración no elimina registros financieros ni amplía sus permisos.

## Instalación de esta iteración

1. Confirmar que ya están aplicadas las migraciones 001–008.
2. Ejecutar `database/migrations/009_pases_por_reunion.sql` en SQL Editor de Supabase.
3. Publicar el frontend de esta rama y recargar la aplicación.

La migración 009 vincula las asistencias existentes a su reunión, conserva sus identificadores y asigna el nombre General a los pases anteriores. Se puede ejecutar nuevamente, incluso después de crear varios pases. Conserva la compatibilidad de creación del frontend anterior mediante el pase General. La creación sigue limitada a hoy y el capitán mantiene el permiso F→J únicamente en su unidad y el mismo día.

La migración se valida localmente; no se ejecuta automáticamente en Supabase al subir esta rama.

La migración 007 dejó fechas antiguas como borradores para revisión. Cerrar las reuniones reales y anular las fechas de prueba; no borrar registros individuales para igualar contadores.

El despliegue de Vercel o un `git pull` no ejecutan SQL. Verificar `privado.migraciones` desde SQL Editor. No volver a ejecutar `schema.sql` sobre producción.

## Pruebas

Requiere Node.js moderno (probado con 24):

```bash
npm ci
npm test
npm run test:ui
```

- `npm test`: PostgreSQL local en PGlite, esquema y migraciones reales, roles, privacidad, cierres completos, correcciones, versiones y límites del capitán, varios pases por día, aislamiento entre pases y exención de directiva sin borrar datos.
- `npm run test:ui`: requiere Chromium. Por defecto usa `/usr/bin/chromium`; se puede indicar `CHROMIUM_PATH`. Prueba la interfaz real con servicios simulados, incluyendo móvil, porcentajes y perfiles por rol. Las capturas se guardan en una carpeta temporal.
- Ninguna prueba utiliza la base de producción.

## Trabajo con Git

Trabajar sobre el último commit, preservar cambios del propietario, subir una rama y abrir PR. Informar qué se probó y qué migración debe ejecutar el propietario. No confundir cambios locales, push, merge y migraciones aplicadas.
