# Calendario del club

## Activar

1. Con las migraciones 001–010 aplicadas, ejecutar `database/migrations/011_calendario.sql` en Supabase SQL Editor como postgres.
2. Integrar y publicar el frontend completo. La rama incluye el service worker regenerado.
3. Abrir el portal con conexión y esperar que descargue la actualización; cerrar todas sus pestañas/ventanas y volver a abrir para activar la nueva versión de la PWA. No borrar IndexedDB si hay pagos pendientes.
4. Entrar en Inicio → Calendario con directiva.

No se recrean los datos que se hayan borrado. Se conservan integrantes, cuentas, permisos, reuniones y pagos existentes. La migración es repetible y no ejecuta schema.sql.

## Organizar actividades

- Elegir un día y pulsar Nueva actividad. Indicar nombre, fecha y hora de Ciudad de México.
- Se pueden programar actividades de hoy y futuras dentro del ciclo activo. Varias actividades en una fecha necesitan nombres distintos, por ejemplo, Camporee — mañana y Camporee — tarde.
- Toda actividad crea su propio pase. La convocatoria conserva los integrantes activos y unidades al momento de crearla, excluyendo directiva. Las altas posteriores no se incorporan automáticamente a convocatorias anteriores.
- En domingo se puede activar Cobrar cuota de $10. En los demás días la actividad lleva asistencia sin cobro semanal.
- Dos actividades con cobro en el mismo domingo comparten un único período de cuotas: no son $20. Los consejeros y directivos siguen exentos.
- El calendario mensual y la agenda muestran fecha, hora, estado y cobro. Los miembros autenticados consultan las actividades; solo directiva crea, edita o cancela.

## Registrar asistencia y pagos

Ver asistencia abre exactamente el pase de esa actividad, aunque sea futura. No se puede cerrar antes de su fecha. Los permisos de consulta y justificación se mantienen: capitán/subcapitán solo justifican faltas de su unidad el mismo día; no pueden cambiar una asistencia.

Asistencias y Cuotas conservan sus herramientas de registro/historial, pero sus botones de organización llevan al Calendario. Ver cuotas abre el módulo de cobro; seleccionar ahí el domingo correspondiente.

Las cuotas futuras admiten anticipos; no cuentan como semanas vencidas en el dashboard. Después de preparar actividades, los capturistas deben actualizar Cuotas con conexión para descargar cargos y lista antes de ir al club. La creación y edición del calendario requieren conexión.

## Editar y cancelar

Nombre y hora se pueden corregir. Cambiar fecha se permite solamente en un borrador de hoy/futuro que no tenga unidades revisadas ni asistencia/justificación capturada. Si ya se pasó lista, cancelar y crear otra actividad cuando corresponda; no mover silenciosamente los registros históricos.

Cancelar no borra la actividad: aparece Cancelada y su asistencia deja de contar. Si otra actividad sigue generando el cobro de ese domingo, la cuota permanece.

Si se cancela la última actividad con cobro (o se desactiva su casilla), el período gestionado por Calendario se cancela y sus aplicaciones se liberan. El ingreso no se borra ni se anula: queda saldo a favor del integrante. La bitácora conserva las aplicaciones anteriores. Los períodos cancelados dejan de contar en el dashboard. Los pendientes offline afectados deben revisarse si reciben un conflicto al sincronizar.

Reactivar el cobro de la misma fecha reutiliza el período y aplica saldo disponible sin duplicar ingresos. Al mover una actividad a otro domingo, si era el último cobro de su fecha, se libera y aplica el saldo al nuevo domingo. Restaurar el borrador desde Asistencias también reactiva su cobro; la interfaz pide confirmación.

Los domingos que ya existían antes de Calendario se conservan como cobros independientes. Vincular una actividad a uno no lo duplica; cancelar esa actividad no cancela automáticamente un cobro independiente anterior. Después de la limpieza que dejó todas las tablas en cero, todos los nuevos domingos organizados en Calendario siguen la regla de cancelación automática.

## Validación

`npm test` incluye casos de creación futura, permisos, reintentos sin duplicados, cuota compartida, cancelación/saldo, reactivación, cambio de fecha y migración repetible. `npm run test:ui` verifica calendario móvil/escritorio, formulario, edición, cancelación, enlaces al pase y regresión de cuotas offline y asistencias. Las pruebas no usan Supabase de producción.

Para cambios posteriores del frontend: ejecutar `npm run build` y subir el nuevo sw.js.
