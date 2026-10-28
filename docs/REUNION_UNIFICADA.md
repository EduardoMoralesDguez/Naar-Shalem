# Rama de prueba: reunión unificada (022)

## Probar sin integrar main

Rama: `codex/reunion-unificada`. Requiere las migraciones hasta 021 y después `database/migrations/022_reunion_unificada.sql`. La migración es aditiva: incorpora RPC nuevas y una lista de unidades guardadas, sin reemplazar las RPC de 021 ni borrar históricos. La versión anterior puede seguir utilizando sus endpoints. Las capturas realizadas comparten los mismos datos, por lo que conviene probar con una base de pruebas si se van a registrar pagos ficticios.

Actualizar la rama, ejecutar `npm ci` y `npm run build`, y usar la publicación de prueba del frontend. Entrar con internet y pulsar Actualizar para preparar la reunión. No borrar IndexedDB si hay pendientes. Para comparar la interfaz anterior, volver a main; no hace falta deshacer 022. No se han ejecutado migraciones ni desplegado producción desde esta rama.

## Flujo

Competencia tiene tres entradas: Reuniones, Clasificación y Administración. Calendario enlaza directamente la captura de la actividad seleccionada. Los historiales financiero y de asistencia quedan como consultas secundarias de Administración; conservan correcciones, anticipos, bitácoras y capacidades anteriores.

La matriz permite seleccionar unidad y registrar:

- Asistencia A/J/F. Pendiente se distingue de una falta; Guardar unidad exige completar el pase de esa unidad.
- Importe recibido, en pesos, únicamente visible y editable por directiva. Se muestra lo aplicado a la cuota por separado. Recibir más dinero es posible aunque la cuota ya esté cubierta: el excedente permanece como saldo a favor. En actividades sin cobro no aparece esa columna.
- Criterios presenciales y puntos automáticos, con total. Falta/justificado deshabilitan los criterios presenciales; cuota y extras se conservan según las reglas existentes. Consejeros no tienen cuadernillo ni cuota.
- Extras individuales o de la unidad, con motivo.

Guardar unidad persiste asistencia, cobros y puntos en una sola transacción. Las demás unidades conservan sus datos. La unidad guardada recibe una marca ✓. Antes de cambiar de unidad hay que guardar los cambios actuales.

Cerrar reunión exige guardar todas las unidades y sincronizar pendientes. Cierra el pase, aplica los saldos disponibles al cobro pendiente y cierra puntajes en la misma transacción. Si falla una parte, no se confirma ninguna. La reapertura de puntajes habilita correcciones, conservando los controles y la auditoría existentes. Los cortes y cierre anual siguen bloqueando capturas hasta reabrirlos.

Los miembros no directivos consultan su unidad en la última reunión con puntaje cerrado y las abiertas, sin editar ni recibir importes financieros. Top 15, estadísticas, cortes y perfiles conservan sus reglas.

## Sin conexión y concurrencia

Se guarda un único intento por unidad pendiente, con UUID estable y versiones de reunión, hoja y cuentas de cuota. Se pueden guardar otras unidades sin conexión: se encolan con las versiones sucesivas del pase y de puntos. No se permite sobrescribir una unidad pendiente hasta sincronizarla. Los conflictos se conservan para revisión, sin duplicar cobros ni descartar trabajo automáticamente.

Tras sincronizar, se vuelven a preparar asistencia, cuotas y puntajes para que las consultas locales reflejen el mismo estado. Los intentos anteriores a una limpieza se rechazan por su época de datos. Cerrar requiere conexión.

## Verificación sugerida

1. Crear una reunión con cobro y otra sin cobro. Verificar la columna Cuota solo donde aplica.
2. Marcar A/J/F, criterios y dinero en una unidad; guardar y comprobar asistencia, ingreso y puntos.
3. Guardar otra unidad sin conexión y volver a abrir la pantalla; conectar y actualizar.
4. Probar un anticipo y recibir más dinero; comprobar saldo en el historial financiero.
5. Intentar cerrar sin guardar todas las unidades, completar las pendientes y cerrar.
6. Entrar como conquistador/consejero/capitán: solo consulta de su unidad y sin importes.
7. Reabrir y corregir; confirmar que el Top y el historial mantienen sus reglas.

Pruebas automatizadas: suites existentes de SQL e interfaz, `tests/reunion-unificada-sql.mjs` (migración repetible, guardado atómico, reversión por conflicto, reintento, cierre y permisos) y prueba Chromium de dos unidades sin conexión, cobro y sincronización. Build regenera el service worker.
