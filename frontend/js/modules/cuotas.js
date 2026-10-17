import {colorearNombre,colorearAvatar,ordenarIntegrantes} from '../lib/colores.js';
import { obtenerCuotas, enviarCuota, verificarCuenta } from '../services/cuotas.js';
import { localCuotas, guardarOperacion, recordarCuenta } from '../lib/cuotas-local.js';
const $ = id => document.getElementById(id);
const dinero = c => new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(c / 100);
const etiquetaPeriodo = p => p ? `${p.fecha} · ${p.hora?.slice(0, 5) || '09:00'} · ${p.nombre || 'Cobro anterior'}` : 'Actividad anterior';
const hoy = () => { const parts = new Intl.DateTimeFormat('en', { timeZone: 'America/Mexico_City', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date()); return ['year', 'month', 'day'].map(t => parts.find(p => p.type === t).value).join('-'); };
const estilo = document.createElement('link'); estilo.rel = 'stylesheet'; estilo.href = new URL('../../css/cuotas.css', import.meta.url).href; document.head.append(estilo);
const entrada = document.createElement('a'); entrada.href = '#cuotas'; entrada.className = 'modulo';
entrada.innerHTML = '<span class="modulo-icono" aria-hidden="true">$</span><span class="sobre-titulo">TESORERÍA</span><h2>Cuotas</h2><p>Cobros por actividad, abonos y saldo a favor.</p><strong>Entrar al módulo →</strong>';
document.querySelector('#inicio .menu-grid').append(entrada);
const vista = document.createElement('section'); vista.id = 'vistaCuotas'; vista.className = 'vista'; vista.hidden = true;
vista.innerHTML = `
 <span class="sobre-titulo">TESORERÍA DEL CLUB</span><h1>Cuotas</h1><a class="boton-volver" href="#competencia">Competencia</a>
 <div class="aviso cu-estado"><p id="cuEstado" role="status"></p><span id="cuPreparacion"></span></div>
 <div class="cu-herramientas"><span id="cuConexion" role="status"></span><button id="cuSync" class="boton-volver">Actualizar</button></div>
 <nav class="cu-tabs" aria-label="Secciones de cuotas"><button id="cuTabCobro" class="boton-volver" aria-pressed="true">Cobro</button><button id="cuTabHistorial" class="boton-volver" aria-pressed="false">Historial</button><button id="cuTabBitacora" class="boton-volver" aria-pressed="false" hidden>Bitácora</button></nav>
 <section id="cuPendientes" class="cu-panel" hidden><h2>Guardado en este dispositivo</h2><p>Estos movimientos todavía no están confirmados en Supabase. Se enviarán con la cuenta que los capturó.</p><div id="cuCola"></div></section>
 <div id="cuVistaCobro"><section id="cuCalendario" class="cu-panel" hidden><h2>Actividades</h2><a href="#calendario" class="boton-volver">Abrir calendario</a></section>
 <section class="cu-panel"><div class="cu-form"><label>Actividad<select id="cuPeriodo"></select></label><label id="cuUnidadCampo">Unidad<select id="cuUnidad"></select></label></div>
 <div class="cu-scroll"><table class="cu-tabla"><caption>Registro de cuotas</caption><thead><tr><th>Integrante</th><th>Aplicado / cuota</th><th>Saldo a favor</th><th>Registro</th></tr></thead><tbody id="cuLista"></tbody></table></div>
 <p id="cuVacio"></p><button id="cuGuardar" class="boton-principal" hidden>Guardar pagos marcados</button><button id="cuCerrar" class="boton-volver" hidden>Cerrar cobro de unidad</button><p id="cuCierreEstado" role="status"></p></section>
 </div>
 <section id="cuVistaHistorial" class="cu-panel" hidden>
  <div class="cu-tabs" aria-label="Vistas del historial"><button id="cuPorUnidad" class="boton-volver" aria-pressed="true">Por unidad</button><button id="cuPorIntegrante" class="boton-volver" aria-pressed="false">Por integrante</button></div>
  <label id="cuHistUnidadCampo">Unidad<select id="cuHistUnidad"></select></label>
  <h2 id="cuMiUnidad"></h2>
  <div id="cuHistMatriz" class="cu-scroll" tabindex="0" role="region" aria-label="Cuotas por unidad"><table id="cuMatriz" class="cu-tabla cu-matriz"></table></div>
  <div id="cuHistDirectorio" hidden><label>Buscar integrante<input id="cuBuscar" type="search" placeholder="Nombre del integrante"></label><div id="cuIntegrantes" class="cu-integrantes"></div></div>
  <div id="cuHistDetalle" hidden><button id="cuHistVolver" class="boton-volver">← Integrantes</button><h2 id="cuHistNombre"></h2><div class="cu-scroll"><table class="cu-tabla"><caption>Historial de ingresos</caption><thead><tr><th>Fecha</th><th>Importe</th><th>Aplicación</th><th>Registró / estado</th><th>Acciones</th></tr></thead><tbody id="cuHistorial"></tbody></table></div></div>
 </section>
 <section id="cuAuditoria" class="cu-panel" hidden><h2>Bitácora de cambios</h2><div class="cu-scroll"><table class="cu-tabla"><thead><tr><th>Fecha</th><th>Registró</th><th>Movimiento</th><th>Integrante / actividad</th><th>Motivo</th></tr></thead><tbody id="cuBitacora"></tbody></table></div></section>
 <dialog id="cuDialogo" class="cu-dialogo"><form id="cuFormulario"><h2 id="cuTitulo"></h2><p id="cuAyuda"></p>
 <label id="cuMontoCampo">Importe recibido ($)<input id="cuMonto" type="number" min="0.01" max="100000" step="0.01" required></label>
 <label id="cuFechaCampo">Fecha de recepción<input id="cuFechaPago" type="date" required></label>
 <fieldset id="cuAplicar"><legend>Aplicar a estas actividades (del más antiguo al más reciente)</legend><div id="cuOpciones"></div><p>Lo que no se aplique queda como saldo a favor para próximas actividades.</p></fieldset>
 <label>Nota / motivo<input id="cuNota" maxlength="500"></label>
 <p id="cuError" role="alert"></p><div class="acciones"><button class="boton-principal">Guardar en el dispositivo</button><button id="cuCancelar" type="button" class="boton-volver">Cancelar</button></div></form></dialog>`;
$('aplicacion').append(vista);
let cuenta, perfil, local, revision = 0, ocupado = false, guardando = false, editando = null;
const marcados = new Set();
let seleccionPeriodo = '', seleccionUnidad = '';
let pestaña = 'cobro', historialVista = 'unidad', historialUsuario = null;
function cambiaFiltro() {
  if (marcados.size && !confirm('Hay pagos marcados sin guardar. ¿Descartarlos y cambiar el filtro?')) {
    $('cuPeriodo').value = seleccionPeriodo; $('cuUnidad').value = seleccionUnidad; return;
  }
  marcados.clear(); pintar();
}
const admin = () => perfil?.rol === 'directiva';
const cobra = () => ['directiva', 'capitan', 'subcapitan'].includes(perfil?.rol);
function mensaje(t) { $('cuEstado').textContent = t; }
function nodo(tag, texto) { const n = document.createElement(tag); n.textContent = texto; return n; }
function boton(t, fn) { const b = nodo('button', t); b.type = 'button'; b.className = 'boton-volver'; b.addEventListener('click', fn); return b; }
function opciones(select, rows, value, label) {
  const anterior = select.value; select.replaceChildren(...rows.map(r => { const o = nodo('option', label(r)); o.value = value(r); return o; }));
  if (rows.some(r => value(r) === anterior)) select.value = anterior;
}
export function puedeSalirCuotas() { return !ocupado && !guardando && ((!marcados.size && !editando) || confirm('Hay cambios sin guardar. ¿Salir de cuotas?')); }
export function reiniciarCuotas() {
  revision++; cuenta = null; perfil = null; local = null; marcados.clear(); editando = null; ocupado = false; guardando = false;
  pestaña = 'cobro'; historialVista = 'unidad'; historialUsuario = null;
  $('cuBuscar').value = ''; $('cuDialogo').close(); $('cuFormulario').reset();
  for (const id of ['cuLista', 'cuHistorial', 'cuCola', 'cuBitacora', 'cuPeriodo', 'cuUnidad', 'cuHistUnidad', 'cuMatriz', 'cuIntegrantes', 'cuHistNombre', 'cuMiUnidad', 'cuConexion', 'cuPreparacion', 'cuEstado', 'cuOpciones', 'cuTitulo', 'cuAyuda', 'cuError', 'cuVacio']) $(id).replaceChildren();
  for (const id of ['cuCalendario', 'cuGuardar', 'cuAuditoria', 'cuPendientes']) $(id).hidden = true;
}
export async function pendientesCuotas(id) { return id ? (await localCuotas(id)).cola.length : 0; }
function pintar() {
  const p = local?.panel; if (!p) return;
  $('cuCalendario').hidden = !admin(); $('cuUnidadCampo').hidden = !admin();
  $('cuGuardar').hidden = !cobra(); $('cuGuardar').disabled = ocupado || !marcados.size;
  $('cuSync').disabled = ocupado || !navigator.onLine;
  $('cuConexion').textContent = `${navigator.onLine ? 'Con conexión' : 'Sin conexión'} · ${local.cola.length ? `${local.cola.length} pendientes` : 'Sin pendientes'}`;
  $('cuPreparacion').textContent = `Actualizado · ${new Date(local.actualizado).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Mexico_City' })}`;
  const actuales = p.periodos.filter(x => !x.legado && x.fecha <= hoy());
  const visibles = admin() || !cobra() ? p.periodos : actuales.filter(p => p.fecha === actuales[0]?.fecha);
  opciones($('cuPeriodo'), visibles, r => r.id, etiquetaPeriodo);
  opciones($('cuUnidad'), [{ id: '', nombre: 'Todas las unidades' }, ...[...new Map(p.integrantes.map(u => [u.id_unidad || 'sin-unidad', { id: u.id_unidad || 'sin-unidad', nombre: u.unidad }])).values()]], r => r.id, r => r.nombre);
  seleccionPeriodo = $('cuPeriodo').value; seleccionUnidad = $('cuUnidad').value;
  const unidades = [...new Map(p.integrantes.map(u => [u.id_unidad || 'sin-unidad', { id: u.id_unidad || 'sin-unidad', nombre: u.unidad }])).values()];
  opciones($('cuHistUnidad'), unidades, u => u.id, u => u.nombre);
  $('cuLista').replaceChildren();
  const usuarios = p.integrantes.filter(u => !$('cuUnidad').value || (u.id_unidad || 'sin-unidad') === $('cuUnidad').value);
  const periodo = p.periodos.find(x => x.id === $('cuPeriodo').value);
  for (const u of [...usuarios].sort(ordenarIntegrantes)) {
    const cargo = p.cargos.find(c => c.id_usuario === u.id_usuario && c.periodo === periodo?.id);
    const pendientes = local.cola.filter(o => o.datos.id_usuario === u.id_usuario);
    const pendiente = pendientes.some(o => o.revisar || o.error || o.accion !== 'pago' || o.datos.importe !== 1000 || o.datos.periodos?.length !== 1 || o.datos.periodos.includes(periodo?.id));
    const fila = document.createElement('tr'); fila.append(colorearNombre(nodo('th', u.nombre),u.id_usuario), nodo('td', cargo ? `${dinero(cargo.pagado)} / ${dinero(cargo.importe)}` : 'Sin cargo en esta actividad'), nodo('td', dinero(u.saldo)));
    const acciones = document.createElement('td'); acciones.className = 'cu-acciones';
    if (pendiente) acciones.append(nodo('span', 'Pendiente de sincronizar / revisar'));
    else if (cobra()) {
      if (cargo && !cargo.cerrado && cargo.pagado === 0 && periodo.fecha <= hoy() && !periodo.legado) {
        const label = document.createElement('label'); const check = document.createElement('input'); check.type = 'checkbox'; check.checked = marcados.has(u.id_usuario); check.disabled = ocupado;
        check.addEventListener('change', () => { check.checked ? marcados.add(u.id_usuario) : marcados.delete(u.id_usuario); pintar(); });
        label.append(check, document.createTextNode(' Recibí $10')); acciones.append(label);
      } else acciones.append(nodo('span', cargo?.pagado >= cargo?.importe ? 'Pagado' : 'Pendiente'));
      if (admin() && !pendientes.length) { const b = boton('Abono / anticipo', () => abrir('pago', u)); b.disabled = ocupado; acciones.append(b); if (u.saldo > 0 && cargo?.cerrado) acciones.append(boton('Aplicar saldo', () => abrir('saldo', u))); }
    } else acciones.append(nodo('span', cargo?.pagado >= cargo?.importe ? 'Pagado' : 'Pendiente'));
    fila.append(acciones); $('cuLista').append(fila);
  }
  const grupo = admin() ? $('cuUnidad').value : (perfil.id_unidad || 'sin-unidad');
  const cargosUnidad = p.cargos.filter(c => c.periodo === periodo?.id && (c.id_unidad || 'sin-unidad') === grupo);
  const cerrado = cargosUnidad.length && cargosUnidad.every(c => c.cerrado);
  $('cuCerrar').hidden = !cobra() || !grupo || !cargosUnidad.length || Boolean(cerrado);
  $('cuCerrar').disabled = ocupado || guardando || !navigator.onLine || Boolean(local.cola.length) || Boolean(marcados.size) || cargosUnidad.some(c => typeof c.cerrado !== 'boolean');
  $('cuCierreEstado').textContent = cerrado ? 'Cobro de unidad cerrado' : cobra() && grupo && cargosUnidad.length && !navigator.onLine ? 'Conecta y actualiza para cerrar el cobro.' : '';
  $('cuVacio').textContent = !p.integrantes.length ? 'No tienes cuotas asignadas ni permiso de cobro en este módulo.' : !periodo ? 'La directiva debe preparar las actividades con cobro.' : '';
  $('cuPendientes').hidden = !local.cola.length; $('cuCola').replaceChildren();
  for (const o of local.cola) {
    const u = p.integrantes.find(x => x.id_usuario === o.datos.id_usuario);
    const div = nodo('div', `${u?.nombre || 'Calendario'} · ${o.accion} ${o.datos.importe ? dinero(o.datos.importe) : ''} · ${o.error || 'Pendiente de sincronizar'}`);
    if (o.error && o.revisar) {
      div.append(boton('Resolver registro', async () => {
        if (ocupado || !navigator.onLine) return mensaje('Conecta el dispositivo para revisar este registro.');
        if (!confirm('Revisa el historial actualizado antes de descartarlo. Si el dinero NO está registrado, vuelve a capturarlo después. ¿Quitar este intento pendiente?')) return;
        await localCuotas(cuenta, d => {
          const posicion = d.cola.findIndex(x => x.id === o.id);
          for (const posterior of d.cola.slice(posicion + 1)) if (posterior.datos.id_usuario === o.datos.id_usuario) {
            posterior.revisar = true; posterior.error = 'Se descartó un pago anterior. Revisa el historial y vuelve a capturar este movimiento si falta.';
          }
          d.cola = d.cola.filter(x => x.id !== o.id);
        }); await cargar();
      }));
    }
    $('cuCola').append(div);
  }
  $('cuTabBitacora').hidden = !admin();
  $('cuBitacora').replaceChildren();
  if (admin()) for (const e of p.bitacora || []) {
    const tr = document.createElement('tr');
    const accion = { pago: 'Pago', saldo: 'Saldo aplicado', corregir: 'Corrección', anular: 'Anulación', cerrar: 'Cierre de cobro', reabrir: 'Reapertura' }[e.accion] || e.accion;
    tr.append(nodo('td', new Date(e.fecha).toLocaleString('es-MX')), nodo('td', e.autor), nodo('td', accion), nodo('td', p.integrantes.find(u => u.id_usuario === e.id_usuario)?.nombre || (e.periodo ? `${etiquetaPeriodo(p.periodos.find(x => x.id === e.periodo))} · ${p.integrantes.find(u => (u.id_unidad || 'sin-unidad') === e.unidad)?.unidad || e.unidad}` : 'Actividad')), nodo('td', e.motivo || '—'));
    $('cuBitacora').append(tr);
  }
  pintarSecciones(); pintarVistaHistorial();
}
function pintarSecciones() {
  if (pestaña === 'bitacora' && !admin()) pestaña = 'cobro';
  $('cuVistaCobro').hidden = pestaña !== 'cobro';
  $('cuVistaHistorial').hidden = pestaña !== 'historial';
  $('cuAuditoria').hidden = pestaña !== 'bitacora' || !admin();
  for (const [id, valor] of [['cuTabCobro', 'cobro'], ['cuTabHistorial', 'historial'], ['cuTabBitacora', 'bitacora']]) $(id).setAttribute('aria-pressed', String(pestaña === valor));
}
function cambiarSeccion(valor) {
  if (!puedeSalirCuotas()) return;
  marcados.clear(); pestaña = valor; pintar();
}
function pintarVistaHistorial() {
  const p = local?.panel; if (!p) return;
  const individual = !cobra();
  if (individual) { historialVista = 'integrante'; historialUsuario = p.integrantes[0]?.id_usuario || null; }
  $('cuPorUnidad').hidden = individual; $('cuPorIntegrante').hidden = individual;
  $('cuHistUnidadCampo').hidden = !admin() || Boolean(historialUsuario);
  $('cuMiUnidad').textContent = !admin() && !individual ? (p.integrantes[0]?.unidad || '') : '';
  $('cuMiUnidad').hidden = !$('cuMiUnidad').textContent;
  $('cuPorUnidad').setAttribute('aria-pressed', String(historialVista === 'unidad'));
  $('cuPorIntegrante').setAttribute('aria-pressed', String(historialVista === 'integrante'));
  $('cuHistMatriz').hidden = historialVista !== 'unidad';
  $('cuHistDirectorio').hidden = historialVista !== 'integrante' || Boolean(historialUsuario);
  $('cuHistDetalle').hidden = !historialUsuario;
  $('cuHistVolver').hidden = individual;
  const usuarios = p.integrantes.filter(u => !admin() || (u.id_unidad || 'sin-unidad') === $('cuHistUnidad').value);
  const periodos = p.periodos.slice().reverse().filter(periodo => p.cargos.some(c => c.periodo === periodo.id && usuarios.some(u => u.id_usuario === c.id_usuario)));
  $('cuMatriz').replaceChildren();
  const head = document.createElement('thead'), cabecera = document.createElement('tr');
  for (const titulo of ['Integrante', ...periodos.map(etiquetaPeriodo), 'Total aplicado']) { const th = nodo('th', titulo); th.scope = 'col'; cabecera.append(th); }
  head.append(cabecera); $('cuMatriz').append(head);
  const body = document.createElement('tbody');
  for (const u of [...usuarios].sort(ordenarIntegrantes)) {
    const fila = document.createElement('tr'), nombre = nodo('th', u.nombre); nombre.scope = 'row';colorearNombre(nombre,u.id_usuario); fila.append(nombre); let total = 0;
    for (const periodo of periodos) {
      const cargo = p.cargos.find(c => c.periodo === periodo.id && c.id_usuario === u.id_usuario);
      const td = nodo('td', cargo ? dinero(cargo.pagado) : '—');
      if (cargo) { total += cargo.pagado; td.title = `${dinero(cargo.pagado)} de ${dinero(cargo.importe)}`; td.dataset.estado = cargo.pagado >= cargo.importe ? 'pagado' : 'pendiente'; }
      fila.append(td);
    }
    fila.append(nodo('td', dinero(total))); body.append(fila);
  }
  if (!usuarios.length) { const row = document.createElement('tr'), td = nodo('td', 'No hay integrantes.'); td.colSpan = periodos.length + 2; row.append(td); body.append(row); }
  $('cuMatriz').append(body);
  const buscar = $('cuBuscar').value.toLocaleLowerCase('es').normalize('NFD').replace(/[\u0300-\u036f]/g, '');
  const encontrados = usuarios.filter(u => u.nombre.toLocaleLowerCase('es').normalize('NFD').replace(/[\u0300-\u036f]/g, '').includes(buscar));
  $('cuIntegrantes').replaceChildren();
  for (const u of [...encontrados].sort(ordenarIntegrantes)) {
    const b = boton('', () => { historialUsuario = u.id_usuario; pintarVistaHistorial(); $('cuHistNombre').focus(); }); b.className = 'cu-integrante';
    const avatar = nodo('span', u.nombre.split(/\s+/).slice(0, 2).map(n => n[0]).join('')); avatar.className = 'cu-avatar';colorearAvatar(avatar,u.id_usuario,u); avatar.setAttribute('aria-hidden', 'true');
    const texto = nodo('span', ''); texto.append(colorearNombre(nodo('strong', u.nombre),u.id_usuario), nodo('small', u.unidad)); b.append(avatar, texto); $('cuIntegrantes').append(b);
  }
  if (!encontrados.length) $('cuIntegrantes').append(nodo('p', 'No hay integrantes que coincidan.'));
  $('cuHistNombre').textContent = p.integrantes.find(u => u.id_usuario === historialUsuario)?.nombre || '';
  $('cuHistNombre').tabIndex = -1;colorearNombre($('cuHistNombre'),historialUsuario);
  pintarHistorial();
}
function pintarHistorial() {
  const p = local?.panel; if (!p) return;
  const id = historialUsuario; $('cuHistorial').replaceChildren();
  const ingresos = p.ingresos.filter(i => i.id_usuario === id);
  for (const i of ingresos) {
    const tr = document.createElement('tr');
    const aplicadas = p.aplicaciones.filter(a => a.ingreso === i.id).map(a => etiquetaPeriodo(p.periodos.find(x => x.id === a.periodo)));
    tr.append(nodo('td', i.fecha), nodo('td', dinero(i.importe)), nodo('td', aplicadas.join(' · ') || (i.anulado ? 'Anulado' : 'Saldo a favor')), nodo('td', `${i.registrado_por}${i.anulado ? ' · Anulado' : ''}`));
    const td = document.createElement('td');
    if (admin() && !i.anulado && !local.cola.some(o => o.datos.id_usuario === id)) {
      const u = p.integrantes.find(x => x.id_usuario === id);
      td.append(boton('Corregir', () => abrir('corregir', u, i)), boton('Anular', () => abrir('anular', u, i)));
    }
    tr.append(td); $('cuHistorial').append(tr);
  }
}
function abrir(accion, u, ingreso) {
  if (ocupado) return;
  editando = { accion, u, ingreso }; $('cuFormulario').reset(); $('cuError').textContent = '';
  $('cuTitulo').textContent = `${{ pago: 'Registrar ingreso', saldo: 'Aplicar saldo', corregir: 'Corregir ingreso', anular: 'Anular ingreso' }[accion]} · ${u.nombre}`;
  $('cuAyuda').textContent = accion === 'pago' ? 'Registra el dinero recibido una sola vez. Por ejemplo, $50 pueden cubrir cinco cuotas de $10.' : 'El cambio conservará su autor y motivo en la bitácora.';
  $('cuMontoCampo').hidden = !['pago', 'corregir'].includes(accion); $('cuMonto').disabled = $('cuMontoCampo').hidden;
  $('cuMonto').value = ingreso ? ingreso.importe / 100 : 10;
  $('cuFechaCampo').hidden = accion !== 'pago'; $('cuFechaPago').disabled = accion !== 'pago'; $('cuFechaPago').value = hoy(); $('cuFechaPago').max = hoy();
  $('cuAplicar').hidden = !['pago', 'saldo'].includes(accion); $('cuNota').required = ['anular', 'corregir'].includes(accion); $('cuNota').minLength = $('cuNota').required ? 3 : 0;
  $('cuOpciones').replaceChildren();
  for (const p of local.panel.periodos.slice().reverse()) {
    const c = local.panel.cargos.find(c => c.periodo === p.id && c.id_usuario === u.id_usuario);
    if (!c || c.pagado >= c.importe) continue;
    const label = document.createElement('label'), check = document.createElement('input'); check.type = 'checkbox'; check.value = p.id; check.checked = p.id === $('cuPeriodo').value;
    label.append(check, document.createTextNode(` ${etiquetaPeriodo(p)} · pendiente ${dinero(c.importe - c.pagado)}`)); $('cuOpciones').append(label);
  }
  $('cuDialogo').showModal();
}
async function cargar() {
  const rev = revision, id = cuenta, propietario = perfil;
  const panel = await obtenerCuotas();
  if (rev !== revision) return;
  const actual = await localCuotas(id, d => { d.panel = panel; d.perfil = propietario; d.actualizado = Date.now(); });
  if (rev !== revision) return;
  local = actual;
  recordarCuenta(id); pintar();
}
export async function abrirCuotas(p, id) {
  perfil = p; cuenta = id; const rev = ++revision;
  try { const actual = await localCuotas(id); if (rev !== revision) return; local = actual;
    if (navigator.onLine) { await cargar(); if (rev !== revision) return; await sincronizar(); }
    else { pintar(); mensaje(local.panel ? 'Sin conexión: puedes guardar cuotas en este dispositivo.' : 'Conecta el dispositivo y prepara la lista antes de usarla sin internet.'); }
  } catch (error) { if (rev === revision) mensaje(error.message || 'No se pudo cargar cuotas.'); }
}
async function sincronizar() {
  if (!cuenta || ocupado || !navigator.onLine) return;
  ocupado = true; const rev = revision, id = cuenta; pintar();
  try {
    await verificarCuenta(id);
    const d = await localCuotas(id);
    const bloqueados = new Set();
    for (const o of d.cola) {
      if (rev !== revision) return;
      if (o.revisar) { if (o.accion === 'cerrar') break; bloqueados.add(o.datos.id_usuario); continue; }
      if (bloqueados.has(o.datos.id_usuario)) {
        await localCuotas(id, d => { const item = d.cola.find(x => x.id === o.id); if (item) { item.revisar = true; item.error = 'Un pago anterior de este integrante necesita revisión. Comprueba ambos movimientos antes de recapturar.'; } });
        continue;
      }
      try {
        await enviarCuota(o);
        await localCuotas(id, d => { d.cola = d.cola.filter(x => x.id !== o.id); });
      } catch (e) {
        const revisar = ['40001', '42501', '22023', '23505', '22P02'].includes(e.code);
        await localCuotas(id, d => { const item = d.cola.find(x => x.id === o.id); if (item) { item.error = e.message || 'Sin confirmación del servidor. Se reintentará con el mismo identificador.'; item.revisar = revisar; } });
        bloqueados.add(o.datos.id_usuario);
        if (!revisar || o.accion === 'cerrar') break;
      }
    }
    await cargar();
    if (rev === revision) mensaje(local.cola.length ? 'Hay movimientos pendientes. Revisa el aviso de cada uno; no se han duplicado.' : 'Todos los movimientos están sincronizados.');
    return rev === revision;
  } catch (e) { if (rev === revision) { local = await localCuotas(id); mensaje(e.message || 'Sin conexión. Los movimientos siguen guardados aquí.'); } }
  finally { if (rev === revision) { ocupado = false; pintar(); } }
}
async function guardar(accion, datos) {
  if (local?.cola.some(o => o.accion === 'cerrar')) throw new Error('Actualiza o resuelve el cierre pendiente antes de registrar más movimientos.');
  if (!cuenta || !local?.panel) throw new Error('Prepara la lista primero.');
  local = await guardarOperacion(cuenta, { id: crypto.randomUUID(), accion, datos: { id_ciclo: local.panel.id_ciclo, epoca: local.panel.epoca, ...datos }, guardado: new Date().toISOString() });
  mensaje('Guardado en este dispositivo. Pendiente de sincronizar.');
}
$('cuFormulario').addEventListener('submit', async e => {
  e.preventDefault(); if (ocupado || guardando || !editando) return;
  guardando = true;
  try {
    const { accion, u, ingreso } = editando;
    await guardar(accion, { id_usuario: u.id_usuario, version: u.version, importe: Math.round(Number($('cuMonto').value) * 100), fecha: $('cuFechaPago').value, periodos: [...$('cuOpciones').querySelectorAll('input:checked')].map(c => c.value), nota: $('cuNota').value.trim(), motivo: $('cuNota').value.trim(), ingreso: ingreso?.id || null });
    editando = null; $('cuDialogo').close(); pintar(); await sincronizar();
  } catch (e) { $('cuError').textContent = e.message; }
  finally { guardando = false; pintar(); }
});
$('cuCancelar').onclick = () => { editando = null; $('cuDialogo').close(); };
$('cuDialogo').addEventListener('cancel', () => { editando = null; });
$('cuGuardar').onclick = async () => {
  if (ocupado || guardando || !marcados.size) return;
  guardando = true;
  $('cuGuardar').disabled = true;
  try {
    const periodo = local.panel.periodos.find(p => p.id === $('cuPeriodo').value);
    for (const id of [...marcados]) { const u = local.panel.integrantes.find(u => u.id_usuario === id); await guardar('pago', { id_usuario: id, version: u.version, importe: 1000, fecha: periodo.fecha, periodos: [periodo.id] }); marcados.delete(id); }
    pintar(); await sincronizar();
  } catch (e) { mensaje(e.message); pintar(); }
  finally { guardando = false; pintar(); }
};
async function actualizar() {
  if (!puedeSalirCuotas()) return; marcados.clear(); if (!await sincronizar()) return;
  try {
    if (!('serviceWorker' in navigator)) throw new Error('Este navegador no permite preparar la app sin conexión.');
    await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => setTimeout(() => reject(new Error('Aún no termina de descargar la app. Reintenta con conexión.')), 15000))]);
    if (navigator.storage?.persist) await navigator.storage.persist();
    if (!local.cola.length) mensaje('Actualizado. Disponible sin conexión.');
  } catch (e) { mensaje(e.message); }
}
$('cuCerrar').onclick = async () => {
  if (ocupado || guardando || !navigator.onLine || local.cola.length || marcados.size) return;
  const periodo = $('cuPeriodo').value, unidad = admin() ? $('cuUnidad').value : (perfil.id_unidad || 'sin-unidad');
  const cargos = local.panel.cargos.filter(c => c.periodo === periodo && (c.id_unidad || 'sin-unidad') === unidad);
  if (!cargos.length || cargos.some(c => c.cerrado || typeof c.cerrado !== 'boolean')) return;
  if (!confirm('¿Cerrar el cobro de esta unidad? Se aplicará el saldo a favor a las cuotas pendientes.')) return;
  guardando = true;
  try {
    await guardar('cerrar', { periodo, unidad, versiones: Object.fromEntries(cargos.map(c => [c.id_usuario, local.panel.integrantes.find(u => u.id_usuario === c.id_usuario)?.version])) });
    await sincronizar();
  } catch (e) { mensaje(e.message); }
  finally { guardando = false; pintar(); }
};
$('cuSync').onclick = () => void actualizar();
$('cuPeriodo').onchange = cambiaFiltro;
$('cuUnidad').onchange = cambiaFiltro;
$('cuTabCobro').onclick = () => cambiarSeccion('cobro');
$('cuTabHistorial').onclick = () => cambiarSeccion('historial');
$('cuTabBitacora').onclick = () => { if (admin()) cambiarSeccion('bitacora'); };
$('cuPorUnidad').onclick = () => { historialVista = 'unidad'; historialUsuario = null; pintarVistaHistorial(); };
$('cuPorIntegrante').onclick = () => { historialVista = 'integrante'; historialUsuario = null; pintarVistaHistorial(); };
$('cuHistUnidad').onchange = () => { historialUsuario = null; pintarVistaHistorial(); };
$('cuBuscar').oninput = pintarVistaHistorial;
$('cuHistVolver').onclick = () => { historialUsuario = null; pintarVistaHistorial(); };

window.addEventListener('online', () => { if (!vista.hidden) void sincronizar(); });
window.addEventListener('offline', () => { if (!vista.hidden) { mensaje('Sin conexión. Guarda los pagos antes de cerrar la app.'); pintar(); } });
window.addEventListener('beforeunload', e => { if (marcados.size || editando) { e.preventDefault(); e.returnValue = ''; } });
