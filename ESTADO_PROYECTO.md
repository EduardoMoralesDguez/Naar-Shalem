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

- Las reuniones regulares y sus pases se crean desde Calendario, en cualquier fecha del ciclo activo. Los otros tipos son avisos sin asistencia. Asistencias abre el pase de hoy/último día disponible o el pase concreto enlazado desde Calendario; los botones permiten elegir entre pases del día.
- Cada asistencia se identifica por reunión e integrante, no por fecha. Corregir o anular un pase no afecta a otro del mismo día.
- Pase en tabla con botones A/J/F; todas las unidades y “Sin unidad” deben revisarse antes de cerrar. Los no marcados quedan con falta.
- Historial: matriz de integrantes por fecha y nombre del pase, A verde/J amarilla/F roja y porcentaje `(A + J) / registros`. “—” significa no convocado y no cuenta como falta.
- Solo reuniones cerradas cuentan en la matriz y el dashboard. Directiva puede cerrar antes de la fecha después de revisar todas las unidades. Las eliminadas no cuentan.
- Directiva filtra por unidad y edita celdas con control de versión. Los borradores y reuniones anteriores se administran desde Historial.
- Capitán: solo convierte F en J para su unidad durante el mismo día, sin aprobación. No puede cambiar una A existente. Se valida en SQL con `America/Mexico_City`.
- Consejero: consulta de su unidad. Conquistador: consulta propia.
- La convocatoria conserva los integrantes y unidades de su creación; las altas posteriores no modifican automáticamente reuniones programadas anteriormente.
- La directiva está exenta de asistencia: no aparece en convocatorias, pases, matriz ni dashboard de asistencia de su perfil. Los registros anteriores se conservan, pero no se muestran ni cuentan. Los grupos vacíos de reuniones antiguas no bloquean su cierre.
- “Sin unidad” sigue disponible para integrantes sujetos a asistencia que no tengan unidad.
- Los directivos no muestran unidad/clase en tarjetas y perfiles. Solo conquistadores y capitanes muestran cuotas; los consejeros conservan únicamente asistencia.
- Las cuotas históricas se conservan. Esta iteración no elimina registros financieros ni amplía sus permisos.

## Cuotas por actividad

- Inicio → Cuotas registra pagos. Cada reunión regular con cobro tiene una cuota independiente de $10, cualquier día; varias reuniones en una fecha pueden tener varios cobros.
- Capitán y subcapitán registran cuotas completas de su unidad. Conquistadores solo consultan lo propio. Directiva cobra en cualquier unidad y administra abonos, anticipos, saldo, correcciones y anulaciones.
- Subcapitán es un rol explícito, seleccionable en el editor, con los mismos permisos de asistencia que capitán. Consejeros/directiva no generan cuotas.
- Libro privado de ingresos y aplicaciones en centavos. Un ingreso de $50 puede aplicarse a cinco cuotas, sin duplicar dinero.
- Escrituras exclusivamente por RPC transaccional, autorizada y auditada; UUID de operación para reintentos y versión por integrante/ciclo para evitar sobrescrituras de dos capturistas.
- IndexedDB mantiene la lista preparada y la cola por proyecto/cuenta. Service worker cachea únicamente archivos estáticos; SDK Supabase 2.49.8 servido localmente para no depender del CDN sin internet.
- Sincronización al abrir Cuotas con conexión, al recuperar red o pulsando el botón. No se garantiza ejecución con app cerrada. Conflictos se revisan explícitamente; nunca se sobreescriben automáticamente.
- Dashboard usa cuotas completamente cubiertas y actividades con cobro cuya fecha haya llegado. Total recibido incluye saldo a favor y excluye anulaciones.

## Calendario

- Semanas de domingo a sábado; horario de Ciudad de México.
- Reunión regular: pase para todo el club excepto directiva, cuota opcional de $10 por actividad cualquier día.
- Prácticas: aviso sin asistencia ni cuota.
- Reunión parcial: aviso para una unidad o clase elegida; solo lo ven esos destinatarios y directiva. Sin asistencia ni cuota.
- Evento: aviso para todo el club durante un rango inclusivo, visible también entre meses. Sin asistencia ni cuota.
- Directiva crea, edita, cancela y elimina. Eliminar retira la actividad del calendario/historial, preservando internamente la bitácora y el dinero recibido como saldo a favor. No se restaura una actividad eliminada.
- Tipo/fecha solo cambian si no hay pase capturado ni unidades revisadas. Nombre/hora se pueden corregir. Versiones y UUID evitan sobrescrituras y duplicados.
- Las convocatorias reflejan integrantes/unidades al crear la reunión; las altas posteriores no se agregan automáticamente.
- Los cobros compartidos anteriores a 012 se preservan sin generar deudas adicionales. Todos los nuevos cobros son independientes por actividad.
- El calendario requiere conexión. La cola offline de Cuotas admite pagos completos de varias actividades para una persona; se sincronizan en orden y un conflicto bloquea los siguientes de esa persona.

## Ajustes visuales

- Interfaz con textos breves, sin explicaciones ni conteos redundantes en Calendario, Integrantes, Cuotas y Asistencias.
- Hora junto al título de cada actividad. En agenda mensual se conserva la fecha; los eventos conservan su rango.
- Última actualización de Cuotas dentro del aviso superior, con hora de Ciudad de México.
- Asistencias: Guardar, unidades revisadas con ✓ y pestaña seleccionada. Se conservan los selectores de pases del día.
- Estilos neutros con azul del club y acentos discretos. Los errores, estados vacíos y pagos pendientes siguen visibles.
- Esta revisión visual no necesita SQL; desplegar frontend y sw.js actualizados.

## Instalación del modelo de datos

1. Confirmar migraciones 001–011 aplicadas.
2. Ejecutar `database/migrations/012_tipos_actividades.sql` como postgres en Supabase SQL Editor.
3. Opcional, solo para borrar pruebas: ejecutar `database/admin/limpiar_actividad.sql` después de 012. Borra reuniones, asistencias y todos los datos financieros, en todos los ciclos; conserva integrantes, cuentas, expedientes e insignias. No se ejecuta automáticamente.
4. Integrar/publicar el frontend y sw.js. Abrir con conexión para descargar la PWA, cerrar todas sus ventanas y volver a abrir.
5. Actualizar Cuotas. Si se limpió la base, los pendientes anteriores quedan rechazados por generación y deben descartarse como pruebas mediante Resolver registro.

La migración es repetible y conserva los datos; no genera semillas ni cuentas Auth. No ejecutar schema.sql en producción. El despliegue o git pull no ejecuta SQL. Guías: [Calendario](docs/CALENDARIO.md) y [Cuotas](docs/CUOTAS.md).

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


## Cuotas: cierre por unidad y navegación (013)

Aplicar `database/migrations/013_cierre_cuotas.sql` después de 012 y desplegar el frontend. Conserva ingresos; revisar los cobros actuales y pendientes offline tras la actualización. Ver `docs/CUOTAS.md` para la conversión de anticipos existentes.

Cobro, Historial (unidad/integrante) y Bitácora separados. Bitácora exclusiva de directiva. Capitán/subcapitán cobran y cierran su unidad; directiva cualquiera. Saldo anterior se aplica al cierre, no al crear reunión. Captura offline preservada; cierre con conexión y sin pendientes. Un solo botón Actualizar sincroniza y prepara el dispositivo. Test adicional: `tests/cuotas-cierre-sql.mjs`.

## Organización (014)

Nuevo módulo en Inicio: Unidades, Clases, Asignaciones y Ciclos. Aplicar `014_organizacion.sql` después de 013. Roles y decisiones actuales se documentan en `docs/ORGANIZACION.md`: un capitán y un subcapitán, identidad propia editable por líderes, asignaciones solo directiva, inscripciones anuales privadas con proyección compatible en usuarios. El cambio de ciclo es explícito, conserva datos y archiva asignaciones; no activar otro año solo por instalar la migración.

Limpieza solicitada de pruebas: `database/admin/limpiar_cuotas_asistencias.sql` borra pagos/saldos/asistencias de todos los ciclos, conserva calendario y reinicia pases/cobros. No ejecutada automáticamente. El antiguo `limpiar_actividad.sql` también borra calendario; son scripts distintos.

Siguiente iteración según DOCX: cuadernillos y tareas por clase. Aún pendientes: especialidades completas/biblioteca, retos temporales, turnos de programa/push, preinscripción/mapa, visor histórico integral. No confundir el archivo de asignaciones de Organización con el archivo histórico completo.

## Ajuste visual y perfiles de unidad (015)

Calendario sin textos explicativos del formulario, menú Integrantes sin descripciones redundantes y acceso al calendario en Asistencias igual al de Cuotas. Se quitó el aviso visible previo al cierre sin cambiar validaciones.

Unidades ahora son tarjetas que abren un perfil con foto, lema, porra, integrantes y porcentaje agregado de asistencia. Edición dentro del perfil con permisos de unidad existentes. Requiere `015_perfiles_unidades.sql` después de 014; solo actualiza la RPC de organización, no borra datos. Porcentaje A+J sobre convocatorias históricas de reuniones cerradas del ciclo, excluyendo directiva y reuniones borrador/anuladas/eliminadas. Resumen agregado sin exponer estados individuales.

## Asistencias offline y clases (016)

Aplicar `016_asistencias_offline_colores.sql` después de 015. Asistencias separa barra de conexión, pestañas, calendario y captura; mantiene A/J/F. Guardado local por cuenta/proyecto, sincronización con UUID estable y control de versiones, conflictos conservados y bitácora solo directiva. Cierre/anulación/restauración con conexión y sin pendientes. No amplía permisos ni el límite diario de justificación. Ver `docs/ASISTENCIAS.md`.

Clases tiene tarjetas y perfil con integrantes. Color hexadecimal editable por directiva; colorea solo nombres de miembros, excluyendo bitácoras y saludo/cabecera principal. La migración convierte los colores existentes y no borra registros. Scripts de limpieza opcionales actualizados para retirar también el registro de operaciones de asistencia.

## Altas en actividades programadas (017)

`017_altas_reuniones_pendientes.sql`, después de 016, incorpora nuevas altas a los pases regulares en borrador y a cobros de unidades sin cerrar desde el día del registro. Respeta exenciones, fechas anteriores y cierres independientes. Completa faltantes de actividades abiertas desde hoy para integrantes ya registrados; no borra ni aplica dinero. Bloqueos en orden 728401/728402/728403 y versiones de pase/cuenta protegen capturas desactualizadas. Prueba: `tests/altas-reuniones-sql.mjs`. Detalles en `docs/ASISTENCIAS.md`.

## Competencia (018)

Aplicar `018_competencia.sql` después de 017. Nuevo acceso Competencia: Puntaje por reunión, Asistencias (ruta y modo offline conservados), Resultados, Criterios, Cortes y Bitácora. Captura/configuración/cortes exclusivos de directiva con validación en servidor. Criterios iniciales de 5 puntos; valores fijados por reunión, manuales y automáticos desde asistencia/cuotas; extras individuales/grupales con motivo. Unidades suman puntajes sin normalización. Top 15 aleatorio sin puntos individuales para otros roles; directiva ve clasificación completa y acumulado anual. Cortes mensuales/personalizados congelan resultados sin borrar el año. Puntaje requiere conexión; detalles y pruebas en `docs/COMPETENCIA.md`. Retos temporales y reapertura de cortes permanecen pendientes.

## Competencia: presencia, consejeros y publicaciones (019)

Aplicar `019_competencia_resultados.sql` después de 018 y desplegar frontend. Cinco tarjetas de acceso; matriz por unidad y Sin unidad, extras separados; Admin agrupa criterios, cortes, estadísticas y bitácora. Pase pendiente permite calificación provisional; falta/justificado deshabilitan criterios presenciales, conservando cuota y extras. Consejeros sin cuadernillo y con tablas/estadísticas privadas, aportando a su unidad. Pertenencias de las convocatorias no se mueven al reasignar miembros.

Periodos programados se finalizan manualmente, incluso antes del fin previsto, congelando hasta hoy y excluyendo días futuros. Publicación autenticada por 72 horas con unidades, Top 15 aleatorio y líderes empatados por criterio (sin cuotas, extras ni consejeros). Perfil muestra último puntaje solo al titular/directiva. Acumulado anual intacto. Cortes 018 conservan totales sin inventar desgloses. Ver `docs/COMPETENCIA.md` para reglas de cierre y migración.

Nombres blancos en cabeceras personales, iniciales por color de clase (negro para directiva/sin unidad), listados por orden de clase. Prueba añadida: `tests/competencia-resultados-sql.mjs`; UI Competencia ampliada. Producción no modificada automáticamente.
