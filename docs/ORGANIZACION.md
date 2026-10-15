# Organización: unidades, clases, asignaciones y ciclos

## Activación

1. Integrar el PR y ejecutar `database/migrations/014_organizacion.sql` después de 013, como postgres en Supabase. No ejecutar `schema.sql` otra vez.
2. Desplegar el frontend completo. Abrir con internet, cerrar todas las ventanas de la PWA y volver a entrar para activar el service worker nuevo.
3. Entrar en **Inicio → Organización**. Este módulo requiere conexión.

La migración no inicia un ciclo ni borra integrantes. Si existen dos capitanes (o dos subcapitanes) en la misma unidad, se detiene con un mensaje: corregir esos cargos antes de reejecutarla. Admite un capitán y un subcapitán activos por unidad; la base protege el límite también al editar desde Integrantes.

## Pantallas y permisos

- **Unidades:** directiva crea, cambia nombre, lema y porra, carga foto y desactiva/reactiva. Para subir foto a una unidad nueva, guardarla primero y abrir Editar. Capitán, subcapitán y consejero de unidad pueden cambiar únicamente lema, porra y foto de su propia unidad. Todos los miembros autenticados consultan la identidad y el listado básico; no se incluyen salud, contactos ni finanzas.
- **Clases:** directiva administra el catálogo, nombre y color distintivo. El resto consulta sus integrantes. Los cuadernillos y tareas siguen pendientes para el siguiente módulo.
- **Asignaciones:** solo directiva. Busca al integrante y asigna unidad, clase y cargo. Un consejero puede tener simultáneamente una unidad y una clase. Seleccionar Conquistador revoca una capitanía. Los directivos no reciben asignaciones desde esta pantalla.
- **Ciclos:** solo directiva. Elegir un año posterior inicia el ciclo y archiva las asignaciones anteriores. El selector superior permite consultar el archivo de organización en modo de solo lectura.

Para desactivar unidad o clase, retirar antes sus asignaciones, incluidas las de integrantes inactivos. No se borran grupos con historial. Las fotos van al bucket privado `unidades-fotos`, ruta `<id_unidad>/<uuid>.webp`; se convierten y reducen antes de subir. No se permiten SVG ni sobreescritura de objetos. Los enlaces de lectura son temporales.

## Qué conserva el cambio anual

La identidad, cuenta Auth, fotos personales, expedientes e insignias mantienen sus IDs. La tabla privada `inscripciones` conserva unidad, clase, rol y estado por integrante/ciclo, con nombres de unidad y clase al archivarse. `usuarios` mantiene una proyección de la inscripción actual para compatibilidad con las RPC de asistencia, cuotas y perfiles; sus triggers actualizan la inscripción cuando se usa cualquiera de los editores.

El nuevo año comienza sin unidades creadas ni unidad/clase asignada a los miembros. Capitanes y subcapitanes vuelven a Conquistador; directiva y consejeros conservan su tipo de perfil, sin asignación. El catálogo de clases sigue disponible. Los integrantes inactivos siguen inactivos. No se copian cuotas, cargos ni asistencias al nuevo año.

Sincronizar los pagos de **todos los dispositivos** antes de iniciar ciclo. La app bloquea el cambio si la cuenta actual tiene pendientes locales; no puede detectar pendientes de teléfonos desconectados. El servidor rechaza operaciones de un ciclo anterior, conservándolas para revisión en el dispositivo.

El archivo nuevo muestra las asignaciones conocidas desde esta migración; no inventa inscripciones de años anteriores. Los registros históricos de asistencias y cuotas permanecen en la base. Su visor unificado por años, cierre de competencia y ganadores corresponde a la iteración de Historial, no a este módulo.

## Prueba sugerida

1. Con directiva, crear una unidad de prueba y una clase; asignar un conquistador a ambas.
2. Nombrar capitán y subcapitán. Intentar nombrar un segundo capitán: debe rechazarlo, incluso desde Integrantes.
3. Entrar con el capitán: editar lema/porra/foto de su unidad, sin ver controles para asignar miembros o editar otras unidades.
4. Verificar que los cambios aparecen en el directorio/perfil y que cuotas y asistencias siguen funcionando.
5. Abrir dos sesiones, editar el mismo registro y comprobar el aviso de versión al guardar desde la sesión desactualizada.
6. Probar un nuevo ciclo solo cuando quieras realizar ese cambio: se confirma explícitamente y no hay botón para regresar el año activo. Después revisar el ciclo anterior en el selector. Para pruebas repetidas del cambio anual, usar una base de pruebas.

## Limpiar cuotas y asistencias de prueba

`database/admin/limpiar_cuotas_asistencias.sql` es **opcional y destructivo**: borra pagos, saldos, asistencias y sus bitácoras en todos los ciclos. Conserva calendario, convocatorias, cargos de cuota, perfiles, unidades, clases, inscripciones e insignias. Las reuniones regulares cerradas vuelven a borrador y las marcas vuelven a falta pendiente; los cargos quedan sin pagar y sin cerrar. No ejecuta el pase ni genera ingresos nuevos.

Ejecutarlo como postgres después de 013, con las apps cerradas. El script cambia la generación de cuotas para rechazar pendientes offline anteriores. Al volver, usar Actualizar; descartar con Resolver registro solo los pendientes que correspondían a los datos de prueba borrados. Se devuelve un conteo final de cero asistencias guardadas, ingresos, aplicaciones y cuotas antiguas.

## Verificación

`npm test`, `npm run test:ui` y `npm run build`. Las pruebas nuevas usan PostgreSQL local (PGlite) para migración repetible, archivo, cargos únicos, versiones, RLS y limpieza; Chromium para rutas, formularios, permisos y móvil. No modifican producción.

## Perfiles de unidad (015)

Aplicar `database/migrations/015_perfiles_unidades.sql` después de 014. Las unidades se presentan como tarjetas con foto/nombre; al abrirlas se muestran lema, porra, integrantes enlazados a sus perfiles y asistencia conjunta. Editar unidad y desactivar/reactivar están dentro del perfil, con los mismos permisos anteriores.

La asistencia se calcula en el servidor: `(asistencias + justificados) / convocatorias de la unidad en reuniones regulares cerradas del ciclo`. Es un porcentaje ponderado por registros, no un promedio de porcentajes individuales. Usa la unidad guardada en cada pase, excluye directiva/exentos, borradores, anulaciones y actividades eliminadas. Sin registros muestra «—». Los usuarios reciben solo el resumen de unidad; no se amplían permisos para consultar asistencias individuales. Al corregir un pase, el resumen cambia al actualizar o volver a abrir Organización.
