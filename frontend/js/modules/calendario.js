import { listarActividades, guardarActividad, cancelarActividad } from '../services/calendario.js';
const $ = id => document.getElementById(id);
const fechaHoy = () => { const p = new Intl.DateTimeFormat('en', { timeZone: 'America/Mexico_City', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date()); return ['year', 'month', 'day'].map(t => p.find(x => x.type === t).value).join('-'); };
const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
const fechaLocal = s => new Date(`${s}T12:00:00`);
const estilo = document.createElement('link'); estilo.rel = 'stylesheet'; estilo.href = new URL('../../css/calendario.css', import.meta.url).href; document.head.append(estilo);
const entrada = document.createElement('a'); entrada.href = '#calendario'; entrada.className = 'modulo';
entrada.innerHTML = '<span class="modulo-icono" aria-hidden="true">▦</span><span class="sobre-titulo">VIDA DEL CLUB</span><h2>Calendario</h2><p>Actividades, pases de asistencia y domingos de cobro.</p><strong>Ver calendario →</strong>';
document.querySelector('#inicio .menu-grid').prepend(entrada);
const vista = document.createElement('section'); vista.id = 'vistaCalendario'; vista.className = 'vista'; vista.hidden = true;
vista.innerHTML = `
 <span class="sobre-titulo">ORGANIZA EL CLUB</span><h1>Calendario</h1>
 <p>Toda actividad tiene pase de asistencia. Las actividades del mismo domingo comparten una sola cuota de $10 cuando se activa el cobro.</p>
 <p id="calMensaje" class="aviso" role="status" hidden></p>
 <div class="cal-barra"><div class="acciones"><button id="calAnterior" class="boton-volver" aria-label="Mes anterior">←</button><button id="calHoy" class="boton-volver">Hoy</button><button id="calSiguiente" class="boton-volver" aria-label="Mes siguiente">→</button></div><h2 id="calMes"></h2><button id="calNueva" class="boton-principal" hidden>Nueva actividad</button></div>
 <div class="cal-panel"><div class="cal-semana" aria-hidden="true"><span>Lun</span><span>Mar</span><span>Mié</span><span>Jue</span><span>Vie</span><span>Sáb</span><span>Dom</span></div><div id="calDias" class="cal-dias" aria-label="Días del mes"></div></div>
 <section class="cal-panel"><div class="cal-barra"><h2 id="calFecha"></h2><button id="calTodo" class="boton-volver">Ver agenda del mes</button></div><div id="calAgenda" class="cal-agenda"></div></section>
 <dialog id="calDialogo" class="cal-dialogo"><form id="calForm"><h2 id="calTitulo"></h2><p>Horario de Ciudad de México.</p>
 <label>Nombre de la actividad<input id="calNombre" required maxlength="60" placeholder="Club del domingo / Camporee — mañana"></label>
 <div class="cal-form-grid"><label>Fecha<input id="calDia" type="date" required></label><label>Hora<input id="calHora" type="time" required value="09:00"></label></div>
 <label class="cal-check"><input id="calCobro" type="checkbox"> Cobrar cuota de $10 este domingo</label>
 <p id="calCobroAyuda" class="texto-suave"></p><p>Al desactivar el último cobro de una fecha, sus pagos quedan como saldo a favor. Si otra actividad sigue cobrando, se mantiene la cuota compartida.</p>
 <p id="calError" role="alert"></p><div class="acciones"><button id="calGuardar" class="boton-principal">Guardar actividad</button><button id="calCerrar" class="boton-volver" type="button">Cancelar</button></div></form></dialog>`;
$('aplicacion').append(vista);
let perfil = null, mes = fechaHoy().slice(0, 7), dia = fechaHoy(), lista = [], revision = 0, ocupado = false, editor = null;
const admin = () => perfil?.rol === 'directiva';
function n(tag, texto) { const e = document.createElement(tag); e.textContent = texto; return e; }
function boton(texto, fn) { const b = n('button', texto); b.type = 'button'; b.className = 'boton-volver'; b.onclick = fn; return b; }
function mensaje(texto) { $('calMensaje').textContent = texto; $('calMensaje').hidden = !texto; }
export function puedeSalirCalendario() { return !ocupado && (!editor || confirm('Hay una actividad abierta sin guardar. ¿Descartarla?')); }
export function reiniciarCalendario() { revision++; perfil = null; lista = []; editor = null; ocupado = false; $('calDialogo').close(); $('calAgenda').replaceChildren(); $('calDias').replaceChildren(); }
function bloquear(valor) { ocupado = valor; for (const id of ['calAnterior', 'calHoy', 'calSiguiente', 'calNueva', 'calGuardar', 'calCerrar']) $(id).disabled = valor; }
function pintar() {
  const base = fechaLocal(`${mes}-01`), ultimo = new Date(base.getFullYear(), base.getMonth() + 1, 0);
  $('calMes').textContent = base.toLocaleDateString('es-MX', { month: 'long', year: 'numeric' });
  $('calDias').replaceChildren();
  for (let i = 0; i < (base.getDay() + 6) % 7; i++) $('calDias').append(n('span', ''));
  for (let numero = 1; numero <= ultimo.getDate(); numero++) {
    const fecha = `${mes}-${String(numero).padStart(2, '0')}`, actividades = lista.filter(a => a.fecha === fecha && a.estado !== 'anulada');
    const b = boton(String(numero), () => { dia = fecha; pintar(); }); b.className = 'cal-dia'; b.dataset.fecha = fecha;
    b.setAttribute('aria-pressed', String(dia === fecha)); b.setAttribute('aria-label', `${fecha}: ${actividades.length} actividades`);
    if (fecha === fechaHoy()) b.setAttribute('aria-current', 'date');
    if (actividades.length) b.append(n('small', `${actividades.length} ${actividades.length === 1 ? 'actividad' : 'actividades'}`));
    if (actividades.some(a => a.cobra_cuota)) b.append(n('span', '$10'));
    $('calDias').append(b);
  }
  $('calFecha').textContent = dia ? fechaLocal(dia).toLocaleDateString('es-MX', { weekday: 'long', day: 'numeric', month: 'long' }) : 'Agenda del mes';
  $('calAgenda').replaceChildren(); const actividades = lista.filter(a => !dia || a.fecha === dia);
  if (!actividades.length) $('calAgenda').append(n('p', 'No hay actividades programadas en esta selección.'));
  for (const a of actividades) {
    const card = document.createElement('article'); card.className = 'cal-actividad'; card.dataset.estado = a.estado;
    const datos = document.createElement('div'); datos.append(n('small', `${a.fecha} · ${a.hora} h`), n('h3', a.nombre));
    datos.append(n('p', `${a.estado === 'anulada' ? 'Cancelada' : a.estado === 'cerrada' ? 'Pase cerrado' : 'Programada'} · ${a.cobra_cuota ? '$10 por domingo' + (a.cobro_compartido ? ' · cobro compartido' : '') : 'Sin cobro por esta actividad'}`));
    const acciones = document.createElement('div'); acciones.className = 'acciones';
    if (a.estado !== 'anulada') {
      const link = n('a', 'Ver asistencia'); link.href = `#asistencias/${a.id}`; link.className = 'boton-volver'; acciones.append(link);
      if (a.cobra_cuota) { const q = n('a', 'Ver cuotas'); q.href = '#cuotas'; q.className = 'boton-volver'; acciones.append(q); }
      if (admin()) { acciones.append(boton('Editar', () => abrirEditor(a)), boton('Cancelar actividad', () => void cancelar(a))); }
    }
    card.append(datos, acciones); $('calAgenda').append(card);
  }
}
async function cargar() {
  const actual = ++revision; bloquear(true); mensaje('Cargando calendario…');
  const base = fechaLocal(`${mes}-01`), fin = iso(new Date(base.getFullYear(), base.getMonth() + 1, 0));
  try { const datos = await listarActividades(`${mes}-01`, fin); if (actual !== revision) return; lista = datos; pintar(); mensaje(''); }
  catch (e) { if (actual === revision) mensaje(e.message || 'No se pudo cargar el calendario. Reintenta con conexión.'); }
  finally { if (actual === revision) bloquear(false); }
}
export async function abrirCalendario(cuenta) { perfil = cuenta; mes = fechaHoy().slice(0, 7); dia = fechaHoy(); $('calNueva').hidden = !admin(); await cargar(); }
function ayudaCobro() {
  const esDomingo = $('calDia').value && fechaLocal($('calDia').value).getDay() === 0;
  $('calCobro').disabled = !esDomingo; if (!esDomingo) $('calCobro').checked = false;
  $('calCobroAyuda').textContent = !esDomingo ? 'Puedes crear actividades cualquier día; el cobro semanal solo se activa en domingo.' : lista.some(a => a.id !== editor?.id && a.fecha === $('calDia').value && a.cobra_cuota && a.estado !== 'anulada') ? 'Este domingo ya tiene un cobro: se compartirá, sin generar otros $10.' : 'Se preparará una cuota de $10 por integrante que paga cuotas.';
}
function abrirEditor(a = null) {
  if (!admin() || ocupado) return;
  editor = a ? { ...a } : { id: crypto.randomUUID(), version: null };
  $('calForm').reset(); $('calTitulo').textContent = a ? 'Editar actividad' : 'Nueva actividad';
  $('calNombre').value = a?.nombre || ''; $('calDia').value = a?.fecha || (dia && dia >= fechaHoy() ? dia : fechaHoy()); $('calHora').value = a?.hora || '09:00'; $('calCobro').checked = a?.cobra_cuota || false; $('calError').textContent = ''; ayudaCobro(); $('calDialogo').showModal();
}
async function cancelar(a) {
  if (!admin() || ocupado) return;
  const motivo = prompt(`Cancelar “${a.nombre}”. Su asistencia dejará de contar. Si es el último cobro de ese domingo, lo pagado quedará a favor del integrante. Escribe el motivo:`);
  if (motivo === null) return; if (motivo.trim().length < 3) return mensaje('Escribe un motivo de al menos 3 caracteres.');
  const actual = revision; bloquear(true);
  try { await cancelarActividad(a, motivo.trim()); if (actual !== revision) return; await cargar(); }
  catch (e) { if (actual === revision) mensaje(e.message || 'No se pudo cancelar.'); }
  finally { if (actual === revision) bloquear(false); }
}
$('calForm').onsubmit = async e => {
  e.preventDefault(); if (!editor || ocupado) return; const actual = revision;
  bloquear(true); $('calError').textContent = '';
  try {
    const fecha = $('calDia').value;
    await guardarActividad({ ...editor, fecha, hora: $('calHora').value, nombre: $('calNombre').value.trim(), cobra_cuota: $('calCobro').checked });
    if (actual !== revision) return; editor = null; $('calDialogo').close(); mes = fecha.slice(0, 7); dia = fecha; await cargar();
  } catch (e) { if (actual === revision) $('calError').textContent = e.message || 'No se recibió confirmación. Reintenta; no se creará una actividad duplicada.'; }
  finally { if (actual === revision) bloquear(false); }
};
function moverMes(delta) { if (ocupado) return; const base = fechaLocal(`${mes}-01`); base.setMonth(base.getMonth() + delta); mes = iso(base).slice(0, 7); dia = ''; void cargar(); }
$('calAnterior').onclick = () => moverMes(-1); $('calSiguiente').onclick = () => moverMes(1);
$('calHoy').onclick = () => { if (ocupado) return; mes = fechaHoy().slice(0, 7); dia = fechaHoy(); void cargar(); };
$('calTodo').onclick = () => { dia = ''; pintar(); };
$('calNueva').onclick = () => abrirEditor(); $('calDia').onchange = ayudaCobro;
$('calCerrar').onclick = () => { editor = null; $('calDialogo').close(); };
$('calDialogo').addEventListener('cancel', e => { if (ocupado) e.preventDefault(); else editor = null; });
window.addEventListener('beforeunload', e => { if (editor || ocupado) { e.preventDefault(); e.returnValue = ''; } });
