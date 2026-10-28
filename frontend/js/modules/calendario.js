import { listarActividades, guardarActividad, cancelarActividad, eliminarActividad } from '../services/calendario.js';
import { obtenerOpcionesIntegrante } from '../services/integrantes-admin.js';
const $ = id => document.getElementById(id);
const fechaHoy = () => {
  const partes = new Intl.DateTimeFormat('en', { timeZone: 'America/Mexico_City', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
  return ['year', 'month', 'day'].map(t => partes.find(x => x.type === t).value).join('-');
};
const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const fechaLocal = s => new Date(`${s}T12:00:00`);
const tipos = { regular: 'Reunión regular', practica: 'Prácticas', parcial: 'Reunión parcial', evento: 'Evento' };
const abarca = (a, fecha) => a.fecha <= fecha && (a.fecha_fin || a.fecha) >= fecha;
const estilo = document.createElement('link');
estilo.rel = 'stylesheet'; estilo.href = new URL('../../css/calendario.css', import.meta.url).href; document.head.append(estilo);
const entrada = document.createElement('a'); entrada.href = '#calendario'; entrada.className = 'modulo';
entrada.innerHTML = '<span class="modulo-icono" aria-hidden="true">▦</span><span class="sobre-titulo">VIDA DEL CLUB</span><h2>Calendario</h2><p>Reuniones, prácticas y eventos del club.</p><strong>Ver calendario →</strong>';
document.querySelector('#inicio .menu-grid').prepend(entrada);
const vista = document.createElement('section'); vista.id = 'vistaCalendario'; vista.className = 'vista'; vista.hidden = true;
vista.innerHTML = `
 <span class="sobre-titulo">ORGANIZA EL CLUB</span><h1>Calendario</h1>
 <p id="calMensaje" class="aviso" role="status" hidden></p>
 <div class="cal-barra"><div class="acciones"><button id="calAnterior" class="boton-volver" aria-label="Mes anterior">←</button><button id="calHoy" class="boton-volver">Hoy</button><button id="calSiguiente" class="boton-volver" aria-label="Mes siguiente">→</button></div><h2 id="calMes"></h2><button id="calNueva" class="boton-principal" hidden>Nueva actividad</button></div>
 <div class="cal-panel"><div class="cal-semana" aria-hidden="true"><span>Dom</span><span>Lun</span><span>Mar</span><span>Mié</span><span>Jue</span><span>Vie</span><span>Sáb</span></div><div id="calDias" class="cal-dias" aria-label="Días del mes"></div></div>
 <section class="cal-panel"><div class="cal-barra"><h2 id="calFecha"></h2><button id="calTodo" class="boton-volver">Ver agenda del mes</button></div><div id="calAgenda" class="cal-agenda"></div></section>
 <dialog id="calDialogo" class="cal-dialogo"><form id="calForm"><h2 id="calTitulo"></h2>
 <fieldset id="calCampos" aria-label="Datos de la actividad">
 <label>Tipo de actividad<select id="calTipo"><option value="regular">Reunión regular</option><option value="practica">Prácticas</option><option value="parcial">Reunión parcial</option><option value="evento">Evento</option></select></label>
 <label>Nombre de la actividad<input id="calNombre" required maxlength="60" placeholder="Club / Camporee — mañana"></label>
 <div class="cal-form-grid"><label>Fecha de inicio<input id="calDia" type="date" required></label><label>Hora de inicio<input id="calHora" type="time" required value="09:00"></label></div>
 <label id="calFinCampo" hidden>Fecha de término (incluida)<input id="calFin" type="date"></label>
 <div id="calDestinoCampos" class="cal-form-grid" hidden><label>Convocar por<select id="calDestinoTipo"><option value="unidad">Unidad</option><option value="clase">Clase</option></select></label><label>Destinatario<select id="calDestino"></select></label></div>
 <label id="calCobroCampo" class="cal-check"><input id="calCobro" type="checkbox"> Cobrar cuota de $10 por esta reunión</label>

 </fieldset><p id="calError" role="alert"></p><div class="acciones"><button id="calGuardar" class="boton-principal">Guardar actividad</button><button id="calCerrar" class="boton-volver" type="button">Volver sin guardar</button></div></form></dialog>`;
$('aplicacion').append(vista);
let perfil = null, mes = fechaHoy().slice(0, 7), dia = fechaHoy(), lista = [], revision = 0, ocupado = false, editor = null;
let opciones = { unidades: [], clases: [] };
const admin = () => perfil?.rol === 'directiva';
function n(tag, texto) { const e = document.createElement(tag); e.textContent = texto; return e; }
function boton(texto, fn) { const b = n('button', texto); b.type = 'button'; b.className = 'boton-volver'; b.onclick = fn; return b; }
function mensaje(texto) { $('calMensaje').textContent = texto; $('calMensaje').hidden = !texto; }
export function puedeSalirCalendario() { return !ocupado && (!editor || confirm('Hay una actividad abierta sin guardar. ¿Descartarla?')); }
export function reiniciarCalendario() {
  revision++; perfil = null; lista = []; editor = null; ocupado = false; opciones = { unidades: [], clases: [] };
  $('calDialogo').close(); $('calAgenda').replaceChildren(); $('calDias').replaceChildren();
}
function bloquear(valor) {
  ocupado = valor;
  for (const id of ['calAnterior', 'calHoy', 'calSiguiente', 'calNueva', 'calGuardar', 'calCerrar', 'calCampos', 'calTodo']) $(id).disabled = valor;
  vista.querySelectorAll('#calAgenda button, #calDias button').forEach(b => { b.disabled = valor; });
}
function pintar() {
  const base = fechaLocal(`${mes}-01`), ultimo = new Date(base.getFullYear(), base.getMonth() + 1, 0);
  $('calMes').textContent = base.toLocaleDateString('es-MX', { month: 'long', year: 'numeric' });
  $('calDias').replaceChildren();
  for (let i = 0; i < base.getDay(); i++) $('calDias').append(n('span', ''));
  for (let numero = 1; numero <= ultimo.getDate(); numero++) {
    const fecha = `${mes}-${String(numero).padStart(2, '0')}`, actividades = lista.filter(a => abarca(a, fecha) && a.estado !== 'anulada');
    const b = boton(String(numero), () => { dia = fecha; pintar(); }); b.className = 'cal-dia'; b.dataset.fecha = fecha;
    b.setAttribute('aria-pressed', String(dia === fecha)); b.setAttribute('aria-label', `${fecha}: ${actividades.length} actividades`);
    if (fecha === fechaHoy()) b.setAttribute('aria-current', 'date');
    if (actividades.length) b.append(n('small', `${actividades.length} ${actividades.length === 1 ? 'actividad' : 'actividades'}`));
    const cobros = actividades.filter(a => a.cobra_cuota).length;
    if (cobros) b.append(n('span', `${cobros} ${cobros === 1 ? 'cobro' : 'cobros'}`));
    $('calDias').append(b);
  }
  $('calFecha').textContent = dia ? fechaLocal(dia).toLocaleDateString('es-MX', { weekday: 'long', day: 'numeric', month: 'long' }) : 'Agenda del mes';
  $('calAgenda').replaceChildren(); const actividades = lista.filter(a => !dia || abarca(a, dia));
  if (!actividades.length) $('calAgenda').append(n('p', 'No hay actividades programadas en esta selección.'));
  for (const a of actividades) {
    const tipo = a.tipo || 'regular';
    const card = document.createElement('article'); card.className = 'cal-actividad'; card.dataset.estado = a.estado;
    const datos = document.createElement('div');
    const cabecera = n('div', ''); cabecera.className = 'cal-actividad-titulo';
    const hora = n('time', `${a.hora} h`); hora.dateTime = `${a.fecha}T${a.hora}`;
    cabecera.append(n('h3', a.nombre), hora); datos.append(cabecera);
    // La agenda mensual necesita fecha; en la selección diaria ya está en el encabezado.
    if (!dia || (a.fecha_fin && a.fecha_fin !== a.fecha)) {
      datos.append(n('small', a.fecha_fin && a.fecha_fin !== a.fecha ? `${a.fecha} — ${a.fecha_fin}` : a.fecha));
    }
    if (a.estado === 'anulada') datos.append(n('small', 'Cancelada'));
    const acciones = document.createElement('div'); acciones.className = 'acciones';
    if (a.estado !== 'anulada') {
      if (tipo === 'regular') {
        const link = n('a', 'Abrir reunión'); link.href = `#competencia/puntaje/${a.id}`; link.className = 'boton-volver'; acciones.append(link);
        if (a.cobra_cuota) { const q = n('a', 'Ver cuotas'); q.href = '#cuotas'; q.className = 'boton-volver'; acciones.append(q); }
      }
      if (admin()) acciones.append(boton('Editar', () => abrirEditor(a)), boton('Cancelar actividad', () => void cancelar(a)));
    }
    if (admin()) { const b = boton('Eliminar', () => void eliminar(a)); b.classList.add('cal-eliminar'); acciones.append(b); }
    card.append(datos, acciones); $('calAgenda').append(card);
  }
}
async function cargar() {
  const actual = ++revision; bloquear(true); mensaje('Cargando calendario…');
  const base = fechaLocal(`${mes}-01`), fin = iso(new Date(base.getFullYear(), base.getMonth() + 1, 0));
  try {
    const [datos, catalogos] = await Promise.all([listarActividades(`${mes}-01`, fin), admin() ? obtenerOpcionesIntegrante() : Promise.resolve(opciones)]);
    if (actual !== revision) return; lista = datos; opciones = catalogos; pintar(); mensaje('');
  } catch (e) { if (actual === revision) mensaje(e.message || 'No se pudo cargar el calendario. Reintenta con conexión.'); }
  finally { if (actual === revision) bloquear(false); }
}
export async function abrirCalendario(cuenta) { perfil = cuenta; mes = fechaHoy().slice(0, 7); dia = fechaHoy(); $('calNueva').hidden = !admin(); await cargar(); }
function destinos(valor = '') {
  const unidad = $('calDestinoTipo').value === 'unidad';
  const filas = unidad ? opciones.unidades : opciones.clases;
  $('calDestino').replaceChildren(...filas.map(f => { const o = n('option', f.nombre); o.value = unidad ? f.id_unidad : f.id_clase; return o; }));
  if (valor) $('calDestino').value = valor;
}
function ajustarTipo() {
  const tipo = $('calTipo').value, regular = tipo === 'regular', parcial = tipo === 'parcial', evento = tipo === 'evento';
  $('calFinCampo').hidden = !evento; $('calFin').disabled = !evento; $('calFin').required = evento; $('calFin').min = $('calDia').value;
  $('calDestinoCampos').hidden = !parcial; $('calDestino').disabled = !parcial; $('calDestino').required = parcial; $('calDestinoTipo').disabled = !parcial;
  $('calCobroCampo').hidden = !regular; $('calCobro').disabled = !regular;
  if (!regular) $('calCobro').checked = false;
}
function abrirEditor(a = null) {
  if (!admin() || ocupado) return;
  editor = a ? { ...a } : { id: crypto.randomUUID(), version: null };
  $('calForm').reset(); $('calTitulo').textContent = a ? 'Editar actividad' : 'Nueva actividad';
  $('calNombre').value = a?.nombre || ''; $('calDia').value = a?.fecha || dia || fechaHoy(); $('calHora').value = a?.hora || '09:00';
  $('calTipo').value = a?.tipo || 'regular'; $('calFin').value = a?.fecha_fin || $('calDia').value;
  $('calDestinoTipo').value = a?.destinatario_clase ? 'clase' : 'unidad'; destinos(a?.destinatario_unidad || a?.destinatario_clase);
  $('calCobro').checked = a?.cobra_cuota || false; $('calError').textContent = ''; ajustarTipo(); $('calDialogo').showModal();
}
async function mutar(operacion, error) {
  const actual = revision; bloquear(true);
  try { await operacion(); if (actual !== revision) return; await cargar(); }
  catch (e) { if (actual === revision) mensaje(e.message || error); }
  finally { if (actual === revision) bloquear(false); }
}
async function cancelar(a) {
  if (!admin() || ocupado) return;
  const motivo = prompt(`Cancelar “${a.nombre}”. Su asistencia dejará de contar y su cobro se desactivará. Los pagos quedan como saldo a favor. Escribe el motivo:`);
  if (motivo === null) return; if (motivo.trim().length < 3) return mensaje('Escribe un motivo de al menos 3 caracteres.');
  await mutar(() => cancelarActividad(a, motivo.trim()), 'No se pudo cancelar.');
}
async function eliminar(a) {
  if (!admin() || ocupado) return;
  if (!confirm(`¿Eliminar “${a.nombre}”? Desaparecerá del calendario y del pase de lista. Su asistencia dejará de contar. Los pagos recibidos se conservan como saldo a favor; queda una bitácora del cambio.`)) return;
  await mutar(() => eliminarActividad(a), 'No se pudo eliminar.');
}
$('calForm').onsubmit = async e => {
  e.preventDefault(); if (!editor || ocupado) return;
  const actual = revision, fecha = $('calDia').value, tipo = $('calTipo').value;
  const actividad = { ...editor, fecha, hora: $('calHora').value, nombre: $('calNombre').value.trim(), tipo,
    fecha_fin: tipo === 'evento' ? $('calFin').value : fecha, cobra_cuota: tipo === 'regular' && $('calCobro').checked,
    destinatario_unidad: tipo === 'parcial' && $('calDestinoTipo').value === 'unidad' ? $('calDestino').value : null,
    destinatario_clase: tipo === 'parcial' && $('calDestinoTipo').value === 'clase' ? $('calDestino').value : null };
  bloquear(true); $('calError').textContent = '';
  try {
    await guardarActividad(actividad);
    if (actual !== revision) return; editor = null; $('calDialogo').close(); mes = fecha.slice(0, 7); dia = fecha; await cargar();
  } catch (e) { if (actual === revision) $('calError').textContent = e.message || 'No se recibió confirmación. Reintenta; no se creará una actividad duplicada.'; }
  finally { if (actual === revision) bloquear(false); }
};
function moverMes(delta) { if (ocupado) return; const base = fechaLocal(`${mes}-01`); base.setMonth(base.getMonth() + delta); mes = iso(base).slice(0, 7); dia = ''; void cargar(); }
$('calAnterior').onclick = () => moverMes(-1); $('calSiguiente').onclick = () => moverMes(1);
$('calHoy').onclick = () => { if (ocupado) return; mes = fechaHoy().slice(0, 7); dia = fechaHoy(); void cargar(); };
$('calTodo').onclick = () => { dia = ''; pintar(); };
$('calNueva').onclick = () => abrirEditor(); $('calDia').onchange = ajustarTipo; $('calTipo').onchange = ajustarTipo; $('calDestinoTipo').onchange = () => destinos();
$('calCerrar').onclick = () => { editor = null; $('calDialogo').close(); };
$('calDialogo').addEventListener('cancel', e => { if (ocupado) e.preventDefault(); else editor = null; });
window.addEventListener('beforeunload', e => { if (editor || ocupado) { e.preventDefault(); e.returnValue = ''; } });
