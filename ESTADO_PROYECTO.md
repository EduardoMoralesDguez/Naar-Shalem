<!-- ESTADO_PROYECTO.md -->
# Naar-Shalem

Frontend Vanilla JS con módulos ES, Supabase Auth/PostgreSQL/Storage y publicación estática en Vercel. Incluye manifest y service worker para el módulo de cuotas sin conexión. El resto del portal requiere conexión; no asumir soporte offline para otros módulos.

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

## Cuotas semanales

- Nuevo módulo Inicio → Cuotas. $10 por domingo preparado por directiva, independiente de los pases de asistencia.
- Capitán y subcapitán registran cuotas completas de su unidad. Conquistadores solo consultan lo propio. Directiva cobra en cualquier unidad y administra abonos, anticipos, saldo, correcciones y anulaciones.
- Subcapitán es un rol explícito, seleccionable en el editor, con los mismos permisos de asistencia que capitán. Consejeros/directiva no generan cuotas.
- Libro privado de ingresos y aplicaciones en centavos. Un ingreso de $50 puede aplicarse a cinco cuotas, sin duplicar dinero.
- Escrituras exclusivamente por RPC transaccional, autorizada y auditada; UUID de operación para reintentos y versión por integrante/ciclo para evitar sobrescrituras de dos capturistas.
- IndexedDB mantiene la lista preparada y la cola por proyecto/cuenta. Service worker cachea únicamente archivos estáticos; SDK Supabase 2.49.8 servido localmente para no depender del CDN sin internet.
- Sincronización al abrir Cuotas con conexión, al recuperar red o pulsando el botón. No se garantiza ejecución con app cerrada. Conflictos se revisan explícitamente; nunca se sobreescriben automáticamente.
- Dashboard usa cuotas completamente cubiertas y domingos transcurridos. Total recibido incluye saldo a favor y excluye anulaciones.

## Instalación de esta iteración

1. Confirmar migraciones 001–009 aplicadas.
2. Ejecutar `database/migrations/010_cuotas.sql` en SQL Editor de Supabase como postgres.
3. Integrar/publicar el frontend completo y recargar. El despliegue o git pull no ejecutan SQL.
4. Crear domingos de cobro y asignar el rol Subcapitán donde corresponda desde el editor.

La migración importa las cuotas antiguas una sola vez y mantiene sus fechas originales; no borra registros ni crea cuentas Auth. No volver a ejecutar schema.sql sobre producción. Instrucciones de uso, anticipos, preparación sin conexión y resolución de conflictos en [docs/CUOTAS.md](docs/CUOTAS.md).

Las migraciones 007–009 de asistencia permanecen vigentes. Revisar borradores históricos antes de cerrarlos; no borrar registros individuales para igualar contadores.

## Pruebas

Requiere Node.js moderno (probado con 24):

```bash
npm ci
npm run build
npm test
npm run test:ui
```

- `npm test`: PostgreSQL local en PGlite, esquema y migraciones reales, roles, privacidad, cierres completos, correcciones, versiones y límites del capitán, varios pases por día, aislamiento entre pases y exención de directiva sin borrar datos.
- `npm run test:ui`: requiere Chromium. Por defecto usa `/usr/bin/chromium`; se puede indicar `CHROMIUM_PATH`. Prueba la interfaz real con servicios simulados, incluyendo móvil, porcentajes y perfiles por rol. Las capturas se guardan en una carpeta temporal.
- Cuotas añade pruebas de importación repetible, ingresos/aplicaciones, anticipos, roles, conflictos, recarga con servidor desconectado y reintento tras respuesta perdida.
- Ninguna prueba utiliza la base de producción.

## Trabajo con Git

Trabajar sobre el último commit, preservar cambios del propietario, subir una rama y abrir PR. Informar qué se probó y qué migración debe ejecutar el propietario. No confundir cambios locales, push, merge y migraciones aplicadas.
