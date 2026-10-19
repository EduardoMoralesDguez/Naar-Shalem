import {navegacionCompetencia,permisosNavegacion} from '../lib/competencia-nav.js';
// frontend/js/modules/asistencias.js
import {
  listarReuniones,
  obtenerReunion,
  actuarReunion,
  obtenerMatriz,
  iniciarAsistenciasLocal, prepararAsistencias, sincronizarAsistencias, estadoAsistencias, resolverAsistencia, obtenerBitacoraAsistencias,
} from '../services/asistencias-offline.js';
import {colorearNombre,ordenarIntegrantes} from '../lib/colores.js';

const estilo = document.createElement('link');
estilo.rel = 'stylesheet';
estilo.href = new URL('../../css/asistencias.css', import.meta.url).href;
document.head.append(estilo);

const vista = document.createElement('section');
vista.id = 'vistaAsistencias';
vista.className = 'vista';
vista.hidden = true;
vista.innerHTML = `
  <span class="sobre-titulo">VIDA DEL CLUB</span><h1>Competencia</h1>
  ${navegacionCompetencia('asistencias')}<h2>Asistencias</h2>
  <p id="asMensaje" class="aviso" role="status" hidden></p>

  <div class="as-herramientas"><span id="asConexion"></span><span id="asActualizado"></span><button id="asRecargar" type="button" class="boton-volver">Actualizar</button></div>
  <section id="asPendientes" class="as-panel" hidden><h2>Pendientes de sincronizar</h2><div id="asCola"></div></section>
  <fieldset id="asCampos" class="as-contenido" aria-label="Asistencias">

    <div class="acciones">
      <button id="asDia" type="button" class="boton-volver">
        Reunión
      </button>
      <button id="asHistorial" type="button" class="boton-volver">
        Historial
      </button>
      <button id="asBitacora" type="button" class="boton-volver" hidden>Bitácora</button>
    </div>

    <section id="asVistaReunion">
      <div id="asCrearPanel" class="as-calendario" hidden><h2>Actividades</h2><a class="boton-volver" href="#calendario">Abrir calendario</a></div>
      <section class="as-panel as-registro"><nav id="asPasesHoy" class="acciones" aria-label="Pases del día"></nav>
      <h2 id="asFechaTitulo"></h2>
      <input id="asReunion" type="hidden">
      <p id="asAvisoReunion" class="texto-suave"></p>

      <nav
        id="asGrupos"
        class="acciones"
        aria-label="Unidades del pase"
      ></nav>

      <h2 id="asUnidadTitulo"></h2>

      <div class="as-scroll" tabindex="0" role="region" aria-label="Pase de lista por unidad">
        <table class="as-tabla"><thead><tr><th scope="col">Integrante</th><th scope="col">A / J / F</th></tr></thead>
          <tbody id="asLista"></tbody>
        </table>
      </div>
      <div class="as-pie" id="asAccionesAdmin" hidden>
        <button id="asGuardar" type="button" class="boton-principal">
          Revisar y guardar unidad
        </button>
        <button id="asCerrar" type="button" class="boton-principal">
          Cerrar pase completo
        </button>
        <button id="asAnular" type="button" class="boton-volver">
          Anular reunión
        </button>
        <button id="asRestaurar" type="button" class="boton-volver">
          Restaurar borrador
        </button>
      </div>
      </section>
    </section>

    <section id="asVistaHistorial" class="as-panel" hidden>
      <label id="asFiltroUnidadCampo" class="as-selector" hidden>Unidad<select id="asFiltroUnidad"></select></label>
      <p id="asResumenHistorial" class="texto-suave" role="status"></p>
      <div class="as-scroll" tabindex="0" role="region" aria-label="Matriz de asistencias">
        <table id="asMatriz" class="as-tabla as-matriz"></table>
      </div>
      <details id="asAdministrarFechas" hidden><summary>Administrar reuniones y borradores</summary><div id="asFechas" class="acciones"></div></details>
    </section>
    <section id="asVistaBitacora" class="as-panel" hidden><h2>Bitácora de cambios</h2><div class="as-scroll"><table class="as-tabla"><thead><tr><th>Fecha</th><th>Registró</th><th>Reunión</th><th>Acción</th><th>Cambios</th></tr></thead><tbody id="asBitacoraLista"></tbody></table></div></section>
  </fieldset>
`;

document.getElementById('aplicacion').append(vista);

const $ = id => document.getElementById(id);

const etiquetas = {
  asistencia: 'Asistencia',
  justificado: 'Justificado',
  falta: 'Falta',
};

let perfil = null;
let panel = null;
let grupo = '';
let modo = 'reunion';
let revision = 0;
let ocupado = false;
let pendientesLocales = 0;
let guardando = false;
let sucio = false;
let estados = new Map();
let matriz = [];
let filtroUnidad = '';
let celda = null;

const admin = () => perfil?.rol === 'directiva';

function mensaje(texto) {
  $('asMensaje').textContent = texto;
  $('asMensaje').hidden = !texto;
}

function bloquear(valor) {
  ocupado = valor;
  $('asCampos').disabled = valor; $('asRecargar').disabled=valor;
}

function hoy() {
  const partes = new Intl.DateTimeFormat('en', {
    timeZone: 'America/Mexico_City',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());

  return ['year', 'month', 'day']
    .map(tipo => partes.find(p => p.type === tipo).value)
    .join('-');
}

function boton(texto, ejecutar) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = 'boton-volver';
  b.textContent = texto;
  b.addEventListener('click', ejecutar);

  return b;
}

export function puedeSalirAsistencias() {
  return !guardando && (
    !sucio ||
    confirm('Hay cambios sin guardar. ¿Descartarlos?')
  );
}

export function reiniciarAsistencias() {
  revision += 1;
  perfil = null; pendientesLocales=0; iniciarAsistenciasLocal(null); $('asCola').replaceChildren();$('asBitacoraLista').replaceChildren();$('asPendientes').hidden=true;$('asConexion').textContent='';$('asActualizado').textContent='';
  panel = null;
  grupo = '';
  $('asReunion').value = '';
  sucio = false;
  guardando = false;
  estados.clear(); matriz = []; celda = null; filtroUnidad = '';
  dialogo.close();
  dialogo.querySelectorAll('button').forEach(b => b.disabled = false);

  bloquear(false);
  mensaje('');

  for (const id of [
    'asLista',
    'asMatriz',
    'asFechas',
    'asFiltroUnidad',
    'asGrupos',
    'asPasesHoy',


  ]) {
    $(id).replaceChildren();
  }

  for (const id of [
    'asUnidadTitulo',
    'asAvisoReunion',
    'asResumenHistorial',
  ]) {
    $(id).textContent = '';
  }

  $('asAccionesAdmin').hidden = true;
}

function resumen(filas) {
  const contar = estado =>
    filas.filter(x => x.estado === estado).length;

  return `${filas.length} registros · ${contar('asistencia')} asistencias · ${contar('falta')} faltas · ${contar('justificado')} justificados`;
}

function pintarPanel() {
  $('asBitacora').setAttribute('aria-pressed','false');
  $('asDia').setAttribute('aria-pressed', 'true');
  $('asHistorial').setAttribute('aria-pressed', 'false');
  $('asGrupos').replaceChildren();
  $('asLista').replaceChildren();
  $('asAccionesAdmin').hidden = !admin() || !panel;

  if (!panel) {
    $('asUnidadTitulo').textContent = '';
    $('asFechaTitulo').textContent = '';
    $('asAvisoReunion').textContent = admin() && modo === 'reunion' ? 'Todavía no hay una reunión de hoy.' : 'No hay reuniones disponibles.';
    return;
  }

  if (!panel.grupos.some(g => g.clave === grupo)) {
    grupo =
      panel.grupos.find(g => g.clave === panel.clave_actor)?.clave ||
      panel.grupos[0]?.clave ||
      '';
  }

  $('asFechaTitulo').textContent = `${panel.fecha} · ${panel.nombre || 'General'}`;
  const seleccion = panel.grupos.find(g => g.clave === grupo);

  // Solo la directiva navega entre unidades.
  // Capitanes y consejeros ven directamente su unidad.
  if (admin()) {
    for (const g of [...panel.grupos].sort((a,b)=>Number(a.clave==='sin-unidad')-Number(b.clave==='sin-unidad'))) {
      const b = boton(
        `${g.nombre}${g.revisada ? ' ✓' : ''}`,
        () => {
          if (ocupado || !puedeSalirAsistencias()) return;

          sucio = false;
          grupo = g.clave;
          pintarPanel();
        }
      );

      b.setAttribute('aria-pressed', String(g.clave === grupo));
      b.setAttribute('aria-label', `${g.nombre}: ${g.revisada ? 'revisada' : 'pendiente'}`);
      $('asGrupos').append(b);
    }
  }

  $('asUnidadTitulo').textContent =
    seleccion?.nombre || 'Mi asistencia';

  $('asAvisoReunion').textContent = panel.estado === 'anulada' ? 'Reunión anulada' : '';

  const filas = panel.integrantes.filter(u => u.clave === grupo).sort(ordenarIntegrantes);

  estados = new Map(filas.map(u => [u.id_usuario, u.estado]));

  for (const u of filas) {
    const li = document.createElement('tr');

    const datos = document.createElement('td');
    const nombre = document.createElement('strong');
    nombre.textContent = u.nombre; colorearNombre(nombre,u.id_usuario);
    datos.append(nombre);

    if (u.motivo) {
      const nota = document.createElement('small');
      nota.textContent = `Justificación: ${u.motivo}`;
      datos.append(nota);
    }

    const acciones = document.createElement('td');
    acciones.className = 'as-controles';

    if (admin() && panel.estado !== 'anulada') {
      const opciones = document.createElement('div');
      opciones.className = 'as-opciones';
      opciones.setAttribute('role', 'group');
      opciones.setAttribute('aria-label', `Asistencia de ${u.nombre}`);
      for (const [valor, texto] of Object.entries(etiquetas)) {
        const b = boton(texto[0], () => {
          estados.set(u.id_usuario, valor);
          opciones.querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', String(x.dataset.estado === valor)));
          sucio = filas.some(f => estados.get(f.id_usuario) !== f.estado);
          actualizarCierre();
        });
        b.dataset.estado = valor;
        b.title = texto;
        b.setAttribute('aria-label', `${texto}: ${u.nombre}`);
        b.setAttribute('aria-pressed', String(u.estado === valor));
        opciones.append(b);
      }
      acciones.append(opciones);
    } else {
      const estado = document.createElement('span');
      estado.className = 'as-estado';
      estado.dataset.estado = u.estado;
      estado.textContent = etiquetas[u.estado];
      acciones.append(estado);

      if (
        panel.fecha === hoy() && panel.puede_justificar &&
        u.puede_justificar &&
        panel.estado !== 'anulada' &&
        u.estado === 'falta'
      ) {
        acciones.append(boton('Marcar justificado', () => {
          const motivo = prompt(
            `Motivo de la justificación de ${u.nombre} (3 a 500 caracteres):`
          );

          if (motivo !== null) {
            void ejecutar('justificar', {
              id_usuario: u.id_usuario,
              motivo,
            });
          }
        }));
      }
    }

    li.append(datos, acciones);
    $('asLista').append(li);
  }

  $('asGuardar').hidden = panel.estado === 'anulada';
  $('asGuardar').disabled = !filas.length;

  $('asGuardar').textContent = 'Guardar';

  $('asCerrar').hidden = panel.estado !== 'borrador';

  actualizarCierre();

  $('asAnular').hidden = panel.estado === 'anulada';
  $('asRestaurar').hidden = panel.estado !== 'anulada';
}

function actualizarCierre() {
  const motivo = !navigator.onLine || pendientesLocales ? 'Actualiza y sincroniza antes de cerrar.' : sucio ? 'Guarda los cambios de esta unidad antes de cerrar.'
    : panel.grupos.some(g => !g.revisada) ? 'Revisa y guarda todas las unidades, incluida Sin unidad.'
    : '';
  $('asCerrar').title = panel.estado === 'borrador' ? motivo : '';
  $('asCerrar').disabled = Boolean(motivo) || panel.estado !== 'borrador';
}

async function cargarReuniones(id = $('asReunion').value) {
  const actual = ++revision;

  bloquear(true);
  mensaje('Cargando reuniones…');

  try {
    const lista = await listarReuniones();

    if (actual !== revision) return;

    const disponibles = lista.filter(r => r.estado !== 'anulada' && (admin() ? r.fecha === hoy() : r.fecha <= hoy()));
    const fechaActual = disponibles[0]?.fecha;
    const pasesDia = disponibles.filter(r => r.fecha === fechaActual);
    const elegido = modo === 'editar' ? lista.find(r => r.id === id)?.id
      : pasesDia.find(r => r.id === id)?.id || pasesDia[0]?.id;
    $('asReunion').value = elegido || '';
    $('asCrearPanel').hidden = !admin() || modo !== 'reunion';
    $('asPasesHoy').replaceChildren();
    if (modo === 'reunion' && pasesDia.length > 1) {
      for (const pase of pasesDia) {
        const b = boton(`${pase.nombre || 'General'} · ${pase.estado}`, () => {
          if (ocupado || !puedeSalirAsistencias()) return;
          sucio = false; grupo = ''; void cargarReuniones(pase.id);
        });
        b.setAttribute('aria-pressed', String(pase.id === elegido));
        $('asPasesHoy').append(b);
      }
    }
    const resultado = elegido
      ? await obtenerReunion(elegido)
      : null;

    if (actual !== revision) return;

    panel = resultado;
    sucio = false;
    pintarPanel();
    await mostrarEstadoLocal();
  } catch (error) {
    if (actual === revision) {
      panel = null;
      pintarPanel();

      mensaje(
        error.message ||
        'No se pudo cargar. Pulsa Recargar.'
      );
    }
  } finally {
    if (actual === revision) bloquear(false);
  }
}

function pintarMatriz() {
  $('asBitacora').setAttribute('aria-pressed','false');
  $('asDia').setAttribute('aria-pressed', 'false');
  $('asHistorial').setAttribute('aria-pressed', 'true');
  const filas = matriz.filter(r => !filtroUnidad || r.unidad_clave === filtroUnidad);
  const fechas = [...new Map(filas.map(r => [r.reunion, { id: r.reunion, fecha: r.fecha, nombre: r.nombre_pase || 'General' }])).values()];
  const integrantes = [...new Map(filas.map(r => [r.id_usuario, r.nombre])).entries()]
    .sort((a, b) => ordenarIntegrantes({id_usuario:a[0],nombre:a[1]},{id_usuario:b[0],nombre:b[1]}));
  const registros = new Map(filas.map(r => [`${r.id_usuario}/${r.reunion}`, r]));
  const tabla = $('asMatriz'); tabla.replaceChildren();
  const caption = document.createElement('caption'); caption.textContent = 'Historial de reuniones cerradas'; tabla.append(caption);
  const head = document.createElement('thead'), tr = document.createElement('tr');
  for (const texto of ['Integrante', ...fechas.map(f => `${f.fecha}\n${f.nombre}`), '%']) {
    const th = document.createElement('th'); th.scope = 'col'; th.textContent = texto; tr.append(th);
  }
  head.append(tr); tabla.append(head);
  const body = document.createElement('tbody');
  for (const [id, nombre] of integrantes) {
    const row = document.createElement('tr'), th = document.createElement('th');
    th.scope = 'row'; th.textContent = nombre; colorearNombre(th,id);row.append(th);
    let total = 0, cumplidas = 0;
    for (const fecha of fechas) {
      const r = registros.get(`${id}/${fecha.id}`), td = document.createElement('td');
      if (!r) { td.textContent = '—'; td.title = 'No convocado'; }
      else {
        total++; if (r.estado !== 'falta') cumplidas++;
        const marca = admin() ? boton(etiquetas[r.estado][0], () => abrirCelda(r)) : document.createElement('span');
        marca.className = 'as-marca'; marca.dataset.estado = r.estado;
        marca.textContent = etiquetas[r.estado][0];
        marca.title = etiquetas[r.estado];
        marca.setAttribute('aria-label', `${nombre}, ${fecha.fecha}, ${fecha.nombre}: ${etiquetas[r.estado]}${admin() ? '. Editar' : ''}`);
        td.append(marca);
      }
      row.append(td);
    }
    const porcentaje = document.createElement('td'); porcentaje.textContent = total ? `${Math.round(100 * cumplidas / total)}%` : '—'; row.append(porcentaje); body.append(row);
  }
  tabla.append(body);
  $('asResumenHistorial').textContent = filas.length ? '' : 'No hay reuniones cerradas para esta unidad.';
}
async function cargarHistorial() {
  const actual = ++revision; bloquear(true); mensaje('Cargando historial…');
  $('asMatriz').replaceChildren(); $('asFechas').replaceChildren();
  try {
    const [filas, fechas] = await Promise.all([obtenerMatriz(), admin() ? listarReuniones() : Promise.resolve([])]);
    if (actual !== revision) return;
    matriz = filas;
    const unidades = new Map(filas.map(r => [r.unidad_clave, r.unidad]));
    if (!unidades.has(filtroUnidad)) filtroUnidad = unidades.keys().next().value || '';
    $('asFiltroUnidad').replaceChildren(...Array.from(unidades, ([id, nombre]) => new Option(nombre, id)));
    $('asFiltroUnidad').value = filtroUnidad; $('asFiltroUnidadCampo').hidden = !admin();
    if (!admin()) filtroUnidad = '';
    $('asAdministrarFechas').hidden = !admin();
    for (const f of fechas) $('asFechas').append(boton(`${f.fecha} · ${f.nombre || 'General'} · ${f.estado}`, () => {
      modo = 'editar'; $('asVistaHistorial').hidden = true; $('asVistaReunion').hidden = false;
      void cargarReuniones(f.id);
    }));
    pintarMatriz(); await mostrarEstadoLocal();
  } catch (error) { if (actual === revision) mensaje(error.message || 'No se pudo cargar el historial.'); }
  finally { if (actual === revision) bloquear(false); }
}

const dialogo = document.createElement('dialog');
dialogo.className = 'as-dialogo';
dialogo.innerHTML = `<h2 id="asCeldaTitulo">Editar asistencia</h2><p id="asCeldaEstado" role="status"></p><div id="asCeldaOpciones" class="acciones"></div><button type="button" id="asCeldaCancelar" class="boton-volver">Cancelar</button>`;
dialogo.setAttribute('aria-labelledby', 'asCeldaTitulo'); document.body.append(dialogo);
function abrirCelda(registro) {
  if (ocupado || !admin()) return;
  celda = registro; $('asCeldaTitulo').textContent = `${registro.nombre} · ${registro.fecha} · ${registro.nombre_pase || 'General'}`;
  $('asCeldaEstado').textContent = 'Selecciona el estado correcto.';
  $('asCeldaOpciones').replaceChildren(...Object.entries(etiquetas).map(([valor, texto]) => boton(texto, () => void guardarCelda(valor))));
  dialogo.showModal();
}
async function guardarCelda(estado) {
  if (guardando || !celda) return;
  const actual = revision; guardando = true; bloquear(true);
  dialogo.querySelectorAll('button').forEach(b => b.disabled = true);
  let exito = false;
  try {
    await actuarReunion({ id: celda.reunion, version: celda.version }, 'celda', { id_usuario: celda.id_usuario, estado });
    exito = true;
  } catch (error) {
    if (actual === revision) $('asCeldaEstado').textContent = error.code === '40001' ? 'El registro cambió. Cancela y pulsa Recargar antes de editar.' : error.message;
  } finally {
    if (actual === revision) { guardando = false; bloquear(false); }
    if (actual === revision) dialogo.querySelectorAll('button').forEach(b => b.disabled = false);
  }
  if (actual === revision && exito) { dialogo.close(); await cargarHistorial(); }
}
$('asCeldaCancelar').addEventListener('click', () => dialogo.close());
dialogo.addEventListener('cancel', e => { if (guardando) e.preventDefault(); });
$('asFiltroUnidad').addEventListener('change', () => { filtroUnidad = $('asFiltroUnidad').value; pintarMatriz(); });

async function cambiarModo(nuevo) {
  if (ocupado || !puedeSalirAsistencias()) return;

  sucio = false;
  modo = nuevo;

  $('asVistaBitacora').hidden=modo!=='bitacora';
  $('asVistaReunion').hidden = modo === 'historial'||modo==='bitacora';
  $('asVistaHistorial').hidden = modo !== 'historial';

  if(modo==='bitacora'){await cargarBitacora();return;}
  if (modo !== 'historial') {
    await cargarReuniones();
  } else {
    await cargarHistorial();
  }
}

async function ejecutar(accion, datos = {}) {
  if (ocupado || !panel) return;

  if (accion !== 'unidad' && !puedeSalirAsistencias()) return;

  const actual = revision;
  const id = panel.id;

  guardando = true;
  bloquear(true);
  mensaje('Guardando…');

  let guardado = false;

  try {
    await actuarReunion(panel, accion, datos);
    guardado = true;
  } catch (error) {
    if (actual === revision) {
      mensaje(
        error.code === '40001'
          ? 'Alguien cambió esta reunión. Recarga y revisa los datos antes de guardar.'
          : error.message ||
            'No se pudo confirmar el guardado. Recarga antes de reintentar.'
      );
    }
  } finally {
    if (actual === revision) {
      guardando = false;
      bloquear(false);
    }
  }

  if (actual !== revision || !guardado) return;

  sucio = false;

  const siguiente = revision + 1;

  await cargarReuniones(id);

  if (revision === siguiente && panel) {
    await mostrarEstadoLocal();
  }
}

export async function abrirAsistencias(cuenta, idActividad = null, authId=null) {
  reiniciarAsistencias();
  perfil = cuenta; permisosNavegacion(vista,perfil); iniciarAsistenciasLocal(authId);$('asBitacora').hidden=!admin();$('asVistaBitacora').hidden=true;
  let errorCarga=null;
  if(navigator.onLine){try{bloquear(true);mensaje('Actualizando…');await sincronizarAsistencias();await prepararAsistencias();}catch(e){errorCarga=e;}finally{bloquear(false);}}
  modo = idActividad ? 'editar' : 'reunion';

  $('asVistaReunion').hidden = false;
  $('asVistaHistorial').hidden = true;
  $('asCrearPanel').hidden = !admin();


  if(errorCarga?.code==='42501'){mensaje(errorCarga.message);return;}
  await cargarReuniones(idActividad);
  if(errorCarga)mensaje(errorCarga.message||'No se pudo actualizar. Se muestran los datos guardados.');
}

$('asGuardar').addEventListener('click', () => {
  const integrantes = panel.integrantes
    .filter(u => u.clave === grupo)
    .map(u => ({
      id_usuario: u.id_usuario,
      estado: estados.get(u.id_usuario),
    }));

  void ejecutar('unidad', {
    clave: grupo,
    integrantes,
  });
});

$('asCerrar').addEventListener('click', () => {
  const texto =
    `¿Cerrar el pase de TODAS las unidades?\n${resumen(panel.integrantes)}\nSe registrará a cada convocado; los no marcados quedarán con falta.`;

  if (confirm(texto)) void ejecutar('cerrar');
});

$('asAnular').addEventListener('click', () => {
  const motivo = prompt(
    'Esta actividad dejará de contar para asistencia. Su cobro se desactivará y los pagos quedarán como saldo a favor. Escribe el motivo de anulación:'
  );

  if (motivo !== null) void ejecutar('anular', { motivo });
});

$('asRestaurar').addEventListener('click', () => {
  if (!confirm('Restaurar esta actividad también reactiva su cobro, si lo tenía. ¿Continuar?')) return;
  void ejecutar('restaurar');
});

$('asDia').addEventListener('click', () => {
  void cambiarModo('reunion');
});

$('asHistorial').addEventListener('click', () => {
  void cambiarModo('historial');
});

$('asRecargar').addEventListener('click', () => {
  void actualizarAsistencias();
});

window.addEventListener('beforeunload', evento => {
  if (sucio || guardando) {
    evento.preventDefault();
    evento.returnValue = '';
  }
});
async function mostrarEstadoLocal(){
 const rev=revision;const d=await estadoAsistencias();if(rev!==revision||!perfil)return;pendientesLocales=d.cola.length;$('asConexion').textContent=`${navigator.onLine?'Con conexión':'Sin conexión'} · ${d.cola.length?`${d.cola.length} pendientes`:'Sin pendientes'}`;
 $('asActualizado').textContent=d.actualizado?`Actualizado · ${new Date(d.actualizado).toLocaleString('es-MX',{dateStyle:'short',timeStyle:'short',timeZone:'America/Mexico_City'})}`:'';
 $('asPendientes').hidden=!d.cola.some(o=>o.error);$('asCola').replaceChildren();
 for(const o of d.cola.filter(o=>o.error)){const fila=document.createElement('div');fila.className='as-pendiente';fila.textContent=`${d.paneles[o.reunion]?.nombre||'Reunión'} · ${o.accion} · ${o.error||'Guardado en este dispositivo'}`;
 if(o.revisar)fila.append(boton('Resolver registro',async()=>{if(!navigator.onLine||ocupado)return;if(!confirm('Revisa el pase actualizado antes de quitar este intento. Si falta el cambio, vuelve a registrarlo. ¿Quitar pendiente?'))return;await resolverAsistencia(o.id);await actualizarAsistencias();}));$('asCola').append(fila);}
 mensaje(d.cola.length?'Cambios guardados en este dispositivo. Pendientes de sincronizar.':navigator.onLine?'Todos los cambios están sincronizados.':'Sin conexión. Puedes guardar en este dispositivo.');
 if(panel){actualizarCierre();$('asAnular').disabled=$('asRestaurar').disabled=Boolean(d.cola.length)||!navigator.onLine;}
}
async function actualizarAsistencias(){
 if(ocupado||!puedeSalirAsistencias())return;
 sucio=false;bloquear(true);
 try{if(navigator.onLine){await sincronizarAsistencias();await prepararAsistencias();if(navigator.storage?.persist)await navigator.storage.persist();}
 bloquear(false);await cambiarModo(modo);}
 catch(e){mensaje(e.message||'No se pudo actualizar. Tus pendientes siguen guardados.');}
 finally{bloquear(false);}
}
async function cargarBitacora(){
 $('asDia').setAttribute('aria-pressed','false');$('asHistorial').setAttribute('aria-pressed','false');$('asBitacora').setAttribute('aria-pressed','true');$('asBitacoraLista').replaceChildren();
 if(!admin())return;
 if(!navigator.onLine){mensaje('Conecta para consultar la bitácora.');return;}
 bloquear(true);const rev=revision;
 try{const filas=await obtenerBitacoraAsistencias();if(rev!==revision)return;const d=await estadoAsistencias();const nombres=new Map(Object.values(d.paneles).flatMap(p=>p.integrantes.map(u=>[u.id_usuario,u.nombre])));
 for(const f of filas){const tr=document.createElement('tr');const cambios=f.datos?.integrantes?.map(u=>`${nombres.get(u.id_usuario)||'Integrante'}: ${etiquetas[u.estado]||u.estado}`).join(' · ')||[nombres.get(f.datos?.id_usuario),etiquetas[f.datos?.estado],f.datos?.motivo].filter(Boolean).join(' · ')||'—';
 for(const t of [new Date(f.fecha).toLocaleString('es-MX',{timeZone:'America/Mexico_City'}),f.autor,f.reunion,({incorporar:'Alta de integrante',unidad:'Pase de unidad',celda:'Corrección',cerrar:'Cierre',anular:'Anulación',restaurar:'Restauración',justificar:'Justificación'})[f.accion]||f.accion,cambios]){const td=document.createElement('td');td.textContent=t;tr.append(td);}$('asBitacoraLista').append(tr);}
 mensaje(filas.length?'':'Sin cambios registrados.');
 }catch(e){if(rev===revision)mensaje(e.message);}finally{if(rev===revision)bloquear(false);}
}
$('asBitacora').onclick=()=>{if(admin())void cambiarModo('bitacora');};
window.addEventListener('online',()=>{if(!vista.hidden&&!sucio&&!guardando)void actualizarAsistencias();});
window.addEventListener('offline',()=>{if(!vista.hidden)void mostrarEstadoLocal();});
