import {colorearNombre} from '../lib/colores.js';
// frontend/js/modules/usuarios.js

const $ = id => document.getElementById(id);

const roles = {
  directiva: 'Directiva',
  consejero: 'Consejero',
  capitan: 'Capitán',
  subcapitan: 'Subcapitán',
  conquistador: 'Conquistador',
};

const filtros = ['filtroUnidad', 'filtroRol', 'filtroClase'];

const normalizar = texto => String(texto || '')
  .normalize('NFD')
  .replace(/[\u0300-\u036f]/g, '')
  .toLowerCase()
  .trim();

let filas = [];

export function nombreRol(rol) {
  return roles[rol] || '';
}

export function mostrarFoto(contenedor, usuario) {
  const iniciales = (
    (usuario.nombres?.trim()[0] || '') +
    (usuario.apellido?.trim()[0] || '')
  ).toUpperCase() || 'NS';

  contenedor.textContent = iniciales;

  if (!usuario.url_foto) return;

  let url;

  try {
    url = new URL(usuario.url_foto, document.baseURI);

    if (!['http:', 'https:', 'blob:'].includes(url.protocol)) {
      return;
    }
  } catch {
    return;
  }

  const imagen = document.createElement('img');
  imagen.alt = '';
  imagen.decoding = 'async';
  imagen.referrerPolicy = 'no-referrer';

  imagen.addEventListener('error', () => {
    if (imagen.parentNode === contenedor) {
      contenedor.textContent = iniciales;
    }
  }, { once: true });

  imagen.src = url.href;
  contenedor.replaceChildren(imagen);
}

export function limpiarUsuarios() {
  filas = [];

  $('buscarIntegrante').value = '';

  filtros.forEach(id => {
    $(id).replaceChildren(new Option('Todos', ''));
  });

  $('filtroEstado').value = 'activos';
  $('panelFiltros').open = false;
  $('listaIntegrantes').replaceChildren();
  $('perfilAvatar').replaceChildren();

  [
    'tarjetaNombre',
    'tarjetaRol',
    'tarjetaUnidad',
    'tarjetaClase',
  ].forEach(id => {
    $(id).textContent = '';
  });
}

export function mostrarUsuarios(usuarios, admin) {
  filas = usuarios;

  $('campoFiltroRol').hidden = !admin;
  $('campoFiltroEstado').hidden = !admin;

  if (!admin) {
    $('filtroRol').value = '';
    $('filtroEstado').value = 'activos';
  }

  const configuraciones = [
    ['filtroUnidad', 'unidad', 'Todas las unidades'],
    ['filtroRol', 'rol', 'Todos los tipos'],
    ['filtroClase', 'clase', 'Todas las clases'],
  ];

  for (const [id, clave, etiqueta] of configuraciones) {
    const previo = $(id).value;

    const valores = [...new Set(
      filas.map(usuario => usuario[clave] || '__sin__')
    )].sort((a, b) => a.localeCompare(b, 'es'));

    $(id).replaceChildren(new Option(etiqueta, ''));

    valores.forEach(valor => {
      const texto = valor === '__sin__'
        ? 'Sin asignar'
        : clave === 'rol'
          ? nombreRol(valor)
          : valor;

      $(id).add(new Option(texto, valor));
    });

    $(id).value = valores.includes(previo) ? previo : '';
  }

  renderizar();
}

function renderizar() {
  const termino = normalizar($('buscarIntegrante').value);
  const estado = $('filtroEstado').value;

  const encontrados = filas.filter(usuario =>
    normalizar(
      `${usuario.nombres} ${usuario.apellido} ${usuario.unidad || ''} ${usuario.clase || ''}`
    ).includes(termino) &&
    filtros.every((id, indice) =>
      !$(id).value ||
      $(id).value === (
        usuario[['unidad', 'rol', 'clase'][indice]] || '__sin__'
      )
    ) &&
    (
      estado === 'todos' ||
      (estado === 'activos' ? usuario.es_activo : !usuario.es_activo)
    )
  );

  const fragmento = document.createDocumentFragment();

  for (const usuario of encontrados) {
    const item = document.createElement('li');
    item.className = 'integrante-item';

    const enlace = document.createElement('a');
    enlace.className = 'integrante-boton';
    enlace.style.textDecoration = 'none';
    enlace.href = `#perfil/${usuario.id_usuario}`;

    const foto = document.createElement('span');
    foto.className = 'integrante-avatar';
    foto.setAttribute('aria-hidden', 'true');
    mostrarFoto(foto, usuario);

    const informacion = document.createElement('span');
    informacion.className = 'integrante-info';

    const nombre = document.createElement('strong');
    nombre.className = 'integrante-nombre';colorearNombre(nombre,usuario.id_usuario);
    nombre.textContent = `${usuario.nombres} ${usuario.apellido}`;

    const detalle = document.createElement('span');
    detalle.className = 'integrante-detalles';
    detalle.textContent =
      `${usuario.unidad || 'Sin unidad'} · ${usuario.clase || 'Sin clase'}`;

    detalle.hidden = usuario.es_directiva || usuario.rol === 'directiva';
    informacion.append(nombre, detalle);

    if (usuario.rol || !usuario.es_activo) {
      const etiqueta = document.createElement('span');
      etiqueta.className = 'integrante-rol';
      etiqueta.textContent = !usuario.es_activo
        ? 'Inactivo'
        : nombreRol(usuario.rol);

      informacion.append(etiqueta);
    }

    enlace.append(foto, informacion);
    item.append(enlace);
    fragmento.append(item);
  }

  $('listaIntegrantes').replaceChildren(fragmento);

  $('estadoDirectorio').textContent = encontrados.length
    ? ''
    : 'No hay integrantes que coincidan con tu búsqueda.';

  const cantidad =
    filtros.filter(id => $(id).value).length +
    Number(estado !== 'activos');

  $('cantidadFiltros').textContent = cantidad
    ? `(${cantidad} activos)`
    : '';
}

export function mostrarPerfil(usuario) {
  $('tarjeta').hidden = false;
  $('tarjetaNombre').textContent =
    `${usuario.nombres} ${usuario.apellido}`;

  colorearNombre($('tarjetaNombre'),usuario.id_usuario);
  $('tarjetaRol').textContent = nombreRol(usuario.rol);
  $('tarjetaRol').parentElement.hidden = !usuario.rol;
  $('tarjetaUnidad').textContent = usuario.unidad || 'Sin asignar';
  $('tarjetaClase').textContent = usuario.clase || 'Sin asignar';
  const esDirectiva = usuario.es_directiva || usuario.rol === 'directiva';
  $('tarjetaUnidad').parentElement.hidden = esDirectiva;
  $('tarjetaClase').parentElement.hidden = esDirectiva;
  $('perfilEstado').hidden = usuario.es_activo;

  mostrarFoto($('perfilAvatar'), usuario);
}

$('buscarIntegrante').addEventListener('input', renderizar);

[...filtros, 'filtroEstado'].forEach(id => {
  $(id).addEventListener('change', renderizar);
});

$('limpiarFiltros').addEventListener('click', () => {
  $('buscarIntegrante').value = '';
  filtros.forEach(id => $(id).value = '');
  $('filtroEstado').value = 'activos';
  renderizar();
});