# Competencia (018)

## Activación

Aplicar `database/migrations/018_competencia.sql` después de 017, como postgres en Supabase; desplegar el frontend y abrir la app con conexión. Cerrar todas las ventanas de la PWA y volver a entrar para activar los archivos nuevos. No borrar datos del sitio con pendientes de asistencia/cuotas.

No modifica ni borra pagos o asistencias. Crea tablas privadas con RLS y RPC con validación de directiva. Asistencias pasa al módulo Competencia; se conservan su ruta, enlaces desde Calendario, marcado A/J/F y modo sin conexión.

## Captura

**Inicio → Competencia → Puntaje**. Solo directiva ve y utiliza la matriz de captura, Criterios, Cortes y Bitácora. Los permisos se verifican también en el servidor. Conquistadores, capitanes, subcapitanes y consejeros consultan resultados; el acceso a Asistencias mantiene sus permisos anteriores.

Elegir una reunión regular, marcar los criterios cumplidos y pulsar **Guardar puntajes**. Cada integrante convocado tiene una fila, con la unidad registrada en ese pase. Directiva no participa; consejeros sí participan en asistencia y criterios manuales, sin cargo de cuota. Se admiten varios pases por día. Las actividades de aviso, importadas, anuladas o eliminadas no admiten captura.

Criterios iniciales de 5 puntos: Biblia, puntualidad, versículo, cuadernillo, limpieza, asistencia y cuota. Directiva puede añadir criterios manuales, cambiar valores (0–10 000) y activarlos/desactivarlos. Los valores y reglas quedan fijados al primer guardado de cada reunión: los cambios de configuración se aplican a reuniones sin captura, sin reescribir puntajes previos. Las marcas y extras de una reunión pueden corregirse mientras su periodo no tenga corte.

- **Asistencia:** automática desde el pase cerrado. Inicialmente cuentan asistencia y justificado; directiva puede configurar si los justificados otorgan puntos para nuevas capturas.
- **Cuota:** automática cuando el cargo está cubierto. Solo aplica si existe cargo en esa actividad; aparece N/A cuando no corresponde. Un abono parcial no otorga el criterio. El saldo a favor cuenta cuando Cuotas lo aplica al cargo, normalmente al cerrar el cobro.
- Los automáticos se actualizan al consultar/actualizar resultados hasta el corte. Es necesario guardar la captura de Puntaje para incluir esa reunión; no se inventan marcas manuales.

**Puntos extra** permite elegir integrante o unidad, cantidad positiva y motivo obligatorio. Se presentan en una tabla con el motivo. Los extras individuales cuentan para el integrante y su unidad; los grupales cuentan solo para la unidad. Para corregir un extra, quitarlo, añadir el correcto y guardar la captura completa.

La unidad suma puntos individuales de sus integrantes más extras grupales, sin normalizar por cantidad de miembros. Sin unidad conserva puntos individuales pero no compite como una unidad ficticia. La pertenencia histórica procede del pase, por lo que una reasignación actual no mueve los puntos ya registrados.

## Resultados y cortes

Todos los miembros autenticados ven posiciones y puntos de unidades, y hasta 15 destacados individuales del periodo en orden aleatorio, sin puntos ni posición individual. Directiva ve la clasificación individual completa y ordenada, además del acumulado anual. En empates se comparte lugar; si hay empate en el límite de 15, la selección es estable por identificador y la presentación se mezcla.

Directiva realiza cortes **mensuales** o **personalizados** desde Cortes. Deben pertenecer al ciclo activo, no superar hoy y no solaparse con un corte anterior. Antes del corte deben estar guardadas las capturas, cerrados los pases y cerrados los cobros de las actividades incluidas. Los integrantes añadidos después de capturar obligan a actualizar y guardar la matriz antes del corte.

Cada corte guarda un resultado fijo por fecha, miembro y unidad. Muestra la unidad ganadora, o todas las empatadas; sin puntos no declara ganadora. El siguiente periodo comienza después del último corte. El acumulado anual suma los resultados cerrados y los puntos de periodos abiertos, sin duplicarlos ni borrarlos. Se guardan por ciclo; el visor de ciclos anteriores no forma parte de esta pantalla.

Los resultados cerrados no cambian aunque después se corrija una asistencia, se corrija/anule un pago o se cancele la actividad. No hay reapertura del corte en esta versión: revisar antes de confirmar. Una actividad con puntajes no puede cambiar de fecha o tipo desde Calendario, para no trasladar sus puntos a otro periodo.

## Conexión, versiones y registro

Puntaje requiere conexión. Asistencias conserva el guardado offline y puede abrirse desde Competencia aun sin internet. Las marcas de puntaje no guardadas permanecen solo en la pantalla; se advierte antes de salir. Un error conserva la captura para reintentar; los reintentos de la misma operación usan un UUID para no duplicar extras ni cortes. Se comprueban versiones de reunión, captura y configuración. Si otra persona cambia la lista o el puntaje, actualizar y revisar antes de guardar.

Bitácora registra autor, fecha y acción, con datos de operación privados en el servidor. Los nombres de integrantes conservan su color de clase en la matriz y resultados; la bitácora y cabecera de cuenta conservan sus colores normales.

## Prueba sugerida

1. Crear una reunión regular con cobro y otra sin cobro. Revisar que Cuota solo aplica a quienes tengan cargo.
2. Marcar Biblia y añadir un extra individual y otro grupal con motivos distintos. Guardar y consultar Resultados.
3. Cerrar asistencia: comprobar que sus puntos se suman. Hacer un pago parcial y luego completarlo: Cuota solo debe sumar al cubrirse.
4. Cambiar Biblia a 10 puntos; la captura ya guardada conserva 5, mientras una reunión sin captura usa 10.
5. Entrar con capitán o conquistador: no puede capturar ni consultar el orden/puntaje individual completo.
6. Cerrar todos los pases/cobros del rango y realizar un corte personalizado. Confirmar ganador, nuevo periodo y conservación del acumulado anual.

Pruebas automáticas: `npm test`, `npm run test:ui`, `npm run build`. PGlite verifica cálculos, exenciones, parciales, extras, configuración, idempotencia, cortes, acumulado, permisos y privacidad del Top 15. Chromium verifica matriz, extras, errores/reintento, configuración, cortes, roles, navegación y móvil. No se utiliza producción.
