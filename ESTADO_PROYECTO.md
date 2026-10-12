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

- Las actividades y sus pases se crean desde Calendario, para hoy o fechas futuras. Asistencias abre el pase de hoy/último día disponible o el pase concreto enlazado desde Calendario; los botones permiten elegir entre pases del día.
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

- Inicio → Cuotas registra pagos. Los domingos de $10 se preparan desde Calendario activando cobro; varias actividades del día comparten una sola cuota.
- Capitán y subcapitán registran cuotas completas de su unidad. Conquistadores solo consultan lo propio. Directiva cobra en cualquier unidad y administra abonos, anticipos, saldo, correcciones y anulaciones.
- Subcapitán es un rol explícito, seleccionable en el editor, con los mismos permisos de asistencia que capitán. Consejeros/directiva no generan cuotas.
- Libro privado de ingresos y aplicaciones en centavos. Un ingreso de $50 puede aplicarse a cinco cuotas, sin duplicar dinero.
- Escrituras exclusivamente por RPC transaccional, autorizada y auditada; UUID de operación para reintentos y versión por integrante/ciclo para evitar sobrescrituras de dos capturistas.
- IndexedDB mantiene la lista preparada y la cola por proyecto/cuenta. Service worker cachea únicamente archivos estáticos; SDK Supabase 2.49.8 servido localmente para no depender del CDN sin internet.
- Sincronización al abrir Cuotas con conexión, al recuperar red o pulsando el botón. No se garantiza ejecución con app cerrada. Conflictos se revisan explícitamente; nunca se sobreescriben automáticamente.
- Dashboard usa cuotas completamente cubiertas y domingos transcurridos. Total recibido incluye saldo a favor y excluye anulaciones.

## Calendario

- Inicio → Calendario: mes, agenda, creación, edición y cancelación para directiva; consulta básica para miembros autenticados.
- Cada actividad tiene nombre, fecha/hora de Ciudad de México y un pase propio. Se permiten fechas de hoy/futuras del ciclo activo y nombres diferentes para mañana/tarde.
- Cobro opcional solo en domingo; se comparte el período de $10. Al cancelar el último cobro gestionado por calendario se liberan aplicaciones y queda saldo a favor, sin borrar dinero. Cancelar no afecta cobros independientes anteriores.
- Cambiar fecha exige borrador de hoy/futuro sin asistencia capturada/unidades revisadas. Reintentos de creación reutilizan el UUID; ediciones usan versión.
- Se conservan convocatorias con integrantes/unidades de su creación. No se incorporan automáticamente altas posteriores a actividades ya preparadas.
- El calendario requiere conexión. El modo offline continúa limitado a cuotas y exige actualizar la lista después de preparar actividades.

## Instalación de esta iteración

1. Confirmar migraciones 001–010 aplicadas.
2. Ejecutar `database/migrations/011_calendario.sql` en SQL Editor de Supabase como postgres.
3. Integrar/publicar el frontend completo. Abrir con conexión para descargar la nueva PWA, cerrar todas sus pestañas y volver a abrir. No borrar pagos pendientes del navegador.
4. Organizar actividades desde Inicio → Calendario.

La migración es repetible y conserva datos existentes; no vuelve a generar datos borrados ni crea cuentas Auth. No ejecutar schema.sql en producción. El despliegue o git pull no ejecuta SQL. Guías: [Calendario](docs/CALENDARIO.md) y [Cuotas](docs/CUOTAS.md).

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
