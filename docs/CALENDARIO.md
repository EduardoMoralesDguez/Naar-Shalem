# Calendario del club

## Activar esta versión

1. Con las migraciones 001–011 aplicadas, ejecutar `database/migrations/012_tipos_actividades.sql` en Supabase SQL Editor como postgres.
2. Si se quieren borrar las pruebas, ejecutar después `database/admin/limpiar_actividad.sql`. Es una operación independiente y destructiva; la migración 012 no limpia datos.
3. Integrar y publicar el frontend completo, incluido `sw.js`. Abrir el portal con conexión, esperar que descargue la actualización, cerrar todas sus pestañas/ventanas y volver a abrir.
4. Entrar en Inicio → Calendario con directiva.

Ni Git ni Vercel ejecutan SQL automáticamente. No volver a ejecutar schema.sql en producción.

## Tipos de actividad

El calendario muestra semanas de **domingo a sábado**. Las horas se interpretan en Ciudad de México.

| Tipo | Destinatarios | Asistencia | Cuota |
| --- | --- | --- | --- |
| Reunión regular | Todo el club | Pase propio; directiva exenta | $10 opcionales por reunión, cualquier día |
| Prácticas | Todo el club | No | No |
| Reunión parcial | Una unidad o una clase elegida | No | No |
| Evento | Todo el club, durante un rango de fechas inclusivo | No | No |

Las reuniones parciales son visibles para directiva y miembros de la unidad/clase indicada. No crean convocatorias de asistencia ni deudas. Los eventos aparecen en cada día del rango, también al cruzar de mes. Las prácticas quedan únicamente como avisos por ahora.

Directiva crea, edita, cancela y elimina. Los demás integrantes consultan los avisos que les corresponden. Todos los permisos se validan en SQL, además de ocultar controles en la interfaz.

## Reuniones regulares y cobros

Se pueden crear varias reuniones el mismo día con nombres distintos. Cada reunión con cobro genera **su propio período de $10**: mañana y tarde con cobro son dos cuotas. Ya no se agrupan por domingo ni por fecha. La lista de Cuotas identifica cada actividad por fecha, hora y nombre.

Los registros previos a 012 se conservan tal como estaban: la migración no convierte un cobro compartido antiguo en varias deudas. Se identifican como anteriores/compartidos. Si se ejecuta la limpieza opcional, se comienza sin estos registros y todos los cobros nuevos son por actividad.

La convocatoria conserva integrantes activos y unidades al crear el pase; excluye directiva. Las altas posteriores no se incorporan automáticamente. Solo conquistadores, capitanes y subcapitanes generan cuotas.

Ver asistencia abre el pase exacto de esa reunión. Directiva puede cerrarlo **antes de la fecha**, siempre que haya revisado y guardado todas las unidades. Los no marcados quedan con falta. Los capitanes/subcapitanes siguen pudiendo justificar únicamente una falta de su unidad el mismo día de la reunión, sin modificar una asistencia.

Las reuniones admiten fechas del ciclo activo, incluidas anteriores. Los cobros futuros admiten anticipos y no cuentan como vencidos en el dashboard. La creación y edición del calendario requieren conexión; después de programar reuniones hay que actualizar Cuotas para preparar los teléfonos.

## Editar, cancelar y eliminar

Nombre y hora se pueden corregir. Cambiar tipo o fecha exige un borrador sin unidades revisadas ni asistencia/justificación capturada. Un aviso puede convertirse en regular y obtener su pase; una regular sin captura puede convertirse en aviso, retirando su pase y liberando su cobro. Con registros de asistencia, se conserva el tipo/fecha o se elimina la actividad incorrecta.

Cancelar deja la tarjeta visible como Cancelada. Eliminar la retira del calendario, del pase y del historial; su asistencia deja de contar. La eliminación usa una marca interna para preservar la bitácora, impedir que un reintento la recree y evitar borrar ingresos. Una actividad eliminada no se restaura desde Asistencias; puede crearse otra con un identificador nuevo y el mismo nombre.

Al cancelar/eliminar una regular o desactivar su cobro, se liberan las aplicaciones de dinero de ese cobro y quedan como saldo a favor. Los ingresos se conservan. Restaurar una actividad cancelada o reactivar su casilla reutiliza su período y aplica saldo sin duplicar dinero. Los cobros independientes de otras actividades siguen vigentes. En cobros compartidos anteriores, el período sigue activo mientras otra actividad lo utilice; los cobros antiguos ajenos a Calendario no se cancelan automáticamente.

La migración conserva el control de versiones. Si otro dispositivo modifica la actividad, se pide recargar antes de sobrescribirla.

## Limpieza opcional de las pruebas

`database/admin/limpiar_actividad.sql` borra, en todos los ciclos:

- Actividades, convocatorias, revisión de unidades, asistencias y sus bitácoras.
- Períodos de cobro, cargos, ingresos, aplicaciones, saldos, operaciones y cuotas antiguas.

Conserva integrantes, cuentas Auth y vínculos, expedientes, unidades, clases, ciclos, especialidades y migraciones. No usa TRUNCATE CASCADE. La operación es transaccional y al terminar muestra conteos en cero.

Cerrar la app en todos los dispositivos durante la limpieza. El script cambia un identificador de generación: cualquier pago offline capturado antes del reinicio queda rechazado, aunque su número de versión coincida con una cuenta nueva. Así no se restauran accidentalmente pagos de prueba.

Después, abrir la versión actualizada con internet y actualizar Cuotas. Los pendientes de las pruebas borradas se descartan con Resolver registro; no se deben recapturar. No es necesario borrar indiscriminadamente el almacenamiento del navegador.

## Verificación

- `npm test`: esquema y migraciones reales en PGlite, permisos, siete días con cobro, dos cuotas en una fecha, cierre futuro, destinatarios, rangos, eliminación, saldo, limpieza e invalidación de colas antiguas.
- `npm run test:ui`: Chromium con interfaz real y servicios simulados; calendario domingo–sábado, formularios por tipo, móvil, eventos entre meses, eliminación, asistencia futura y cuotas offline de varias actividades.
- `npm run build`: regenera la versión del service worker. Repetirlo tras cualquier cambio del frontend.

Las pruebas no usan Supabase de producción.
