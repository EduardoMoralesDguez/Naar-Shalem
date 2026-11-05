# Validación de capitanes, abonos, fotos y panel

## Preparar la rama

```bash
git fetch origin
git switch codex/capitanes-fotos-panel
git pull --ff-only
npm ci
npm run build
npm run check
npm test
npm run test:ui
python3 -m http.server 8080 --directory frontend
```

`test:ui` necesita Chromium; se puede indicar su ejecutable con `CHROMIUM_PATH`. No descartar cambios locales para cambiar de rama: guardarlos antes. Se puede publicar esta rama como Preview de Vercel con el mismo procedimiento del README.

**Base existente con 023:** ejecutar `database/migrations/024_capitanes_fotos.sql` completo en el SQL Editor de Supabase de pruebas. No ejecutar `supabase/schema.sql` encima de una base existente. Para una instalación vacía usar el maestro y seguir el README. La migración y la publicación del frontend son pasos separados; aplicar SQL antes de probar la interfaz.

Sincronizar capturas pendientes antes de actualizar; cerrar sesión y volver a entrar para refrescar el cargo. Tener cuentas de directiva, dos capitanes de una unidad (uno antes subcapitán), consejero, conquistador y alguien de otra unidad. Usar al menos dos unidades y reuniones de hoy, anteriores y futuras. Guardar los resultados de cada caso: aprobado/falló, rol, reunión y captura del error.

## Casos de aceptación

| Caso | Acción | Resultado esperado |
| --- | --- | --- |
| Conversión | Antes de SQL anotar UUID y registros del subcapitán; después volver a entrar. | Mismo perfil/cuenta, ahora Capitán. Clase, unidad y movimientos intactos. No hay opción Subcapitán en formularios nuevos. |
| Dos capitanes | Directiva mantiene dos capitanes activos en una unidad e intenta asignar un tercero. | Dos permitidos; tercero rechazado. Revocar uno permite nombrar su reemplazo. |
| Identidad | Ambos capitanes editan lema/porra/foto de su unidad. | Ambos pueden guardar; no pueden cambiar otra unidad, mover miembros ni administrar ciclos. |
| Cobro por capitán | Cada capitán cobra $10 en una reunión de hoy de su unidad y actualiza. | Un ingreso por pago, sin duplicación al recargar. No se muestra historial global ni saldo acumulado a capitanes. |
| Justificación | Capitán justifica una falta de hoy con motivo; intenta hacerlo en otra unidad o fecha. | Hoy/propia unidad permitido; otro alcance rechazado. No puede editar criterios manuales. |
| Captura directiva | Cambiar F a A, marcar criterios/cuota, guardar unidad, editar y volver a guardar. | F inicia con criterios bloqueados; A habilita los permitidos. Guardado queda tenue y editar lo reactiva. Reintentar no duplica cobros. |
| Cierre | Guardar todas las unidades y cerrar reunión. | Se cierran pase y puntaje; reapertura sigue las reglas actuales y conserva datos. |
| Lectores | Entrar como conquistador/consejero/capitán. | Solo matriz de su unidad y reuniones permitidas; Top 15 por clases. Sin Administración ni historial financiero global. |
| Abono | Directiva: Competencia → Admin → Historial financiero → Por integrante → seleccionar miembro → Registrar abono. Registrar $50 y seleccionar dos cargos pendientes de $10. | Un ingreso de $50; $20 aplicados y $30 de saldo. No registrar otra vez el mismo dinero en la matriz. El menú Admin permanece visible. |
| Saldo automático | Cerrar después una reunión con cargo pendiente de $10 de ese miembro. | Se aplica saldo según el cierre; no crea otro ingreso ni requiere botón Aplicar saldo. |
| Corregir/anular | Corregir el ingreso con motivo; después anular uno de prueba. | Aplicaciones, saldo, cumplimiento y puntos se recalculan según las reglas vigentes; queda bitácora. |
| Foto publicada | Subir `ana.webp` a `frontend/img/perfiles/`, publicar y abrir la URL `/img/perfiles/ana.webp`. Escribir esa ruta en Editar integrante y guardar. | La URL carga y la foto aparece al recargar el perfil. No se crea objeto en Supabase Storage. |
| Fotos anteriores | Editar un nombre sin tocar su foto antigua de Storage. | La foto permanece. «Quitar foto» la desvincula sin borrar el archivo. |
| Foto de unidad | Publicar `frontend/img/unidades/jaspe.webp` y vincularla en Editar unidad. | Aparece en la unidad; otra unidad no puede editarla. Una ruta `../foto.webp` es rechazada. |
| Navegación | Recorrer Inicio, Integrantes, Organización, Calendario y Competencia en computadora y teléfono. | Se marca la sección activa, sin desbordamiento de página; las tablas anchas desplazan dentro de su contenedor. Buscar filtra el menú. Menú móvil abre/cierra y Escape funciona. |
| Offline | Preparar datos con conexión, desconectar, capturar como directiva, recargar y reconectar. | Se conservan los pendientes de esa cuenta; sincronizar una vez sin duplicar. Capitanes siguen requiriendo conexión para cobrar/justificar. |
| Conflicto | Dos sesiones de directiva editan el mismo registro desde una versión anterior. | Se informa el conflicto; no se sobrescribe silenciosamente el último cambio. |
| Sesión y privacidad | Cerrar sesión, entrar como otra persona y abrir una ruta administrativa. | No se muestran datos privados ni pendientes ajenos. Verificar también llamadas RPC con sesión de otro rol, no solo botones. |

Las fotos estáticas tienen URL pública. No subir documentos privados, salud, domicilios ni archivos confidenciales a esas carpetas. Para cambiar una foto ya publicada usar un nombre nuevo y actualizar el vínculo, evitando cachés antiguos.

## Verificación automatizada realizada

- `npm test`: 13 suites SQL históricas, restauración/equivalencia del maestro, RPC y nueva suite de capitanes/fotos. Se verifican conversión repetible, versión del perfil, límite de dos, denegación del tercero, rutas inválidas y permisos de unidad/anónimo.
- `npm run test:ui`: calendario, organización y competencia en Chromium con servicios simulados. Incluye vínculo de foto sin upload, ausencia del cargo antiguo, menú móvil/escritorio y envío de abono desde el historial.
- `npm run build` y `npm run check`: generación PWA, sintaxis/imports y referencias estáticas.

Estas pruebas no se conectan a tu Supabase. Auth real, correo, despliegue Vercel, imágenes publicadas e instalación en teléfonos requieren los casos manuales anteriores. No se migraron ni eliminaron fotos existentes y no se ejecutó SQL en tu proyecto remoto.
