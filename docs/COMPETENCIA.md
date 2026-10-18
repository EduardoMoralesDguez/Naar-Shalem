# Competencia (019)

## Actualización

Aplicar `database/migrations/019_competencia_resultados.sql` después de 018, desde SQL Editor de Supabase. Después desplegar el frontend. Abrir la app con internet, cerrar sus ventanas y volver a entrar. No borrar datos del sitio si existen asistencias o cuotas pendientes de sincronizar.

La migración conserva pagos, asistencias, criterios, capturas y cortes. Repara grupos faltantes del pase, incluido **Sin unidad**, y completa altas pendientes en reuniones abiertas desde hoy. No reabre automáticamente pases cerrados ni agrega integrantes a fechas anteriores a su ingreso. Las tablas privadas tienen RLS, sin acceso directo desde el cliente; las RPC verifican autenticación y permisos.

## Navegación y captura

**Competencia** abre cinco tarjetas: Asistencias, Cuotas, Puntos, Clasificación y Admin. Admin es exclusivo de directiva. Puntos muestra la matriz a directiva y el último puntaje privado al propio integrante. Asistencias mantiene A/J/F, guardado sin conexión y bitácora; Cuotas conserva sus permisos y funcionamiento.

En **Puntos**, directiva elige una reunión regular y una unidad, o **Sin unidad**. Matriz y Puntos extra están separados. Se guarda la captura completa de la reunión, incluyendo las otras unidades. Los extras requieren destinatario, cantidad y motivo; los grupales cuentan solo para la unidad.

Criterios iniciales: asistencia, cuota, Biblia, puntualidad, versículo, cuadernillo y limpieza, todos de 5 puntos. Directiva puede añadir criterios, cambiar valores y activarlos. Valores y reglas se fijan al primer guardado de cada reunión; cambiar configuración no reescribe capturas anteriores.

- Antes de guardar el pase de una unidad aparece un aviso no bloqueante. Se permiten marcas provisionales. El estado `falta` inicial no se considera todavía una ausencia confirmada.
- Al guardar el pase, falta o justificado dejan sin efecto los criterios presenciales, tanto en la matriz como en el cálculo del servidor. No hace falta cerrar toda la reunión. Una corrección posterior del pase vuelve a evaluar la elegibilidad mientras no haya corte; al guardar la matriz se conservan solo las marcas elegibles.
- Justificado puede recibir asistencia según la regla de esa captura. Falta no recibe asistencia.
- **Cuota y extras individuales se conservan aunque falte o justifique**, según la decisión del club. Cuota suma cuando el cargo está completamente cubierto; no aplica donde no haya cargo. Un anticipo suma cuando Cuotas lo aplica al cargo.
- Consejeros participan en asistencia y criterios manuales, excepto cuadernillo. No tienen cargo de cuota. Sus puntos aportan a su unidad y tienen una clasificación individual independiente, exclusiva de directiva.
- Sin unidad obtiene puntos personales. Asignarle una unidad después no traslada los puntos de las convocatorias anteriores. No se crea una unidad ficticia para competir.

Puntaje requiere conexión. Asistencia y Cuotas conservan sus colas locales por cuenta. Sincronizar esas colas y actualizar Competencia permite incorporar sus cambios. Guardar puntajes usa versiones de reunión, hoja y criterios, y UUID de operación para reintentos sin duplicar extras.

## Clasificación, estadísticas y privacidad

Directiva ve clasificación de unidades, conquistadores y consejeros, filtros de fechas y acumulado anual. Las unidades suman puntos individuales (incluidos consejeros) más extras grupales; no se normaliza por tamaño.

En **Admin → Estadísticas**, las tarjetas ordenan integrantes por puntos de cada criterio, incluyendo cuota, con opción de ver todos. Los consejeros tienen un apartado separado. Criterios sin puntos no producen ganadores.

Los demás integrantes ven únicamente resultados de un corte publicado durante las **72 horas siguientes a su cierre**:

- Unidades con sus puntos y clasificación.
- Hasta 15 conquistadores destacados, en orden aleatorio, sin posición ni puntaje total. En el límite de 15 se selecciona de forma estable por identificador y luego se mezcla la presentación.
- Líderes de cada criterio, con todos los empatados en primer lugar y sus puntos de ese criterio. Se excluyen cuota, extras y consejeros de estas estadísticas públicas.

Un aviso en Inicio enlaza a la publicación. La base de datos aplica la caducidad, incluso si se solicitan fechas distintas por RPC. El navegador también retira la publicación al vencer, aunque se pierda la conexión. Solo los miembros con sesión pueden consultar estos resultados; no se publica una página anónima en internet.

En el perfil, el puntaje del último corte permanece disponible para su titular y para directiva, aun después de las 72 horas. Los perfiles de otros integrantes no muestran ese total. El servidor rechaza consultas del puntaje ajeno.

## Periodos y cortes

**Admin → Cortes → Crear periodo** permite programar un mes o un rango personalizado del ciclo activo. No puede solaparse con otro periodo abierto o corte ya finalizado.

Directiva puede pulsar **Finalizar** desde que comienza el periodo, sin esperar a su fecha final ni al cierre de todos los pases/cobros. La confirmación indica que se fijan los puntos guardados hasta ese momento. Para incluir pagos, asistencias o puntajes pendientes, guardarlos y sincronizarlos antes de finalizar.

Si se finaliza anticipadamente, el corte termina en la fecha de hoy (Ciudad de México); las reuniones de días posteriores quedan fuera, aunque ya tengan capturas provisionales. Se conservan las fechas originalmente programadas en el periodo. Si termina después del último día previsto, el corte usa ese último día.

El corte guarda el desglose por criterio y las pertenencias históricas. No cambia si luego se corrige una asistencia, pago o asignación. Se bloquea la captura de esas fechas y no hay reapertura en esta versión. El acumulado anual combina cortes y capturas abiertas sin duplicarlos ni borrarlos.

Los cortes realizados con 018 conservan sus totales originales. Como no guardaban desglose por criterio, aparecen como histórico y no se inventan estadísticas ni publicaciones nuevas para ellos. La categoría histórica de sus miembros se obtiene del rol disponible al instalar 019; no existe un registro anterior de roles por captura.

## Presentación y pruebas

Nombres en la cabecera del perfil: blancos. Iniciales: fondo de su clase, con texto legible; directiva y personas sin unidad usan fondo negro. Las fotos se conservan. El resto de nombres mantiene el color de clase, salvo bitácoras y cabecera general. Integrantes se ordenan por Amigo, Compañero, Explorador, Orientador, Viajero y Guía; clases adicionales y sin clase quedan al final, con desempate alfabético. Las clasificaciones competitivas se ordenan por puntos.

Prueba manual sugerida:

1. Crear una reunión y después registrar un integrante sin unidad. Actualizar Asistencias y verificar su grupo.
2. Capturar criterios antes de pasar lista: aparece aviso y permite guardar.
3. Marcar a alguien como falta y a otro como justificado. Comprobar que se descartan criterios presenciales, conservando cuota/extras.
4. Revisar un consejero: cuadernillo deshabilitado; puntaje en su tabla y sumado a su unidad.
5. Crear un periodo que termine en el futuro y finalizarlo hoy. Revisar publicación, empates, cortes y acumulado anual.
6. Con otra cuenta, comprobar Top 15 sin posiciones, ausencia de Admin y del total de otro integrante. Revisar el propio perfil.

Validación automatizada: `npm test`, `npm run test:ui`, `npm run build`. `tests/competencia-resultados-sql.mjs` usa las migraciones reales, prueba instalación repetida, presencia, consejeros, Sin unidad, reintentos, cierre temprano, congelación, Top 15, empates, permisos y expiración. Chromium comprueba tarjetas, matriz, extras, colores, perfiles, estadísticas, navegación y móvil. No se utiliza producción.
