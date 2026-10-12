# Cuotas del club

Desde la migración 012, cada reunión regular puede tener su propio cobro de $10, cualquier día, incluso varias veces en la misma fecha. Se prepara en **Inicio → Calendario**. Ver [CALENDARIO.md](CALENDARIO.md).

## Activar

1. Aplicar `database/migrations/010_cuotas.sql` en Supabase SQL Editor como postgres, después de 001–009, y después aplicar 011 y 012 para Calendario. No ejecutar otra vez schema.sql.
2. Integrar y desplegar el frontend en Vercel. Publicar la carpeta frontend completa, incluidos vendor, sw.js y manifest.webmanifest.
3. Entrar en Inicio → Calendario con directiva y crear reuniones regulares con cobro opcional. Cada reunión con cobro cobra $10; dos de la misma fecha son dos cuotas.
4. En Integrantes → Editar, asignar el rol Subcapitán y su unidad a quien corresponda. No se crean cuentas ni se reasignan perfiles automáticamente.

La migración es repetible y no borra las tablas anteriores. Importa una sola vez los registros de cuotas de conquistadores/capitanes: conserva fechas originales aunque fueran sábados, dinero recibido y pendientes. Los registros de directivos/consejeros permanecen en la tabla antigua y no generan nuevas obligaciones. Los pagos posteriores se administran desde las nuevas RPC; no editar public.cuotas para modificar este módulo.

## Durante el cobro

- Directiva prepara las fechas y puede cobrar en cualquier unidad, incluso desde su teléfono prestado. El autor del movimiento será la cuenta que tenga abierta.
- Capitán y subcapitán ven su unidad y marcan Recibí $10; ambos tienen los mismos permisos. Guardar pagos marcados conserva cada movimiento en el teléfono. Los integrantes sin marca siguen pendientes.
- Conquistadores solo consultan sus cuotas. Consejeros no registran ni generan cuotas.
- Un cargo parcialmente pagado lo completa directiva. Los capitanes solo registran cuotas completas sin pagos previos.
- El capitán ve todos los cobros de la fecha más reciente que no sea futura, identificados por nombre y hora. Un registro preparado sin internet puede sincronizarse después de la reunión; no se rechaza únicamente porque haya cambiado el día.

## Abonos, anticipos y correcciones

Directiva pulsa Abono / anticipo, indica el dinero recibido y selecciona las fechas que cubrirá. Se aplica de la fecha más antigua a la más reciente. Por ejemplo, un ingreso de $50 cubre cinco cuotas de $10 si se seleccionan esas cinco actividades. El remanente queda a favor del integrante; no se registra como otro ingreso.

Si todavía no están creados las actividades futuras con cobro, el saldo se aplica al crearlos. Para aplicar un saldo a actividades que ya existen, usar Aplicar saldo. La aplicación jamás supera el cargo ni el ingreso disponible. Las altas posteriores a una actividad preparada no generan automáticamente cargos retroactivos.

Corregir cambia el importe y recalcula sus aplicaciones originales. Anular deja el ingreso en el historial, libera sus aplicaciones y exige motivo. La bitácora conserva cuenta, fecha, acción, motivo y datos anteriores; no se borran ingresos. Si una corrección deja saldo libre, directiva puede aplicarlo a otras cuotas.

El dashboard cuenta como pagada una cuota completamente cubierta, no un abono parcial. El porcentaje usa solo las fechas de cobro ya transcurridas. El total recibido incluye anticipos y excluye anulaciones. No usa el número de reuniones de asistencia.

## Preparar el teléfono sin conexión

1. Desde la URL HTTPS de Vercel, iniciar sesión y abrir Cuotas con internet.
2. Pulsar Preparar / actualizar sin conexión y esperar la confirmación. La directiva debe haber agregado las fechas antes de que los teléfonos descarguen la lista.
3. Sin conexión, abrir la misma app/navegador y guardar los pagos. La pantalla indica Pendiente de sincronizar. El portal offline se limita a cuotas; expedientes y asistencia no se cachean.
4. Al volver a tener internet, abrir Cuotas con la misma cuenta. Se intenta sincronizar y también existe el botón Sincronizar pendientes. Esperar Todos los movimientos están sincronizados.

No se promete envío con la app cerrada. El guardado pertenece a ese dispositivo, navegador y cuenta: borrar sus datos, usar navegación privada o cambiar de dispositivo antes de sincronizar puede perder la copia local. La app solicita almacenamiento persistente cuando el navegador lo permite. Cerrar sesión conserva la cola separada por cuenta y muestra un aviso si falta sincronizar; para enviarla hay que iniciar sesión con su autor.

El modo offline necesita HTTPS o localhost. Live Server por HTTP desde la IP LAN del ordenador no ofrece service worker; para probar desde el teléfono usar Vercel. El navegador decide cómo ofrecer instalación; el guardado offline también funciona dentro de una pestaña compatible.

## Si dos teléfonos registran lo mismo

Cada movimiento lleva un UUID persistido antes de enviarse. Reintentar el mismo envío no duplica el ingreso, incluso si el servidor guardó el dinero y se perdió la respuesta. Además, cada cuenta de cuotas tiene una versión: si otro teléfono ya la modificó, el segundo envío se detiene para revisión, sin sobrescribir ni sumar dinero silenciosamente.

Revisar el historial actualizado antes de usar Resolver registro. Si ya aparece el dinero, quitar el intento local. Si no aparece, quitar el intento y volver a capturarlo con los datos actualizados (o pedir a directiva que lo haga). No resolver un aviso de conflicto registrando dinero adicional sin comprobarlo.

Se admiten varios pagos completos pendientes para el mismo integrante si pertenecen a actividades distintas. Se guardan y envían en orden, con versiones consecutivas; no se repite el mismo cargo. Si uno entra en conflicto, se bloquean también los posteriores de ese integrante para revisión. Los abonos, anticipos y correcciones requieren resolver/sincronizar sus pendientes anteriores. Otros integrantes pueden seguir registrándose.

La limpieza opcional cambia la generación de datos. Los pagos offline anteriores al reinicio se rechazan; actualizar la lista y descartar los pendientes de esas pruebas mediante Resolver registro. La migración por sí sola no invalida los pendientes anteriores ni borra dinero.

## Desarrollo y validación

- `npm test`: PostgreSQL local (PGlite), migraciones reales, roles, reintentos, anticipos, correcciones y conservación de datos.
- `npm run test:ui`: Chromium, servicios simulados, IndexedDB y service worker reales; prueba recarga con servidor desconectado, reenvíos, conflictos, cuentas separadas y móvil.
- `npm run build`: regenera sw.js y su versión a partir del contenido estático. Ejecutarlo después de modificar el frontend y subir el sw.js resultante. La entrega incluye el archivo ya generado y puede publicarse sin bundler.
- El service worker sirve una versión consistente del HTML y scripts. Después de publicar una actualización, cerrar las pestañas del portal y volver a abrir; una versión nueva espera a que termine de usarse la anterior.
- Solo se cachean recursos estáticos permitidos. La respuesta de Supabase no se guarda en Cache Storage: el módulo guarda en IndexedDB únicamente el perfil básico y los datos de cuotas autorizados, separados por proyecto/cuenta. Al sincronizar se revalidan sesión, rol y unidad en SQL.
- No se ejecutan migraciones ni pruebas contra producción automáticamente.
