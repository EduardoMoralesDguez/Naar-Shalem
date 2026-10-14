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
 <span class="sobre-titulo">TESORERÍA DEL CLUB</span><h1>Cuotas</h1>
 <div class="aviso cu-estado"><p id="cuEstado" role="status"></p><span id="cuPreparacion"></span></div>
 <div class="acciones"><button id="cuPreparar" class="boton-principal">Preparar / actualizar sin conexión</button><button id="cuSync" class="boton-volver">Sincronizar pendientes</button></div>
 <section id="cuPendientes" class="cu-panel" hidden><h2>Guardado en este dispositivo</h2><p>Estos movimientos todavía no están confirmados en Supabase. Se enviarán con la cuenta que los capturó.</p><div id="cuCola"></div></section>
 <section id="cuCalendario" class="cu-panel" hidden><h2>Actividades</h2><a href="#calendario" class="boton-volver">Abrir calendario</a></section>
 <section class="cu-panel"><div class="cu-form"><label>Actividad<select id="cuPeriodo"></select></label><label id="cuUnidadCampo">Unidad<select id="cuUnidad"></select></label></div>
 <div class="cu-scroll"><table class="cu-tabla"><caption>Registro de cuotas</caption><thead><tr><th>Integrante</th><th>Aplicado / cuota</th><th>Saldo a favor</th><th>Registro</th></tr></thead><tbody id="cuLista"></tbody></table></div>
 <p id="cuVacio"></p><button id="cuGuardar" class="boton-principal" hidden>Guardar pagos marcados</button></section>
 <section class="cu-panel"><h2>Historial de ingresos</h2><label>Integrante<select id="cuHistUsuario"></select></label><div class="cu-scroll"><table class="cu-tabla"><thead><tr><th>Fecha</th><th>Importe</th><th>Aplicación</th><th>Registró / estado</th><th>Acciones</th></tr></thead><tbody id="cuHistorial"></tbody></table></div></section>
 <details id="cuAuditoria" class="cu-panel" hidden><summary>Bitácora de cambios</summary><div id="cuBitacora"></div></details>
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
  $('cuDialogo').close(); $('cuFormulario').reset();
  for (const id of ['cuLista', 'cuHistorial', 'cuCola', 'cuBitacora', 'cuPeriodo', 'cuUnidad', 'cuHistUsuario', 'cuPreparacion', 'cuEstado', 'cuOpciones', 'cuTitulo', 'cuAyuda', 'cuError', 'cuVacio']) $(id).replaceChildren();
  for (const id of ['cuCalendario', 'cuGuardar', 'cuAuditoria', 'cuPendientes']) $(id).hidden = true;
}
export async function pendientesCuotas(id) { return id ? (await localCuotas(id)).cola.length : 0; }
function pintar() {
  const p = local?.panel; if (!p) return;
  $('cuCalendario').hidden = !admin(); $('cuUnidadCampo').hidden = !admin();
  $('cuGuardar').hidden = !cobra(); $('cuGuardar').disabled = ocupado || !marcados.size;
  $('cuSync').disabled = ocupado || !navigator.onLine;
  $('cuPreparar').disabled = ocupado || !navigator.onLine;
  $('cuPreparacion').textContent = `Actualizado · ${new Date(local.actualizado).toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Mexico_City' })}`;
  const actuales = p.periodos.filter(x => !x.legado && x.fecha <= hoy());
  const visibles = admin() || !cobra() ? p.periodos : actuales.filter(p => p.fecha === actuales[0]?.fecha);
  opciones($('cuPeriodo'), visibles, r => r.id, etiquetaPeriodo);
  opciones($('cuUnidad'), [{ id: '', nombre: 'Todas las unidades' }, ...[...new Map(p.integrantes.map(u => [u.id_unidad || 'sin-unidad', { id: u.id_unidad || 'sin-unidad', nombre: u.unidad }])).values()]], r => r.id, r => r.nombre);
  seleccionPeriodo = $('cuPeriodo').value; seleccionUnidad = $('cuUnidad').value;
  opciones($('cuHistUsuario'), p.integrantes, r => r.id_usuario, r => r.nombre);
  $('cuLista').replaceChildren();
  const usuarios = p.integrantes.filter(u => !$('cuUnidad').value || (u.id_unidad || 'sin-unidad') === $('cuUnidad').value);
  const periodo = p.periodos.find(x => x.id === $('cuPeriodo').value);
  for (const u of usuarios) {
    const cargo = p.cargos.find(c => c.id_usuario === u.id_usuario && c.periodo === periodo?.id);
    const pendientes = local.cola.filter(o => o.datos.id_usuario === u.id_usuario);
    const pendiente = pendientes.some(o => o.revisar || o.error || o.accion !== 'pago' || o.datos.importe !== 1000 || o.datos.periodos?.length !== 1 || o.datos.periodos.includes(periodo?.id));
    const fila = document.createElement('tr'); fila.append(nodo('th', u.nombre), nodo('td', cargo ? `${dinero(cargo.pagado)} / ${dinero(cargo.importe)}` : 'Sin cargo en esta actividad'), nodo('td', dinero(u.saldo)));
    const acciones = document.createElement('td'); acciones.className = 'cu-acciones';
    if (pendiente) acciones.append(nodo('span', 'Pendiente de sincronizar / revisar'));
    else if (cobra()) {
      if (cargo && cargo.pagado === 0 && periodo.fecha <= hoy() && !periodo.legado) {
        const label = document.createElement('label'); const check = document.createElement('input'); check.type = 'checkbox'; check.checked = marcados.has(u.id_usuario); check.disabled = ocupado;
        check.addEventListener('change', () => { check.checked ? marcados.add(u.id_usuario) : marcados.delete(u.id_usuario); $('cuGuardar').disabled = !marcados.size; });
        label.append(check, document.createTextNode(' Recibí $10')); acciones.append(label);
      } else acciones.append(nodo('span', cargo?.pagado >= cargo?.importe ? 'Pagado' : 'Pendiente'));
      if (admin() && !pendientes.length) { const b = boton('Abono / anticipo', () => abrir('pago', u)); b.disabled = ocupado; acciones.append(b); if (u.saldo > 0) acciones.append(boton('Aplicar saldo', () => abrir('saldo', u))); }
    } else acciones.append(nodo('span', cargo?.pagado >= cargo?.importe ? 'Pagado' : 'Pendiente'));
    fila.append(acciones); $('cuLista').append(fila);
  }
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
  $('cuAuditoria').hidden = !admin();
  $('cuBitacora').replaceChildren(...(p.bitacora || []).map(e => nodo('p', `${new Date(e.fecha).toLocaleString('es-MX')} · ${e.autor} · ${e.accion} · ${p.integrantes.find(u => u.id_usuario === e.id_usuario)?.nombre || 'Calendario'} ${e.motivo || ''}`)));
  pintarHistorial();
}
function pintarHistorial() {
  const p = local?.panel; if (!p) return;
  const id = $('cuHistUsuario').value; $('cuHistorial').replaceChildren();
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
      if (o.revisar) { bloqueados.add(o.datos.id_usuario); continue; }
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
        if (!revisar) break;
      }
    }
    await cargar();
    if (rev === revision) mensaje(local.cola.length ? 'Hay movimientos pendientes. Revisa el aviso de cada uno; no se han duplicado.' : 'Todos los movimientos están sincronizados.');
    return rev === revision;
  } catch (e) { if (rev === revision) { local = await localCuotas(id); mensaje(e.message || 'Sin conexión. Los movimientos siguen guardados aquí.'); } }
  finally { if (rev === revision) { ocupado = false; pintar(); } }
}
async function guardar(accion, datos) {
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
  finally { guardando = false; }
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
  finally { guardando = false; }
};
$('cuPreparar').onclick = async () => {
  if (!puedeSalirCuotas()) return; marcados.clear(); if (!await sincronizar()) return;
  try {
    if (!('serviceWorker' in navigator)) throw new Error('Este navegador no permite preparar la app sin conexión.');
    await Promise.race([navigator.serviceWorker.ready, new Promise((_, reject) => setTimeout(() => reject(new Error('Aún no termina de descargar la app. Reintenta con conexión.')), 15000))]);
    if (navigator.storage?.persist) await navigator.storage.persist();
    mensaje('App y lista preparadas para usar sin conexión.');
  } catch (e) { mensaje(e.message); }
};
$('cuSync').onclick = () => void sincronizar();
$('cuPeriodo').onchange = cambiaFiltro;
$('cuUnidad').onchange = cambiaFiltro;
$('cuHistUsuario').onchange = pintarHistorial;
window.addEventListener('online', () => { if (!vista.hidden) void sincronizar(); });
window.addEventListener('offline', () => { if (!vista.hidden) { mensaje('Sin conexión. Guarda los pagos antes de cerrar la app.'); pintar(); } });
window.addEventListener('beforeunload', e => { if (marcados.size || editando) { e.preventDefault(); e.returnValue = ''; } });
