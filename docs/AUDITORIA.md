# Auditoría y refactorización integral

Fecha de referencia: 3 de noviembre de 2026 (Ciudad de México). Base auditada: commit `478d048` de `codex/reunion-unificada`. Trabajo aislado en `codex/auditoria-integral`. No se ejecutaron modificaciones contra Supabase ni Vercel de producción.

## Alcance y fuentes

Se inspeccionaron los 106 archivos versionados iniciales, más el documento `1.docx` recuperado en adjuntos locales. Hay dos versiones locales: SHA-256 `e574386f0f0008e2d9243b0e691c4df9e4091ff8bb44be4fc4663e602aa6cfa5` (incluye 13 iteraciones) y `eac3643257c78779f86b9f25f271ac6832807c5a0af32a5eb1fc4e9f61f6b19c` (mismos requisitos, sin el apéndice de iteraciones). Se compararon ambos textos; no se incorporaron adjuntos privados al repositorio.

Los RF/RNF se desglosan por enunciado para no declarar completo un módulo que solo tiene una parte. Los IDs con decimal corresponden al orden del enunciado dentro del RF/RNF original. CU-01–12 corresponden a los doce casos de uso. LEV identifica requisitos adicionales del levantamiento o detalles operativos expresamente solicitados en la conversación. El diagrama ER es un modelo propuesto: sus tablas de tareas/retos no demuestran implementación. Las decisiones posteriores del usuario prevalecen en la implementación (Top 15 por clase, captura de puntos exclusiva de directiva, reunión integrada, capitán/subcapitán y cuotas por actividad), pero las diferencias frente al documento se indican.

## Arquitectura real e inventario

Frontend HTML/CSS/JavaScript ES sin framework; router hash en app.js; módulos de UI y servicios Supabase separados. Auth en cliente oficial UMD 2.49.8, PostgreSQL con RPC y RLS, buckets privados de fotos y URLs firmadas. PWA: manifest, service worker de recursos estáticos e IndexedDB por cuenta/proyecto. Vercel es publicación estática configurada fuera del repositorio. No existen Express activo, TypeScript, backend Node, funciones Edge, push ni dependencias de producción npm.

Dos dependencias npm de desarrollo, ambas utilizadas: PGlite (PostgreSQL real en WASM) y ws (control de Chromium por CDP). No se eliminaron ni actualizaron versiones de librerías. Hay 23 migraciones, un esquema histórico y cuatro scripts administrativos: 28 SQL históricos en total, no aproximadamente 30 instaladores independientes. Había dos archivos llamados README (raíz y vendor), además de siete documentos de estado/módulo; no siete README equivalentes.

## Plan aplicado y decisiones

1. Medir referencia con build, suites SQL y UI, sin editar datos ni secretos.
2. Restaurar esquema histórico en PGlite efímero con contrato mínimo de Auth/Storage y una cuenta fixture necesaria para 002. Extraer definiciones finales desde pg_catalog; no copiar secuencias de CREATE/ALTER/DROP.
3. Crear maestro para instalaciones vacías; comparar columnas/defaults, restricciones, funciones, índices, triggers, RLS y ACL. Conservar funciones de compatibilidad que siguen siendo llamadas por otras RPC.
4. Centralizar transporte RPC y creación segura de nodos de texto; retirar cálculo duplicado de progreso y CSS huérfano comprobado por referencias. Mantener vistas, rutas y lógica de negocio.
5. Consolidar instrucciones actuales en README y operación en un documento técnico; retirar documentos contradictorios de iteraciones antiguas. Mantener auditoría separada por su propósito verificable.
6. Reejecutar pruebas, documentar pendientes y dejar revisión en rama, sin merge/despliegue automático.

## Archivos eliminados, fusionados y reorganizados

| Archivos anteriores | Resultado y justificación |
| --- | --- |
| README.md raíz (UTF-16, instrucciones Express) | Reescrito en UTF-8 con arquitectura, instalación nueva/existente, Auth/Storage, Vercel, configuración y pruebas reales. |
| frontend/vendor/README.md | Información de origen, licencia y actualización fusionada en README raíz; licencia MIT y distribución intactas. |
| ESTADO_PROYECTO.md | Contenido útil integrado en README/OPERACION; cronología y pantallas viejas permanecen recuperables en Git. |
| docs/ASISTENCIAS.md, CALENDARIO.md, COMPETENCIA.md, CUOTAS.md, ORGANIZACION.md, REUNION_UNIFICADA.md | Fusionados en docs/OPERACION.md, resolviendo contradicciones según 023 y la interfaz actual; instalación común solo en README. |
| frontend/css/asistencias.css | Eliminado: solo lo incluía el generador del cache, sin HTML/import ni pantalla consumidora tras retirar el módulo. |
| frontend/js/services/{asistencias,cuotas,organizacion,competencia}.js | Sustituido manejo RPC repetido por lib/rpc.js, conservando timeout de 15/20 s, respuesta y error original. |
| frontend/js/services/catalogo.js | Retirado cálculo local de porcentajes no usado con registros; progreso sigue viniendo de RPC. Respaldo vacío de cuotas conserva la misma estructura. |
| frontend/js/modules/{competencia,cuotas}.js | Unificada creación de nodos con textContent en lib/dom.js, sin modificar estilos ni eventos. |
| scripts/lib/database.mjs, consolidar-schema.mjs | Herramienta local de reconstrucción y extracción de catálogo final; sin conexión remota. |
| supabase/schema.sql | Único instalador nuevo, con guardia contra ejecución sobre tablas existentes. |
| tests/schema-consolidado.mjs, rpc.mjs; scripts/verificar-proyecto.mjs | Validación de equivalencia/operación, transporte RPC, sintaxis/imports/assets. |
| .gitignore, package.json, frontend/sw.js | Artefactos locales work/ ignorados; ES modules explícitos; comandos de validación; cache regenerado. |

No se movieron ni borraron las migraciones históricas: las suites dependen de ellas y sirven para bases existentes. Tampoco se eliminaron tablas antiguas ni RPC de compatibilidad: no tener un botón no prueba que una función esté sin uso. No se tocó js/config.js, los secretos ni valores de conexión.

## SQL consolidado y dependencias

El maestro contiene el estado final de **40 tablas, una vista y 79 funciones**. No contiene datos de personas, pagos, asistencia, vínculos Auth ni bitácoras ficticias. Incluye catálogos, criterios, ciclo inicial del año vigente, marcadores de migración y buckets privados. Supabase proporciona Auth, Storage, roles y auth.uid; el maestro no sustituye esos servicios. No se necesitan extensiones de aplicación; UUID usa función nativa.

Orden: precondiciones/transacción → tablas finales → funciones (check_function_bodies desactivado durante restauración para dependencias circulares) → defaults/constraints/FK → índices/vista → semillas → triggers → RLS/policies → grants/revokes → recarga PostgREST. La equivalencia se verifica después, y un flujo real invoca las funciones restauradas. Los CHECK de arrays varchar pueden redistribuir casts al restaurar; el comparador normaliza exclusivamente esa diferencia de representación. Las restricciones NOT NULL se representan como nulabilidad de columna para no requerir sintaxis nueva de PostgreSQL 18.

| Origen histórico | Responsabilidad final/dependencia |
| --- | --- |
| 001_cuentas_y_datos_privados.sql | Separación de cuentas, contacto y salud; requiere esquema base. |
| 002_login_rls.sql | Login/RLS; en flujo histórico exige directiva previamente vinculada. |
| 003_directorio_compartido.sql | Directorio compartido y especialidades visibles. |
| 004_administrar_integrantes.sql | CRUD de integrantes, validaciones y versiones. |
| 005_portal_y_fotos.sql | Portal/fotos; depende de Storage. |
| 006_asistencias.sql | Primer control de asistencia. |
| 007_reuniones.sql | Reuniones y convocatorias. |
| 008_matriz_asistencias.sql | Matriz y revisión por unidad. |
| 009_pases_por_reunion.sql | Pases independientes por reunión y justificación. |
| 010_cuotas.sql | Ledger de cuotas, cargos, ingresos, aplicaciones e idempotencia. |
| 011_calendario.sql | Calendario relacionado con pase y cuota. |
| 012_tipos_actividades.sql | Tipos de actividad, rangos, destinatarios y cobro por actividad. |
| 013_cierre_cuotas.sql | Cierre de cobro por unidad y aplicación de saldo. |
| 014_organizacion.sql | Organización, inscripciones históricas, ciclos y cargos. |
| 015_perfiles_unidades.sql | Perfiles de unidad y resumen de asistencia. |
| 016_asistencias_offline_colores.sql | Cola de asistencia, época de datos y colores hex. |
| 017_altas_reuniones_pendientes.sql | Altas posteriores en reuniones pendientes. |
| 018_competencia.sql | Criterios, hojas, extras, competencia y cortes. |
| 019_competencia_resultados.sql | Resultados, consejeros y publicaciones. |
| 020_competencia_integrada.sql | Privacidad, integración y reaperturas. |
| 021_cierre_puntajes.sql | Cierre de puntajes y lectura de última cerrada. |
| 022_reunion_unificada.sql | Guardado/cierre unificado transaccional. |
| 023_captura_capitan.sql | Panel y acciones limitadas de capitán. |

Las cuatro utilidades de database/admin quedan fuera del maestro: dos vinculan cuentas manualmente; dos limpian registros de prueba y son destructivas. No son duplicados de instalación y requieren una decisión administrativa independiente. El maestro no se ejecutó en un proyecto alojado; la prueba usa contrato mínimo de Auth/Storage, no certifica email ni subida real.

## Matriz de cumplimiento después de refactorizar

**Implementada** significa flujo conectado comprobado por SQL y/o UI local indicada, no certificación de producción. **Parcialmente implementada** señala operaciones o permisos faltantes. **No implementada** requiere ausencia de operación funcional tras buscar UI, servicios y SQL. **Pendiente de verificación** conserva código existente sin adjudicarle funcionamiento no probado. Evidencia SQL se refiere a tests/*-sql.mjs; UI a las tres suites Chromium actuales. Los casos de uso agrupan RF, por lo que el total cuenta entradas evaluadas, no capacidades únicas ni horas de desarrollo.

| ID | Módulo | Funcionalidad | Estado | Observaciones/evidencia |
| --- | --- | --- | --- | --- |
| RF-01.1 | Usuarios | Altas, edición y baja lógica de miembros/unidades | Implementada | SQL organización y altas; UI organización/integrantes. La baja conserva históricos. |
| RF-01.2 | Usuarios | Expediente con salud, tutor, foto e historial de clases | Parcialmente implementada | Perfil básico, contacto y salud privados; foto Storage conectada. Falta historial académico de clases cursadas. |
| RF-01.3 | Preinscripción | Formulario, bandeja y conversión a integrante | No implementada | No hay tabla, RPC ni formulario de prospectos funcional. |
| RF-02.1 | Estructura dual | Asignación simultánea de clase y unidad | Implementada | organizacion_guardar e integrantes_guardar; suites organización y altas. |
| RF-02.2 | Estructura dual | Nombrar y revocar hasta dos líderes por unidad | Implementada | Regla vigente: un capitán y un subcapitán; índices y pruebas de unicidad. Sustituye dos capitanes iguales del documento. |
| RF-03.1 | Asistencia | Captura y porcentaje por reunión | Implementada | Matriz unificada, asistencia_resumen; SQL asistencia y reunión unificada; UI Competencia. |
| RF-03.2 | Tesorería | Cuota, cumplimiento (meta 70%) y puntos automáticos | Implementada | Cuota de $10 por actividad activada, no por semana; SQL cuotas/cierre y Competencia. |
| RF-03.3 | Asistencia | Justificación según rol y porcentaje | Parcialmente implementada | Directiva y capitán del día comprobados; consejero no justifica; subcapitán no tiene acción en matriz 023. Se preservó esta diferencia. |
| RF-04.1 | Competencia | Criterios individuales configurables | Implementada | Parámetros y snapshots, solo directiva según decisión posterior; SQL y UI Competencia. |
| RF-04.2 | Competencia | Puntos de unidad: individuales más extras grupales | Implementada | Pruebas SQL de detalle, pertenencia histórica y extra con motivo. |
| RF-04.3 | Competencia | Cortes de periodo y acumulado anual | Implementada | SQL resultados/integrada/cierre; periodos y reapertura UI. |
| RF-04.4 | Competencia | Top 15 y tabla completa reservada | Implementada | Empates, orden por clase y aleatorio interno, publicaciones 72 h; SQL integrada y UI. |
| RF-04.5 | Retos | Retos con fechas, objetivo y barra de progreso | No implementada | No hay modelo/operaciones/pantalla de retos. Extras no equivalen a retos. |
| RF-05.1 | Académico | Panel separado de progreso académico y competencia | Parcialmente implementada | Hay puntaje, asistencia y cumplimiento; no hay barra de cuadernillo. |
| RF-05.2 | Académico | Consejero de clase asigna tareas y evalúa requisitos | No implementada | Sin requisitos, tareas, entregas ni asignación docente funcional. |
| RF-05.3 | Especialidades | Banda visual de insignias obtenidas | Pendiente de verificación | RPC especialidades_visibles y componente visual conectados; falta prueba actual específica de carga, privacidad y banda. |
| RF-05.4 | Especialidades | Otorgamiento individual/masivo de insignias | No implementada | Tabla y consulta existen; no hay operación de otorgamiento ni formulario. |
| RF-05.5 | Biblioteca | Descarga de materiales según especialidad | No implementada | Sin biblioteca, archivos autorizados ni políticas para materiales. |
| RF-06.1 | Calendario | Agenda interactiva para miembros | Implementada | Tipos, fechas, rangos, destinatarios y permisos; SQL calendario/tipos y UI. |
| RF-06.2 | Calendario | Asignar turnos de programa a unidades | No implementada | Destinatario de reunión parcial no es turno de dirección de programa. |
| RF-06.3 | Calendario | Recorrer automáticamente turnos cancelados | No implementada | Cancelación existe; no hay desplazamiento de programa. |
| RF-07.1 | Ciclos | Separar registros operativos por ciclo anual | Implementada | FK ciclo, snapshots y pruebas organización/competencia. |
| RF-07.2 | Ciclos | Nuevo ciclo sin asignaciones ni cargos de liderazgo | Implementada | Prueba SQL de archivo, reinicio y conservación; UI confirmación de ciclo. |
| RF-07.3 | Ciclos | Archivo histórico integral de ganadores y estadísticas | Parcialmente implementada | Inscripciones consultables por ciclo; registros conservados; falta visor integral de asistencia/cuotas/ganadores de ciclos pasados. |
| RF-08.1 | Seguridad | Directiva administra globalmente | Implementada | RPC SECURITY DEFINER con validaciones y RLS; pruebas de operaciones autorizadas y denegadas. |
| RF-08.2 | Seguridad | Consejero administra identidad, puntos preliminares y justificaciones | Parcialmente implementada | Identidad propia comprobada; puntos exclusivamente directiva por cambio aprobado; justificaciones no disponibles. |
| RF-08.3 | Seguridad | Consejero evalúa únicamente su clase académica | No implementada | Sin asignación de consejero de clase ni operaciones académicas. |
| RF-08.4 | Seguridad | Capitán administra identidad, pase preliminar y recordatorios | Parcialmente implementada | Identidad, cobro y justificación limitados; no pase preliminar ni mensajes. Matriz solo editable por directiva. |
| RF-08.5 | Seguridad | Conquistador consulta perfil, progreso y calendario | Implementada | RLS/RPC y UI por rol; además directorio básico compartido autorizado en sesiones previas. |
| RNF-01.1 | PWA | Captura sin conexión y consulta de requisitos | Parcialmente implementada | IndexedDB/captura integrada comprobados; requisitos académicos inexistentes; capitán cobra/justifica con conexión. |
| RNF-01.2 | PWA | Background Sync con aplicación cerrada | Parcialmente implementada | Cola, UUID y reintento con app abierta; no SyncManager/evento sync ni ejecución garantizada con app cerrada. |
| RNF-02 | PWA | Instalación en iOS/Android | Pendiente de verificación | Manifest y SW; falta prueba en dispositivos físicos y Safari/iOS. |
| RNF-03 | Interfaz | Diseño adaptable móvil y escritorio | Implementada | Chromium en ambos tamaños para calendario, organización y Competencia; no certificación universal de accesibilidad. |
| RNF-04 | Comunicación | Notificaciones push | No implementada | Sin suscripciones Push API, VAPID, service worker push ni emisor. |
| RNF-05.1 | Seguridad | Contraseñas mediante Supabase Auth | Pendiente de verificación | Cliente Auth real conectado; no pruebas de login/email/recuperación contra Supabase alojado en esta auditoría. |
| RNF-05.2 | Seguridad | RLS y validaciones del servidor | Implementada | Comparación de ACL/RLS maestro-histórico; pruebas PostgreSQL autenticado/anónimo y roles de negocio. |
| RNF-05.3 | Seguridad | Salud y contacto solo titular, consejero y directiva | Pendiente de verificación | Tablas privadas y RPC implementadas; falta suite negativa exhaustiva con consejero de otra unidad y asignación dual de clase. |
| RNF-06.1 | Rendimiento | Carga inicial menor de 3 s en 3G/4G | Pendiente de verificación | No se ha medido con throttling reproducible ni dispositivos reales. Preparación de todas las reuniones puede ser costosa. |
| RNF-06.2 | Rendimiento | Transiciones SPA instantáneas | Parcialmente implementada | Rutas cliente comprobadas; varias pantallas esperan RPC y preparación; no hay presupuesto de latencia validado. |
| CU-01 | Preinscripción | Captación y preinscripción completa | No implementada | Depende de RF-01.3 y permisos anónimos específicos todavía inexistentes. |
| CU-02 | Usuarios | Gestión de expediente completo | Parcialmente implementada | RF-01.1/2; falta historial de clases y pruebas reales de archivos/Auth. |
| CU-03 | Estructura dual | Organización y arranque anual | Implementada | RF-02.1/2, RF-07.2; probado en SQL y UI. |
| CU-04 | Estructura dual | Cultura e identidad de unidad | Implementada | Nombre/lema/porra y ruta de foto con permisos; pruebas organización. Transferencia real Storage requiere integración alojada. |
| CU-05 | Asistencia | Pase, justificación y porcentaje | Parcialmente implementada | Flujo directiva/capitán probado; alcance de consejero/subcapitán distinto al documento. |
| CU-06 | Tesorería | Cobro y privacidad financiera | Implementada | Pruebas SQL cuota/resumen/privacidad y captura unificada; no importes para lectores. |
| CU-07 | Competencia | Evaluaciones preliminares por consejero/capitán | Parcialmente implementada | Evaluación existe; por decisión posterior es exclusiva de directiva, sin etapa preliminar/aprobación. |
| CU-08 | Competencia | Competencia, cortes y retos | Parcialmente implementada | Motor de puntos/cortes/Top probado; falta RF-04.5. |
| CU-09 | Académico | Cuadernillos y tareas | No implementada | Depende de RF-05.2 y RF-08.3. |
| CU-10 | Especialidades | Insignias y biblioteca completas | Parcialmente implementada | Solo consulta visual conectada; falta otorgamiento, estados en curso y biblioteca. |
| CU-11 | Calendario | Agenda, turnos y recorrido | Parcialmente implementada | Agenda probada; turnos y desplazamiento ausentes. |
| CU-12 | PWA | Procesos offline, sincronización y push | Parcialmente implementada | Cola offline probada; envío con app cerrada y push pendientes. |
| LEV-01 | Usuarios | Cuenta individual y recuperación de contraseña | Pendiente de verificación | Cliente Auth implementado; creación/vinculación manual. Falta verificación de emails/redirect en proyecto alojado. |
| LEV-02 | Estructura dual | Perfiles de clase y color hexadecimal | Implementada | Organización SQL y UI; nombres por clase, excepciones de cabecera y bitácora. |
| LEV-03 | Competencia | Consejeros compiten aparte y aportan a unidad | Implementada | SQL resultados, exclusión de cuadernillo/cuota; clasificación y estadísticas diferenciadas. |
| LEV-04 | Competencia | Reabrir corte/ciclo y publicación temporal | Implementada | Pruebas SQL de reapertura, snapshots, expiración y UI de cortes. |
| LEV-05 | Usuarios | Directorio público de contacto del club | No implementada | Sin contacto/WhatsApp público específico. Login no equivale a directorio público. |
| LEV-06 | Calendario | Recordatorios de turno de programa | No implementada | No hay turnos ni avisos automáticos de programa. |
| LEV-07 | Mapa | Mapa de domicilios exclusivo de directiva | No implementada | Sin coordenadas, captura de domicilio geográfico ni pantalla/RPC de mapa. |
| LEV-08 | Especialidades | Especialidades en curso e impartidas por ciclo | No implementada | Relación de insignias obtenidas no modela curso/progreso/historial de impartición. |
| LEV-09 | Tesorería | Anticipos y correcciones de ingreso | Parcialmente implementada | Servidor conserva anticipos/corrección/anulación. Historial permite corregir/anular; entrada de anticipo quedó en pantalla de cobro oculta en refactor anterior. |
| LEV-10 | PWA | Resolución de conflictos sin pérdida/duplicación | Implementada | UUID, versión, época y cola por cuenta; pruebas SQL e interfaz de reintento y dos unidades offline. |

## Resumen ejecutivo y cálculo

Total: **61 entradas evaluadas** (RF desglosados, RNF, CU y adicionales del levantamiento).

- Implementada: **23**.
- Parcialmente implementada: **17**.
- No implementada: **15**.
- Pendiente de verificación: **6**.

Cumplimiento estricto: **23/61 = 37.70%**. Parciales y pendientes de verificación valen cero en este indicador; no se usan medias ponderadas inventadas. Los CU se cuentan como entradas explícitas, aunque dependan de RF; el resultado no debe interpretarse como porcentaje de código completado.

| Módulo | Evaluados | Implementados | Cumplimiento estricto |
| --- | ---: | ---: | ---: |
| Académico | 3 | 0 | 0.00% |
| Asistencia | 3 | 1 | 33.33% |
| Biblioteca | 1 | 0 | 0.00% |
| Calendario | 5 | 1 | 20.00% |
| Ciclos | 3 | 2 | 66.67% |
| Competencia | 8 | 6 | 75.00% |
| Comunicación | 1 | 0 | 0.00% |
| Especialidades | 4 | 0 | 0.00% |
| Estructura dual | 5 | 5 | 100.00% |
| Interfaz | 1 | 1 | 100.00% |
| Mapa | 1 | 0 | 0.00% |
| PWA | 5 | 1 | 20.00% |
| Preinscripción | 2 | 0 | 0.00% |
| Rendimiento | 2 | 0 | 0.00% |
| Retos | 1 | 0 | 0.00% |
| Seguridad | 8 | 3 | 37.50% |
| Tesorería | 3 | 2 | 66.67% |
| Usuarios | 5 | 1 | 20.00% |

Cobertura del levantamiento: estructura dual → RF-02/LEV-02; usuarios → RF-01/LEV-01/05; roles → RF-08; evaluación → RF-04/LEV-03/04; académico/especialidades → RF-05/LEV-08; asistencia/finanzas → RF-03/LEV-09; calendario/comunicación → RF-06/LEV-06; ciclos → RF-07; público → RF-01.3/LEV-05; offline → RNF-01/02/04 y LEV-10; mapa → LEV-07. Los doce casos de uso están listados individualmente. El apéndice de iteraciones no añade requisitos diferentes: 0/12 son validación/lanzamiento; 1/2 seguridad; 3/4 organización/miembros; 5/6 asistencia/tesorería; 7/8 académico/especialidades; 9 competencia/retos; 10 calendario/push; 11 prospectos/mapa.

## Faltantes, fallos previos y prioridades

| Prioridad | Tipo | Hallazgo real | Qué falta / siguiente desarrollo |
| --- | --- | --- | --- |
| Crítica | Verificación de seguridad | No se validó servicio Auth/Storage alojado ni todas las combinaciones de acceso a salud/contacto. | Proyecto de prueba, cuentas reales por rol/unidad/clase, peticiones manipuladas, expiración/revocación, URLs firmadas y recuperación de contraseña. No abrir RLS para facilitar pruebas. |
| Alta | Parcial / diferencia de rol previa | 023 solo habilita capitán en matriz; subcapitán no recibe los controles aunque existen permisos legados de cuotas. Consejero no justifica. | Confirmar matriz vigente y ampliar de forma explícita cliente + SQL + pruebas negativas, separado de refactorización. |
| Alta | Backend sin entrada funcional | Anticipos/abonos permanecen en RPC y en un formulario del cobro antiguo oculto. | Entrada explícita en Historial financiero, permisos directiva, importes, selección de actividades y prueba de saldo/cierre. |
| Alta | No implementada | Cuadernillos, tareas y consejero académico de clase. | Modelo requisitos/entregas/evaluaciones por ciclo; asignación docente; RPC/RLS dual y pantallas. |
| Alta | Backend parcial / frontend de lectura | Especialidades solo tiene consulta y banda; no alta/otorgamiento masivo ni estado en curso. | Catálogo administrable, operación transaccional de otorgamiento, autoría, ciclo y pruebas de permisos. |
| Alta | Parcial | Archivo anual integral. | Selector histórico de resultados/asistencia/cuotas y especialidades, preservar snapshots de pertenencia. |
| Media | No implementada | Biblioteca y acceso a PDFs. | Bucket privado, metadatos, autorización por inscripción/especialidad, descarga y caducidad. |
| Media | No implementada | Retos, metas, premios y barras. | Modelo de reto por fechas/ciclo, cómputo, publicación/revocación y pruebas de límites temporales. |
| Media | No implementada | Turnos, recorrido y recordatorios. | Asignaciones de programa independientes del destinatario del evento; desplazamiento transaccional sin duplicar. |
| Media | No implementada | Preinscripción y contacto público. | Formulario protegido contra abuso, prospectos privados, conversión idempotente y canal de contacto. |
| Media | No implementada | Push y Background Sync cerrado. | Suscripciones/VAPID/emisor, autorización y baja; diseñar recuperación offline compatible con iOS sin prometer ejecución garantizada. |
| Media | No implementada | Mapa privado. | Consentimiento/domicilio, coordenadas, RPC solo directiva, controles negativos y proveedor de mapa sin exponer ubicaciones al resto. |
| Media | Rendimiento por verificar | Abrir Competencia prepara todas las reuniones accesibles; puede aumentar consultas con el historial. | Medir RPC/bytes/latencia, paginar preparación o hacer incremental manteniendo versiones/época; probar 3G/4G bajo presupuesto. |
| Media | Pruebas adicionales | Banda de insignias, Storage real, accesibilidad completa e instalación iOS/Android. | Pruebas específicas y piloto; no marcar finalizado solo por screenshots Chromium. |
| Baja | Corregido en esta rama | README UTF-16 de Express y documentos que describían pantallas ya retiradas. | Consolidación realizada, sin cambiar producto ni credenciales. |
| Baja | Corregido en esta rama | Transporte RPC repetido, cálculo de porcentajes local sin uso real y CSS precacheado sin consumidor. | Extracción/remoción comprobada; suites conservadas y SW regenerado. |

No se encontró una pantalla completa de cuadernillos/retos/mapa sin backend: esos módulos están ausentes, no simplemente desconectados. Los datos de insignias existentes sí tienen frontend de lectura; el faltante es administración. Auth/Storage están conectados, pero no se certificó su servicio alojado. Se conservaron reglas actuales aun cuando el documento pedía más facultades a consejeros.

## Validaciones ejecutadas y límites

- Referencia antes de cambios: npm test (13 suites SQL) y npm run test:ui (3 suites) pasaron. No se detectaron fallos de estas suites en la base de partida.
- Maestro: restauración en base nueva; equivalencia de catálogo de columnas/defaults, nulabilidad, funciones, FK/CHECK/índices, triggers, vista, policies y ACL de esquema/tabla/columna/función para anon/authenticated. Los nombres de constraints NOT NULL dependen de versión PostgreSQL; se verifica nulabilidad por columna.
- Maestro operativo: crear primera directiva/vincular Auth fixture, crear reunión regular, guardar unidad con asistencia/cuota/puntos, reintentar mismo UUID sin duplicar ingreso, cerrar y rechazar lectura anónima de miembros/salud. Reinstalación sobre base existente se rechaza sin borrar datos.
- RPC: datos devueltos, error original con code de conflicto, timeout y ausencia de reintentos automáticos de escrituras.
- Interfaz: suites Chromium de calendario, organización y Competencia con servicios simulados, captura offline, cola/conflicto, total, lectura por unidad, Top, reaperturas y pestaña financiera.
- Build, sintaxis JS, imports, referencias HTML y assets PWA. No aplica TypeScript. No se cambiaron versiones de dependencias.

Límites: no se desplegó Vercel, no se ejecutó el maestro en un Supabase alojado, no se probaron emails ni almacenamiento remoto, no se midió rendimiento con red móvil ni se certificó instalación en dispositivos físicos. PGlite sustituye roles/tablas mínimos de Auth/Storage, no sus servicios. No se ensayó restauración de respaldos de producción. El inventario no implica que todas las funcionalidades del documento estén construidas.

## Roadmap recomendado

1. **Cerrar seguridad e integración alojada.** Supabase de pruebas con maestro, primer acceso, correo/recuperación, subida/firma de fotos y matriz de acceso negativa. Resolver acciones de subcapitán/consejero y acceso a anticipos según decisión de negocio. Antes de finalizar: RLS, idempotencia, no fuga de datos y rollback de cobros.
2. **Completar académico y especialidades.** Primero asignación de consejero de clase y modelo por ciclo; después requisitos/tareas y otorgamiento. Biblioteca depende de especialidades/autorización. Antes de finalizar: consejero no evalúa otra clase, otorgamiento masivo atómico, progreso y acceso a archivos.
3. **Cerrar competencia e historial.** Retos depende de motor de puntos; archivo usa inscripciones/snapshots ya existentes. Pueden desarrollarse en paralelo con académico una vez estabilizado ciclo/permisos. Probar cortes/reaperturas, fronteras de fechas, cambio de unidad y acumulado sin doble conteo.
4. **Agenda y comunicación.** Turnos primero, recorrido después, recordatorios/push al final. Probar cancelaciones simultáneas, ausencia de duplicados, caducidad de suscripciones y permisos.
5. **Captación y mapa.** Pueden desarrollarse en paralelo como módulos aislados; prospectos con acceso anónimo limitado, mapa solo directiva. Probar abuso de formulario, conversión repetida y solicitudes no autorizadas de ubicación.
6. **Lanzamiento.** Medir carga/transiciones en 3G/4G, iOS/Android, accesibilidad, datos offline entre cuentas, actualización de SW y recuperación de backups. Cerrar pendientes de verificación solo con evidencia reproducible.

## Uso de la nueva estructura

Para nueva instalación: README → supabase/schema.sql → crear/vincular primera cuenta → configurar frontend → build/publicación estática. Para base existente con 023: no aplicar el maestro; esta rama no cambia esquema en producción. Las migraciones siguen disponibles para upgrades. Regenerar el maestro solo después de cambios SQL y comprobar equivalencia. El archivo es un snapshot instalable, no una segunda implementación de reglas editada manualmente.

<details><summary>Inventario completo inicial de archivos versionados</summary>

```text
.gitignore
ESTADO_PROYECTO.md
README.md
database/admin/limpiar_actividad.sql
database/admin/limpiar_cuotas_asistencias.sql
database/admin/vincular_cuenta.sql
database/admin/vincular_cuentas_prueba.sql
database/migrations/001_cuentas_y_datos_privados.sql
database/migrations/002_login_rls.sql
database/migrations/003_directorio_compartido.sql
database/migrations/004_administrar_integrantes.sql
database/migrations/005_portal_y_fotos.sql
database/migrations/006_asistencias.sql
database/migrations/007_reuniones.sql
database/migrations/008_matriz_asistencias.sql
database/migrations/009_pases_por_reunion.sql
database/migrations/010_cuotas.sql
database/migrations/011_calendario.sql
database/migrations/012_tipos_actividades.sql
database/migrations/013_cierre_cuotas.sql
database/migrations/014_organizacion.sql
database/migrations/015_perfiles_unidades.sql
database/migrations/016_asistencias_offline_colores.sql
database/migrations/017_altas_reuniones_pendientes.sql
database/migrations/018_competencia.sql
database/migrations/019_competencia_resultados.sql
database/migrations/020_competencia_integrada.sql
database/migrations/021_cierre_puntajes.sql
database/migrations/022_reunion_unificada.sql
database/migrations/023_captura_capitan.sql
database/schema.sql
docs/ASISTENCIAS.md
docs/CALENDARIO.md
docs/COMPETENCIA.md
docs/CUOTAS.md
docs/ORGANIZACION.md
docs/REUNION_UNIFICADA.md
frontend/css/asistencias.css
frontend/css/auth.css
frontend/css/calendario.css
frontend/css/competencia.css
frontend/css/cuotas.css
frontend/css/directorio.css
frontend/css/integrantes_admin.css
frontend/css/organizacion.css
frontend/css/perfiles.css
frontend/css/portal.css
frontend/css/style.css
frontend/img/LogoNS.png
frontend/img/especialidades/astronomia.png
frontend/img/especialidades/ejercicios_y_marchas.png
frontend/img/especialidades/nudos.png
frontend/img/especialidades/primeros_auxilios.png
frontend/img/login/portada.jpg
frontend/index.html
frontend/js/app.js
frontend/js/config.js
frontend/js/lib/captura-reunion.js
frontend/js/lib/colores.js
frontend/js/lib/competencia-nav.js
frontend/js/lib/consultas.js
frontend/js/lib/cuotas-local.js
frontend/js/lib/supabase.js
frontend/js/modules/calendario.js
frontend/js/modules/competencia.js
frontend/js/modules/cuotas.js
frontend/js/modules/especialidades.js
frontend/js/modules/integrantes-admin.js
frontend/js/modules/organizacion.js
frontend/js/modules/progreso.js
frontend/js/modules/usuarios.js
frontend/js/services/asistencias-offline.js
frontend/js/services/asistencias.js
frontend/js/services/auth.js
frontend/js/services/calendario.js
frontend/js/services/catalogo.js
frontend/js/services/competencia-local.js
frontend/js/services/competencia.js
frontend/js/services/cuotas.js
frontend/js/services/fotos.js
frontend/js/services/integrantes-admin.js
frontend/js/services/organizacion.js
frontend/manifest.webmanifest
frontend/sw.js
frontend/vendor/README.md
frontend/vendor/SUPABASE-LICENSE
frontend/vendor/supabase-2.49.8.js
package-lock.json
package.json
scripts/build-sw.mjs
tests/altas-reuniones-sql.mjs
tests/asistencias-offline-sql.mjs
tests/asistencias-sql.mjs
tests/calendario-sql.mjs
tests/calendario-tipos-sql.mjs
tests/calendario-ui.mjs
tests/competencia-cierre-sql.mjs
tests/competencia-integrada-sql.mjs
tests/competencia-resultados-sql.mjs
tests/competencia-sql.mjs
tests/competencia-ui.mjs
tests/cuotas-cierre-sql.mjs
tests/cuotas-sql.mjs
tests/organizacion-sql.mjs
tests/organizacion-ui.mjs
tests/reunion-unificada-sql.mjs
```
</details>
