// frontend/js/modules/asistencias.js
import {
  listarReuniones,
  crearReunion,
  obtenerReunion,
  actuarReunion,
  obtenerListaAsistencias,
  obtenerHistorialAsistencias,
} from '../services/asistencias.js';

const estilo = document.createElement('link');
estilo.rel = 'stylesheet';
estilo.href = new URL('../../css/asistencias.css', import.meta.url).href;
document.head.append(estilo);

const entrada = document.createElement('a');
entrada.href = '#asistencias';
entrada.className = 'modulo';
entrada.innerHTML = `
  <span class="modulo-icono" aria-hidden="true">✓</span>
  <span class="sobre-titulo">VIDA DEL CLUB</span>
  <h2>Asistencias</h2>
  <p>Pases de lista por unidad e historial de reuniones.</p>
  <strong>Entrar al módulo →</strong>
`;

document.querySelector('#inicio .menu-grid').append(entrada);

const vista = document.createElement('section');
vista.id = 'vistaAsistencias';
vista.className = 'vista';
vista.hidden = true;
vista.innerHTML = `
  <span class="sobre-titulo">VIDA DEL CLUB</span>
  <h1>Asistencias</h1>
  <p id="asMensaje" class="aviso" role="status" hidden></p>

  <fieldset id="asCampos" class="as-panel">
    <legend>Reuniones e historial</legend>

    <div class="acciones">
      <button id="asDia" type="button" class="boton-volver">
        Reuniones
      </button>
      <button id="asHistorial" type="button" class="boton-volver">
        Historial
      </button>
      <button id="asRecargar" type="button" class="boton-volver">
        Recargar
      </button>
    </div>

    <section id="asVistaReunion">
      <div id="asCrearPanel" class="as-filtros" hidden>
        <label>
          Fecha de la reunión
          <input id="asNuevaFecha" type="date" required>
        </label>
        <button id="asCrear" class="boton-volver" type="button">
          Crear o abrir reunión
        </button>
      </div>

      <label class="as-selector">
        Reunión
        <select id="asReunion"></select>
      </label>

      <p id="asAvisoReunion" class="texto-suave"></p>

      <nav
        id="asGrupos"
        class="acciones"
        aria-label="Unidades del pase"
      ></nav>

      <h2 id="asUnidadTitulo"></h2>
      <p id="asResumen" class="texto-suave"></p>

      <ul
        id="asLista"
        class="as-lista"
        aria-label="Integrantes convocados"
      ></ul>

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

    <section id="asVistaHistorial" hidden>
      <label class="as-selector">
        Integrante
        <select id="asPersona"></select>
      </label>
      <p id="asResumenHistorial" class="texto-suave"></p>
      <ul
        id="asListaHistorial"
        class="as-lista"
        aria-label="Historial personal"
      ></ul>
    </section>
  </fieldset>
`;

document.getElementById('aplicacion').append(vista);

const $ = id => document.getElementById(id);

const etiquetas = {
  asistencia: 'Asistencia',
  falta: 'Falta',
  justificado: 'Justificado',
};

let perfil = null;
let panel = null;
let grupo = '';
let modo = 'reunion';
let revision = 0;
let ocupado = false;
let guardando = false;
let sucio = false;
let estados = new Map();

const admin = () => perfil?.rol === 'directiva';

function mensaje(texto) {
  $('asMensaje').textContent = texto;
  $('asMensaje').hidden = !texto;
}

function bloquear(valor) {
  ocupado = valor;
  $('asCampos').disabled = valor;
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
  perfil = null;
  panel = null;
  grupo = '';
  sucio = false;
  guardando = false;
  estados.clear();

  bloquear(false);
  mensaje('');

  for (const id of [
    'asLista',
    'asListaHistorial',
    'asGrupos',
    'asReunion',
    'asPersona',
  ]) {
    $(id).replaceChildren();
  }

  for (const id of [
    'asUnidadTitulo',
    'asResumen',
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
  $('asGrupos').replaceChildren();
  $('asLista').replaceChildren();
  $('asAccionesAdmin').hidden = !admin() || !panel;

  if (!panel) {
    $('asUnidadTitulo').textContent = '';
    $('asResumen').textContent = '';
    $('asAvisoReunion').textContent = 'No hay reuniones disponibles.';
    return;
  }

  if (!panel.grupos.some(g => g.clave === grupo)) {
    grupo =
      panel.grupos.find(g => g.clave === panel.clave_actor)?.clave ||
      panel.grupos[0]?.clave ||
      '';
  }

  const seleccion = panel.grupos.find(g => g.clave === grupo);

  // Solo la directiva navega entre unidades.
  // Capitanes y consejeros ven directamente su unidad.
  if (admin()) {
    for (const g of panel.grupos) {
      const b = boton(
        `${g.nombre} · ${g.revisada ? 'Revisada ✓' : 'Pendiente'}`,
        () => {
          if (ocupado || !puedeSalirAsistencias()) return;

          sucio = false;
          grupo = g.clave;
          pintarPanel();
        }
      );

      b.setAttribute('aria-pressed', String(g.clave === grupo));
      $('asGrupos').append(b);
    }
  }

  $('asUnidadTitulo').textContent =
    seleccion?.nombre || 'Mi asistencia';

  const revisadas = panel.grupos.filter(g => g.revisada).length;

  $('asAvisoReunion').textContent =
    panel.estado === 'anulada'
      ? 'Reunión anulada: no cuenta en el historial ni en el dashboard.'
      : panel.estado === 'cerrada'
        ? 'Pase cerrado. Las correcciones se reflejan en el historial y el dashboard.'
        : `${panel.importada ? 'Fecha importada: revisa si corresponde a una reunión real. ' : ''}Borrador: todavía no cuenta como reunión. ${
            admin()
              ? `${revisadas}/${panel.grupos.length} unidades revisadas. Al cerrar, quienes no estén marcados como presentes o justificados quedarán con falta.`
              : 'Los estados serán definitivos cuando la directiva cierre el pase.'
          }`;

  const filas = panel.integrantes.filter(u => u.clave === grupo);

  estados = new Map(filas.map(u => [u.id_usuario, u.estado]));
  $('asResumen').textContent = resumen(filas);

  for (const u of filas) {
    const li = document.createElement('li');
    li.className = 'as-fila';

    const datos = document.createElement('div');
    const nombre = document.createElement('strong');
    nombre.textContent = u.nombre;
    datos.append(nombre);

    if (u.motivo) {
      const nota = document.createElement('small');
      nota.textContent = `Justificación: ${u.motivo}`;
      datos.append(nota);
    }

    const acciones = document.createElement('div');
    acciones.className = 'as-controles';

    if (admin() && panel.estado !== 'anulada') {
      const select = document.createElement('select');
      select.setAttribute('aria-label', `Estado de ${u.nombre}`);

      select.append(
        ...Object.entries(etiquetas).map(
          ([valor, texto]) => new Option(texto, valor)
        )
      );

      select.value = u.estado;

      select.addEventListener('change', () => {
        estados.set(u.id_usuario, select.value);

        sucio = filas.some(
          f => estados.get(f.id_usuario) !== f.estado
        );

        $('asCerrar').disabled =
          sucio ||
          panel.estado !== 'borrador' ||
          revisadas !== panel.grupos.length ||
          panel.fecha > panel.hoy;
      });

      acciones.append(select);
    } else {
      const estado = document.createElement('span');
      estado.className = 'as-estado';
      estado.dataset.estado = u.estado;
      estado.textContent = etiquetas[u.estado];
      acciones.append(estado);

      if (
        panel.puede_justificar &&
        u.puede_justificar &&
        panel.estado !== 'anulada' &&
        u.estado !== 'justificado'
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

  if (perfil.rol === 'capitan') {
    $('asAvisoReunion').textContent +=
      ' Puedes marcar justificado únicamente el día de la reunión (hora de Ciudad de México).';
  }

  $('asGuardar').hidden = panel.estado === 'anulada';
  $('asGuardar').disabled = !filas.length;

  $('asGuardar').textContent = panel.estado === 'cerrada'
    ? 'Guardar correcciones de la unidad'
    : 'Revisar y guardar unidad';

  $('asCerrar').hidden = panel.estado !== 'borrador';

  $('asCerrar').disabled =
    revisadas !== panel.grupos.length ||
    panel.fecha > panel.hoy;

  $('asAnular').hidden = panel.estado === 'anulada';
  $('asRestaurar').hidden = panel.estado !== 'anulada';
}

async function cargarReuniones(id = $('asReunion').value) {
  const actual = ++revision;

  bloquear(true);
  mensaje('Cargando reuniones…');

  try {
    const lista = await listarReuniones();

    if (actual !== revision) return;

    $('asReunion').replaceChildren(...lista.map(r => new Option(
      `${r.fecha} · ${r.estado}${
        r.importada && r.estado === 'borrador'
          ? ' · Revisar datos anteriores'
          : ''
      }`,
      r.id
    )));

    const elegido =
      lista.find(r => r.id === id)?.id ||
      lista[0]?.id;

    if (elegido) $('asReunion').value = elegido;

    const resultado = elegido
      ? await obtenerReunion(elegido)
      : null;

    if (actual !== revision) return;

    panel = resultado;
    sucio = false;
    pintarPanel();
    mensaje('');
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

async function cargarHistorial() {
  const actual = ++revision;

  bloquear(true);
  mensaje('Cargando historial…');

  $('asListaHistorial').replaceChildren();
  $('asResumenHistorial').textContent = '';

  try {
    const filas = $('asPersona').value
      ? await obtenerHistorialAsistencias($('asPersona').value)
      : [];

    if (actual !== revision) return;

    for (const r of filas) {
      const li = document.createElement('li');
      li.className = 'as-fila';

      const fecha = document.createElement('time');
      fecha.dateTime = r.fecha;
      fecha.textContent = r.fecha;

      const estado = document.createElement('span');
      estado.className = 'as-estado';
      estado.dataset.estado = r.estado;
      estado.textContent = etiquetas[r.estado];

      li.append(fecha, estado);
      $('asListaHistorial').append(li);
    }

    $('asResumenHistorial').textContent =
      `${resumen(filas)}. Solo reuniones cerradas.`;

    mensaje('');
  } catch (error) {
    if (actual === revision) {
      mensaje(error.message || 'No se pudo cargar el historial.');
    }
  } finally {
    if (actual === revision) bloquear(false);
  }
}

async function cambiarModo(nuevo) {
  if (ocupado || !puedeSalirAsistencias()) return;

  sucio = false;
  modo = nuevo;

  $('asVistaReunion').hidden = modo !== 'reunion';
  $('asVistaHistorial').hidden = modo !== 'historial';

  if (modo === 'reunion') {
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
    mensaje(
      accion === 'justificar'
        ? 'Justificación guardada directamente.'
        : accion === 'unidad' && panel.estado === 'borrador'
          ? 'Unidad revisada. Completa los grupos pendientes y cierra el pase para registrarlo.'
          : 'Cambios guardados. El historial y el dashboard usan las reuniones cerradas.'
    );
  }
}

export async function abrirAsistencias(cuenta) {
  reiniciarAsistencias();
  perfil = cuenta;
  modo = 'reunion';

  $('asVistaReunion').hidden = false;
  $('asVistaHistorial').hidden = true;
  $('asCrearPanel').hidden = !admin();
  $('asNuevaFecha').value = hoy();

  const actual = revision;

  bloquear(true);

  try {
    const lista = await obtenerListaAsistencias();

    if (actual !== revision) return;

    $('asPersona').replaceChildren(...lista.map(u => new Option(
      `${u.nombres} ${u.apellido}`,
      u.id_usuario
    )));

    if (lista.some(u => u.id_usuario === cuenta.id_usuario)) {
      $('asPersona').value = cuenta.id_usuario;
    }

    await cargarReuniones();
  } catch (error) {
    if (actual === revision) {
      mensaje(error.message);
      bloquear(false);
    }
  }
}

$('asCrear').addEventListener('click', async () => {
  if (
    ocupado ||
    !puedeSalirAsistencias() ||
    !$('asNuevaFecha').reportValidity()
  ) {
    return;
  }

  const actual = revision;

  guardando = true;
  bloquear(true);

  let id;

  try {
    id = await crearReunion($('asNuevaFecha').value);
  } catch (error) {
    if (actual === revision) mensaje(error.message);
  } finally {
    if (actual === revision) {
      guardando = false;
      bloquear(false);
    }
  }

  if (actual === revision && id) {
    sucio = false;
    grupo = '';
    await cargarReuniones(id);
  }
});

$('asReunion').addEventListener('change', () => {
  if (ocupado || !puedeSalirAsistencias()) {
    $('asReunion').value = panel?.id || '';
    return;
  }

  sucio = false;
  grupo = '';
  void cargarReuniones();
});

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
    'Motivo de anulación (por ejemplo: fecha de prueba). Esta reunión dejará de contar para todos:'
  );

  if (motivo !== null) void ejecutar('anular', { motivo });
});

$('asRestaurar').addEventListener('click', () => {
  void ejecutar('restaurar');
});

$('asDia').addEventListener('click', () => {
  void cambiarModo('reunion');
});

$('asHistorial').addEventListener('click', () => {
  void cambiarModo('historial');
});

$('asRecargar').addEventListener('click', () => {
  void cambiarModo(modo);
});

$('asPersona').addEventListener('change', () => {
  void cargarHistorial();
});

window.addEventListener('beforeunload', evento => {
  if (sucio || guardando) {
    evento.preventDefault();
    evento.returnValue = '';
  }
});