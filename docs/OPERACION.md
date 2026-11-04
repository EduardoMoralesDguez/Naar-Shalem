# Operación y reglas vigentes

Referencia del código con migraciones 001–023. Instalación/configuración se describen únicamente en el README raíz. Este documento sustituye las descripciones de pantallas antiguas: Asistencias y Cuotas ya no son módulos de captura independientes.

## Identidad, organización y privacidad

Cada cuenta Auth se vincula a un integrante; perfil, cuenta y contraseña no son lo mismo. Salud y contacto están en tablas privadas. El directorio básico se comparte entre miembros autenticados, mientras que expedientes y finanzas usan RPC con alcance por rol. Los buckets privados entregan URLs firmadas, no enlaces públicos permanentes.

Clase y unidad son asignaciones independientes. Directiva crea/desactiva clases y unidades y asigna miembros. Hay un capitán y un subcapitán por unidad; índices y validaciones rechazan duplicados incluso mediante llamadas directas. Capitanes, subcapitanes y consejeros editan la identidad de su unidad dentro de los permisos actuales, sin mover integrantes ni modificar otras unidades. No hay módulo de consejero de clase académico.

Unidades tienen perfil, foto, lema, porra, integrantes y asistencia agregada. El porcentaje conjunto es `(asistencias + justificados) / convocatorias` de reuniones regulares cerradas del ciclo: ponderado por registros, no promedio de porcentajes. Usa la unidad histórica y excluye directiva, borradores, anulaciones y eliminadas. Sin registros muestra «—».

Clases tienen perfil e integrantes, sin competencia grupal ni porra. El color admite `#RRGGBB`; conversiones de nombres de colores se hicieron en 016, con azul como respaldo. Los nombres siguen el color de clase en directorios/matrices; cabecera personal blanca, iniciales blancas, círculo negro para directiva/sin unidad. Bitácoras y cabecera de cuenta no adoptan esos colores. Se preservan fotografías.

Nuevo ciclo: directiva elige año posterior y confirma; requiere conexión y no tener pendientes locales. Se archivan inscripciones, roles y nombres de agrupaciones. El nuevo ciclo no tiene unidades ni asignaciones de unidad/clase; capitanes/subcapitanes vuelven a conquistador, directiva/consejeros conservan rol y miembros inactivos siguen inactivos. No se copian cuotas ni asistencias. El archivo conserva lo conocido desde 014, sin inventar historia anterior. No hay todavía visor integral de todos los módulos por año.

## Calendario y convocatorias

Semana domingo–sábado; fechas y límites diarios en `America/Mexico_City`.

| Tipo | Destinatarios | Pase | Cobro |
| --- | --- | --- | --- |
| Regular | Club | Sí, directiva exenta | $10 opcionales por actividad |
| Prácticas | Club | No | No |
| Parcial | Una unidad o clase | No | No |
| Evento | Club, rango inclusivo | No | No |

Pueden existir varias reuniones/cobros el mismo día. Los cobros anteriores compartidos se conservan como legado; no se convierten retroactivamente en deudas independientes. Directiva crea/edita/cancela/elimina; los demás consultan destinatarios autorizados. No están implementados turnos de programa ni su desplazamiento automático.

Desde 017, altas y reactivaciones entran en reuniones pendientes elegibles: no pierden los cobros futuros ya programados. Se respetan cierres, fecha de inscripción y exenciones; no se reescriben reuniones cerradas. Las convocatorias y puntos conservan la unidad que correspondía al registro; asignar unidad después no traslada puntos anteriores sin unidad.

Nombre/hora se corrigen con versión. Cambiar tipo/fecha exige ausencia de capturas y reglas adicionales de Competencia. Cancelar mantiene el aviso; eliminar usa marca interna y lo retira del calendario/cálculos sin borrar ingresos. Liberar un cobro devuelve sus aplicaciones al saldo, conservando el ingreso. Reactivar reutiliza el período conforme a sus reglas. La versión impide sobrescribir cambios simultáneos.

## Captura integrada

Competencia ofrece Reuniones, Clasificación y Administración. Directiva selecciona actividad y unidad (incluida Sin unidad), registra A/J/F, cuota, criterios y extras. Calendario abre la reunión exacta. El valor inicial F bloquea criterios presenciales y nuevos cobros; A los habilita. Cambiar a F/J descarta marcas presenciales y cobro todavía no guardado, sin anular ingresos ni extras ya registrados. J puede sumar asistencia según configuración, pero no criterios presenciales.

La cuota es una casilla «Recibí $10», solo donde hay cargo. Cubierta aparece marcada y bloqueada. Consejeros no tienen cuota ni cuadernillo; sí compiten individualmente y aportan a su unidad. Criterios iniciales: asistencia, cuota, Biblia, puntualidad, versículo, cuadernillo y limpieza (5). Directiva cambia valores/activación o añade criterios. La primera captura fija valores y reglas para esa reunión.

Guardar unidad conserva asistencia, ingresos y puntos juntos; si falla una parte no se confirma ninguna. Otras unidades conservan sus capturas. La marca ✓ y botón tenue indican guardado; editar devuelve el botón al estado normal. Extras tienen destinatario, cantidad y motivo. La tabla Por reunión incluye totales por persona, reunión y general.

Cerrar reunión exige todas las unidades guardadas y pendientes sincronizados. Cierra pase, aplica saldo disponible y cierra puntajes en una transacción. Puede cerrarse anticipadamente si cumple las reglas. Reabrir puntaje habilita correcciones; si hay corte/ciclo finalizado se debe reabrir antes. Los criterios automáticos se calculan desde asistencia/cuota hasta fijar un corte.

Lectores ven la última reunión con puntaje cerrado y las abiertas de su unidad; sin unidad ven su propia fila. No reciben motivos privados de extras ni importes financieros. En 023 el capitán puede cobrar a su unidad el día de la reunión y justificar una falta registrada del mismo día con motivo de 3–500 caracteres, con conexión. No modifica una asistencia ni criterios/extras. El subcapitán conserva operaciones antiguas de servidor pero no estas acciones en la matriz nueva; es una limitación documentada, no corregida silenciosamente en esta refactorización.

## Tesorería

Las cantidades se almacenan en centavos. Un ingreso se distingue de su aplicación a un cargo. El remanente es saldo a favor, no ingreso nuevo. Crear una actividad no consume anticipos. Al cerrar su cobro se aplica saldo disponible de forma automática; se retiró el botón Aplicar saldo de la interfaz. Un abono parcial no cuenta como cuota cumplida. El porcentaje financiero usa cargos vencidos completamente cubiertos; no el número de reuniones sin cuota. Total recibido excluye anulaciones e incluye anticipos.

Historial financiero está dentro de Administración, con consultas por unidad/integrante, importes y corrección/anulación con motivo. Corregir recalcula aplicaciones; anular libera aplicaciones y deja el ingreso auditado. No se debe editar `public.cuotas` para cambiar pagos actuales: es compatibilidad histórica. Directiva recibe datos financieros completos; capitán solo lo necesario para el cobro de su unidad/reunión. Los demás consultan porcentajes autorizados.

Limitación previa: la RPC de abonos/anticipos existe, pero su entrada quedó en el panel de cobro antiguo oculto. Esta refactorización conserva esa capacidad del servidor y la registra como funcionalidad parcial; no inventa un flujo nuevo.

## Clasificación, cortes y publicaciones

Top 15 del ciclo siempre visible a miembros con sesión, incluyendo empatados en el límite y solo puntajes positivos. Sin publicación se muestran nombres sin posición/puntos, agrupados por clase en dos columnas; aleatorio dentro de cada clase. Directiva ve ranking completo, filtros y estadísticas de conquistadores/consejeros separados. La unidad suma puntos individuales, consejeros y extras grupales, sin dividir por tamaño.

Periodos mensuales o personalizados no se solapan. Finalizar antes de tiempo limita el corte a la fecha actual en Ciudad de México; excluye reuniones futuras. Los resultados fijan puntos y pertenencias históricas. El acumulado anual suma cortes y capturas abiertas sin duplicar ni borrar datos. Cortes legados sin desglose no inventan estadísticas.

Al finalizar se publican durante 72 horas las unidades ordenadas, Top 15 ordenado (empates incluidos), consejeros y ganadores por criterio con todos los empatados. Cuotas/extras no aparecen en estadísticas públicas. Perfil individual: después de publicación, solo titular/directiva ve su puntaje; unidad conserva su resultado. Público significa miembros autenticados, no visitantes anónimos. Caducidad se aplica en servidor y cliente, incluso en la clasificación sin conexión.

Reabrir un corte retira publicación, archiva resultado anterior y conserva capturas/rango efectivo para continuar. Finalizar ciclo publica acumulado anual sin límite de 72 h; reabrirlo retira esa publicación sin reactivar publicaciones temporales previas. Cambio de ciclo organizacional y finalización de competencia son acciones diferentes.

## PWA, conflictos y recuperación

Abrir con internet antes de la reunión prepara datos accesibles. El SW almacena archivos estáticos del mismo origen, nunca respuestas Supabase. IndexedDB conserva datos operativos por cuenta/proyecto. Guardar es necesario: marcas no guardadas solo viven en pantalla. La sesión recordada permite el acceso offline restringido; el servidor revalida permisos al enviar.

Preparación al entrar y reintento al recuperar conexión con la app abierta. No hay Background Sync con la aplicación cerrada ni push. Cierres, criterios, cortes y acciones del capitán requieren conexión. Las colas anteriores de asistencia/cuotas se conservan para que no se pierdan operaciones de teléfonos todavía sin actualizar.

Cada operación usa UUID estable, versión y época de datos. Reintentar tras perder respuesta no duplica ingresos. Se permite guardar distintas unidades offline; editar de nuevo una unidad pendiente exige sincronizarla. Conflictos conservan el intento y bloquean la secuencia dependiente. Revisar el servidor antes de descartar y recapturar. Un cambio de cuenta/ciclo o limpieza no permite reenviar operaciones inválidas como si fueran nuevas.

Cerrar sesión, cambiar ciclo o finalizar exige revisar pendientes; la app no puede detectar teléfonos ajenos desconectados. Nunca borrar indiscriminadamente datos del navegador. La copia preparada no sustituye respaldos PostgreSQL.

## Administración y comprobaciones manuales

Scripts opcionales de limpieza: `limpiar_cuotas_asistencias.sql` conserva actividades/convocatorias y reinicia registros operativos; `limpiar_actividad.sql` retira también reuniones/cargos. Revisar el contenido vigente antes de usarlos: contienen borrados de todos los ciclos, bitácoras y operaciones. Cierran su trabajo transaccionalmente y cambian la época para rechazar pendientes previos. No son pasos de instalación.

Antes de publicar: probar dos unidades offline, reconexión y conflicto; repetir cobro con el mismo UUID; cerrar/reabrir; probar capitán otra unidad/fuera de fecha; verificar directorio y perfil con consejero/conquistador; publicar corte y probar caducidad/reapertura; abrir nueva cuenta y comprobar que no hereda caché ajena. Probar email, fotografías reales y PWA iOS/Android en un Supabase de pruebas: no quedan certificados por fixtures locales.
