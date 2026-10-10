// frontend/js/modules/usuarios.js

const directorio = document.getElementById('directorio');
const tituloDirectorio = document.getElementById('directorioTitulo');
const buscador = document.getElementById('buscarIntegrante');
const filtroUnidad = document.getElementById('filtroUnidad');
const filtroRol = document.getElementById('filtroRol');
const filtroClase = document.getElementById('filtroClase');
const botonLimpiar = document.getElementById('limpiarFiltros');

const lista = document.getElementById('listaIntegrantes');
const estado = document.getElementById('estadoDirectorio');
const mensaje = document.getElementById('mensaje');

const navegacionPerfil = document.getElementById('navegacionPerfil');
const botonVolver = document.getElementById('volverIntegrantes');
const subtitulo = document.getElementById('subtituloPagina');

const tarjeta = document.getElementById('tarjeta');
const nombre = document.getElementById('tarjetaNombre');
const rol = document.getElementById('tarjetaRol');
const unidad = document.getElementById('tarjetaUnidad');
const clase = document.getElementById('tarjetaClase');

const SIN_ASIGNAR = '__sin_asignar__';

const NOMBRES_ROLES = {
  directiva: 'Directiva',
  consejero: 'Consejero',
  capitan: 'Capitán',
  conquistador: 'Conquistador',
};

let integrantes = [];
let usuarioSeleccionado = '';
let posicionDirectorio = 0;
let ultimoBoton = null;
let callbackSeleccion = null;
let callbackVolver = null;
let frameNavegacion = null;

function capitalizar(texto = '') {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function nombreRol(valor) {
  return NOMBRES_ROLES[valor] || capitalizar(valor || '');
}

function normalizar(texto) {
  return String(texto || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function valorAsignacion(valor) {
  return valor || SIN_ASIGNAR;
}

function obtenerIniciales(usuario) {
  const primera = usuario.nombres?.trim().charAt(0) || '';
  const segunda = usuario.apellido?.trim().charAt(0) || '';

  return `${primera}${segunda}`.toUpperCase() || 'NS';
}

function programarNavegacion(callback) {
  if (frameNavegacion !== null) {
    cancelAnimationFrame(frameNavegacion);
  }

  frameNavegacion = requestAnimationFrame(() => {
    frameNavegacion = null;
    callback();
  });
}

function deshabilitarControles(deshabilitado) {
  buscador.disabled = deshabilitado;
  filtroUnidad.disabled = deshabilitado;
  filtroRol.disabled = deshabilitado;
  filtroClase.disabled = deshabilitado;

  if (deshabilitado) {
    botonLimpiar.disabled = true;
  }
}

function hayFiltrosActivos() {
  return Boolean(
    buscador.value ||
    filtroUnidad.value ||
    filtroRol.value ||
    filtroClase.value
  );
}

function llenarFiltro(select, valores, textoTodos, obtenerEtiqueta) {
  const seleccionAnterior = select.value;
  const opciones = [...new Set(valores)].sort((a, b) =>
    obtenerEtiqueta(a).localeCompare(obtenerEtiqueta(b), 'es')
  );

  select.replaceChildren(new Option(textoTodos, ''));

  opciones.forEach((valor) => {
    select.appendChild(new Option(obtenerEtiqueta(valor), valor));
  });

  if (opciones.includes(seleccionAnterior)) {
    select.value = seleccionAnterior;
  }
}

function actualizarOpcionesFiltros() {
  // Las opciones se generan desde todos los integrantes cargados,
  // no únicamente desde los resultados de la búsqueda actual.
  llenarFiltro(
    filtroUnidad,
    integrantes.map((usuario) => valorAsignacion(usuario.unidad)),
    'Todas las unidades',
    (valor) => valor === SIN_ASIGNAR ? 'Sin unidad asignada' : valor
  );

  llenarFiltro(
    filtroRol,
    integrantes.map((usuario) => usuario.rol).filter(Boolean),
    'Todos los tipos',
    nombreRol
  );

  llenarFiltro(
    filtroClase,
    integrantes.map((usuario) => valorAsignacion(usuario.clase)),
    'Todas las clases',
    (valor) => valor === SIN_ASIGNAR ? 'Sin clase asignada' : valor
  );
}

function crearTarjetaIntegrante(usuario) {
  const item = document.createElement('li');
  item.className = 'integrante-item';

  const boton = document.createElement('button');
  boton.type = 'button';
  boton.className = 'integrante-boton';
  boton.dataset.usuarioId = usuario.id_usuario;
  boton.setAttribute(
    'aria-label',
    `Ver perfil de ${usuario.nombres} ${usuario.apellido}`
  );

  const avatar = document.createElement('span');
  avatar.className = 'integrante-avatar';
  avatar.textContent = obtenerIniciales(usuario);
  avatar.setAttribute('aria-hidden', 'true');

  const informacion = document.createElement('span');
  informacion.className = 'integrante-info';

  const nombreIntegrante = document.createElement('strong');
  nombreIntegrante.className = 'integrante-nombre';
  nombreIntegrante.textContent =
    `${usuario.nombres} ${usuario.apellido}`;

  const rolIntegrante = document.createElement('span');
  rolIntegrante.className = 'integrante-rol';
  rolIntegrante.textContent = nombreRol(usuario.rol);

  const detalles = document.createElement('span');
  detalles.className = 'integrante-detalles';

  const unidadIntegrante = document.createElement('span');
  unidadIntegrante.textContent =
    `Unidad: ${usuario.unidad || 'Sin asignar'}`;

  const claseIntegrante = document.createElement('span');
  claseIntegrante.textContent =
    `Clase: ${usuario.clase || 'Sin asignar'}`;

  detalles.append(unidadIntegrante, claseIntegrante);
  informacion.append(nombreIntegrante, rolIntegrante, detalles);

  const flecha = document.createElement('span');
  flecha.className = 'integrante-flecha';
  flecha.textContent = '→';
  flecha.setAttribute('aria-hidden', 'true');

  boton.append(avatar, informacion, flecha);
  item.appendChild(boton);

  return item;
}

function renderizarDirectorio() {
  const termino = normalizar(buscador.value);
  const unidadElegida = filtroUnidad.value;
  const rolElegido = filtroRol.value;
  const claseElegida = filtroClase.value;

  const filtrados = integrantes.filter((usuario) => {
    const contenido = normalizar([
      usuario.nombres,
      usuario.apellido,
      usuario.unidad,
      usuario.clase,
      nombreRol(usuario.rol),
    ].filter(Boolean).join(' '));

    const coincideBusqueda = contenido.includes(termino);

    const coincideUnidad =
      !unidadElegida ||
      valorAsignacion(usuario.unidad) === unidadElegida;

    const coincideRol =
      !rolElegido || usuario.rol === rolElegido;

    const coincideClase =
      !claseElegida ||
      valorAsignacion(usuario.clase) === claseElegida;

    return (
      coincideBusqueda &&
      coincideUnidad &&
      coincideRol &&
      coincideClase
    );
  });

  const fragmento = document.createDocumentFragment();

  filtrados.forEach((usuario) => {
    fragmento.appendChild(crearTarjetaIntegrante(usuario));
  });

  lista.replaceChildren(fragmento);
  botonLimpiar.disabled =
    integrantes.length === 0 || !hayFiltrosActivos();

  if (integrantes.length === 0) {
    estado.textContent = 'No hay integrantes disponibles.';
    return;
  }

  if (filtrados.length === 0) {
    estado.textContent =
      'No hay integrantes que coincidan. Prueba otros filtros o pulsa “Limpiar búsqueda y filtros”.';
    return;
  }

  if (hayFiltrosActivos()) {
    estado.textContent =
      `Mostrando ${filtrados.length} de ${integrantes.length} integrantes`;
    return;
  }

  estado.textContent = integrantes.length === 1
    ? '1 integrante'
    : `${integrantes.length} integrantes`;
}

function limpiarFiltros() {
  buscador.value = '';
  filtroUnidad.value = '';
  filtroRol.value = '';
  filtroClase.value = '';

  renderizarDirectorio();
  buscador.focus({ preventScroll: true });
}

export function mostrarCargaUsuarios() {
  integrantes = [];
  usuarioSeleccionado = '';
  posicionDirectorio = 0;
  ultimoBoton = null;

  directorio.hidden = false;
  tarjeta.hidden = true;
  navegacionPerfil.hidden = true;

  buscador.value = '';

  filtroUnidad.replaceChildren(new Option('Todas las unidades', ''));
  filtroRol.replaceChildren(new Option('Todos los tipos', ''));
  filtroClase.replaceChildren(new Option('Todas las clases', ''));

  deshabilitarControles(true);

  lista.replaceChildren();
  lista.setAttribute('aria-busy', 'true');

  mensaje.textContent = '';
  mensaje.hidden = true;
  estado.textContent = 'Cargando integrantes…';
  subtitulo.textContent = 'Conoce a los integrantes del club';
}

export function mostrarUsuarios(usuarios) {
  integrantes = [...usuarios];

  mensaje.hidden = true;
  lista.setAttribute('aria-busy', 'false');

  actualizarOpcionesFiltros();
  deshabilitarControles(integrantes.length === 0);
  renderizarDirectorio();
}

export function mostrarErrorUsuarios(texto) {
  integrantes = [];
  usuarioSeleccionado = '';

  directorio.hidden = false;
  tarjeta.hidden = true;
  navegacionPerfil.hidden = true;

  deshabilitarControles(true);

  lista.replaceChildren();
  lista.setAttribute('aria-busy', 'false');

  estado.textContent = '';
  mensaje.textContent = texto;
  mensaje.hidden = false;
}

export function mostrarPerfil(usuario) {
  if (!directorio.hidden) {
    posicionDirectorio = window.scrollY;
  }

  usuarioSeleccionado = usuario.id_usuario;

  nombre.textContent = `${usuario.nombres} ${usuario.apellido}`;
  rol.textContent = nombreRol(usuario.rol);
  unidad.textContent = usuario.unidad || 'Sin asignar';
  clase.textContent = usuario.clase || 'Sin asignar';

  directorio.hidden = true;
  navegacionPerfil.hidden = false;
  tarjeta.hidden = false;
  subtitulo.textContent = 'Perfil del integrante';

  programarNavegacion(() => {
    window.scrollTo({ top: 0, left: 0, behavior: 'instant' });
    nombre.focus({ preventScroll: true });
  });
}

export function mostrarDirectorio() {
  usuarioSeleccionado = '';

  tarjeta.hidden = true;
  navegacionPerfil.hidden = true;
  directorio.hidden = false;
  subtitulo.textContent = 'Conoce a los integrantes del club';

  // Conserva la búsqueda, los filtros y los resultados existentes.
  programarNavegacion(() => {
    const destino = ultimoBoton?.isConnected
      ? ultimoBoton
      : tituloDirectorio;

    destino.focus({ preventScroll: true });

    window.scrollTo({
      top: posicionDirectorio,
      left: 0,
      behavior: 'instant',
    });
  });
}

export function obtenerUsuarioSeleccionado() {
  return usuarioSeleccionado;
}

export function alElegirUsuario(callback) {
  callbackSeleccion = callback;
}

export function alVolverDirectorio(callback) {
  callbackVolver = callback;
}

buscador.addEventListener('input', renderizarDirectorio);

[filtroUnidad, filtroRol, filtroClase].forEach((select) => {
  select.addEventListener('change', renderizarDirectorio);
});

botonLimpiar.addEventListener('click', limpiarFiltros);

lista.addEventListener('click', (evento) => {
  const boton = evento.target.closest('button[data-usuario-id]');

  if (!boton || !lista.contains(boton)) return;

  ultimoBoton = boton;
  callbackSeleccion?.(boton.dataset.usuarioId);
});

botonVolver.addEventListener('click', () => {
  callbackVolver?.();
});