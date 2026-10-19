# Competencia (020)

## Instalación

Ejecutar `database/migrations/020_competencia_integrada.sql` después de 019 en el SQL Editor de Supabase, y desplegar el frontend. La migración es repetible, conserva capturas y añade cierres anuales y archivo de reaperturas. No ejecutarla antes de las migraciones previas.

Abrir con internet, cerrar las ventanas de la PWA y volver a entrar. En Competencia, pulsar **Actualizar** antes de la reunión. No borrar los datos del sitio si hay movimientos pendientes.

## Navegación y captura

Asistencias, Cuotas, Puntos, Clasificación y Admin comparten las tarjetas de Competencia. Admin es exclusivo de directiva. Cuotas ya no aparece como entrada independiente en Inicio. El marcado A/J/F no cambia.

En **Puntos**, directiva elige reunión y unidad, incluyendo **Sin unidad**. La matriz por criterios lleva total general de la unidad visible; los extras están debajo, con destinatario, cantidad y motivo. **Por reunión** muestra integrantes por filas, reuniones por columnas y totales de fila, columna y tabla. La captura guarda la reunión completa, incluidas sus otras unidades.

Capitanes, subcapitanes, consejeros y conquistadores pueden consultar la matriz de su unidad, sin editar. Solo se ofrece la última reunión calificada y las posteriores sin calificar. Al calificar otra reunión, la anterior deja de estar accesible también por RPC. Quien no tiene unidad solo ve su propia fila. Los motivos de extras no se exponen en esta consulta, pero su cantidad suma al total.

Criterios iniciales: asistencia, cuota, Biblia, puntualidad, versículo, cuadernillo y limpieza, con 5 puntos. Directiva puede añadir criterios, cambiar valores y activarlos. La primera captura fija los valores y reglas de esa reunión; cambiar configuración no reescribe reuniones anteriores.

- Antes de guardar el pase aparece un aviso no bloqueante y se permiten marcas provisionales.
- Un pase guardado como falta o justificado descarta criterios presenciales. Justificado puede ganar asistencia según la regla configurada. Cuota y extras se conservan.
- Cuota suma cuando el cargo está totalmente cubierto y solo donde existe cargo. Un anticipo cuenta cuando se aplica al cargo.
- Consejeros participan, aportan a su unidad y tienen tabla individual aparte. No tienen cuadernillo ni cargo de cuota.
- Los puntos conservan la unidad de su convocatoria. Asignar posteriormente una unidad no traslada puntos obtenidos sin unidad.

## Sin conexión

**Actualizar** en Competencia sincroniza y prepara Asistencias, Cuotas y las matrices de Puntos accesibles a esa cuenta. Los botones de actualización antiguos de Asistencias y Cuotas se sustituyen por este acceso central. También prepara las reuniones nuevas del calendario; hay que abrir la aplicación con internet antes de salir.

Asistencias, cobros y capturas de puntos se guardan en IndexedDB, separados por cuenta y proyecto. Los puntos pendientes se conservan al cerrar la aplicación. La sincronización procesa primero asistencias, después cuotas y finalmente puntos, con identificadores estables para evitar duplicados. Si cambió la versión del pase, del puntaje o de sus criterios, se conserva el intento para revisión; no se sobrescribe la captura del servidor. Una reunión con puntaje pendiente debe sincronizarse antes de volver a guardarla.

Crear criterios y periodos, finalizar o reabrir requiere conexión y resolver puntajes pendientes. Los cálculos automáticos confirmados se actualizan desde el servidor al sincronizar. Los datos preparados no sustituyen una copia de seguridad ni permiten consultar información que el servidor no autoriza.

## Cuotas y privacidad

- Directiva conserva historial, bitácora, importes y saldos a favor.
- Capitán y subcapitán cobran su unidad en las reuniones del día de cobro vigente. Ven Aplicado ($10/$0, o el importe realmente aplicado si existe un pago parcial) y el total de esa reunión. No reciben ingresos históricos, aplicaciones ni saldos acumulados por RPC.
- Conquistadores y consejeros no reciben tablas de importes. En el progreso personal solo aparece el porcentaje de cumplimiento cuando corresponde.
- La tabla de cobro elimina el formato `10/10`. Saldo a favor solo aparece para directiva; el pie suma las columnas monetarias visibles.

Las restricciones se aplican en SQL y en la interfaz. Se retira el acceso de clientes a la tabla antigua `public.cuotas`. Las RPC privadas de compatibilidad no son invocables por miembros.

## Clasificación y publicaciones

Siempre hay un **Top 15 aleatorio** del acumulado del ciclo para los integrantes, sin puntos ni posición. Incluye a todos los empatados en el puesto 15, por lo que puede mostrar más de 15 personas. Solo participan puntuaciones positivas. No se aceptan filtros arbitrarios de usuarios no directivos para inferir resultados ocultos.

Directiva mantiene clasificación completa, filtros y estadísticas por criterio, con consejeros separados. Los puntos de unidad suman integrantes, consejeros y extras grupales, sin normalizar por tamaño.

Al finalizar un corte se publican durante **72 horas**:

- Unidades ordenadas con sus puntos.
- Top 15 ordenado con puntos, incluidos empates en el límite.
- Consejeros ordenados con sus puntos.
- Ganadores por criterio, incluidos todos los empatados en primer lugar. Cuotas y extras no aparecen en las estadísticas públicas.

Durante la publicación los perfiles individuales muestran el puntaje del corte. Después, ese puntaje solo lo consulta su titular o directiva. Los perfiles de unidad conservan su último resultado. El Top aleatorio continúa visible tras caducar las tablas publicadas. La caducidad se verifica en el servidor y en la pantalla de clasificación, también sin conexión. “Público” significa visible a los miembros con sesión; no hay una página anónima en internet.

## Cortes y ciclo anual

**Admin → Cortes** permite crear periodos mensuales o personalizados. No pueden solaparse con otro periodo abierto o finalizado. Directiva puede finalizar desde que empieza el periodo. Si lo hace antes, el corte termina en la fecha actual de Ciudad de México y no incluye reuniones posteriores.

El corte fija los puntos y pertenencias históricas; cambios posteriores de pagos o asistencias no alteran ese resultado. El acumulado anual combina cortes y capturas abiertas sin duplicar ni borrar puntos.

**Reabrir** retira la publicación, desbloquea las capturas y deja el periodo abierto con el rango efectivo que tuvo el corte. Se archiva el resultado anterior en la base de datos y se registra la acción en bitácora. Las capturas originales permanecen y sus criterios automáticos vuelven a calcularse. Los cortes antiguos de 018 conservan sus sumas al permanecer cerrados; no se inventan estadísticas por criterio que no se guardaron entonces.

**Finalizar ciclo** fija y publica el acumulado completo del año del ciclo activo, sin límite de tres días. **Reabrir ciclo** retira esa publicación y permite continuar; conserva cortes y capturas, sin reactivar publicaciones temporales anteriores. Sincronizar todos los dispositivos antes de finalizar: los datos pendientes en otros dispositivos no se pueden incluir hasta recibirlos.

## Presentación y validación

Las iniciales son siempre blancas. El círculo usa el color de clase; directiva y personas sin unidad usan negro. El nombre de directiva en el directorio es negro. La cabecera del perfil conserva nombres blancos; las fotos existentes se conservan. El directorio sigue el orden de clases.

Prueba manual:

1. Con directiva, actualizar Competencia y desconectar internet. Guardar un pase y una matriz; cerrar y volver a abrir. Reconectar y actualizar; verificar pendientes y totales.
2. Con capitán, cobrar su unidad y comprobar el total, sin Historial ni Saldo a favor.
3. Con un conquistador, ver la última matriz de su unidad sin poder editar. Calificar una reunión posterior con directiva y comprobar que sustituye a la anterior.
4. Revisar Por reunión y su total general. Comprobar que extras individuales suman y extras grupales pertenecen a la unidad.
5. Finalizar un corte, revisar las tablas y perfiles, y reabrirlo. Confirmar que las capturas siguen presentes.
6. Finalizar y reabrir el ciclo; verificar que la publicación anual aparece y se retira.

Validación automatizada: `npm test`, `npm run test:ui`, `npm run build`. Las pruebas usan PGlite y Chromium locales, sin producción; cubren migraciones repetidas, permisos, empates, reuniones visibles, publicaciones, reaperturas, navegación, captura local, sincronización y móvil.
