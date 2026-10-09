// app.js
const API_URL = 'http://localhost:3000/api/usuarios';
const API_PROGRESO = 'http://localhost:3000/api/progreso';
const API_ESPECIALIDADES = 'http://localhost:3000/api/especialidades';
const META_CUOTAS = 70;

const formatoMoneda = new Intl.NumberFormat('es-MX', {
  style: 'currency',
  currency: 'MXN',
  maximumFractionDigits: 0,
});

const selector = document.getElementById('selectorUsuario');
const mensaje = document.getElementById('mensaje');
const tarjeta = document.getElementById('tarjeta');
const tarjetaNombre = document.getElementById('tarjetaNombre');
const tarjetaRol = document.getElementById('tarjetaRol');
const tarjetaUnidad = document.getElementById('tarjetaUnidad');
const tarjetaClase = document.getElementById('tarjetaClase');

const dashboard = document.getElementById('dashboard');
const dashboardError = document.getElementById('dashboardError');
const dashboardMetricas = document.getElementById('dashboardMetricas');
const asistenciaPorcentaje = document.getElementById('asistenciaPorcentaje');
const asistenciaBarra = document.getElementById('asistenciaBarra');
const asistenciaDetalle = document.getElementById('asistenciaDetalle');
const cuotasPorcentaje = document.getElementById('cuotasPorcentaje');
const cuotasBarra = document.getElementById('cuotasBarra');
const cuotasDetalle = document.getElementById('cuotasDetalle');
const totalPagado = document.getElementById('totalPagado');

const especialidadesSeccion = document.getElementById('especialidades');
const especialidadesEstado = document.getElementById('especialidadesEstado');
const especialidadesLista = document.getElementById('especialidadesLista');

let usuarios = [];
let seleccionVersion = 0;

function capitalizar(texto) {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function mostrarError(texto) {
  mensaje.textContent = texto;
  mensaje.hidden = false;
}

function seleccionVigente(idUsuario, version) {
  return version === seleccionVersion && selector.value === idUsuario;
}

async function cargarUsuarios() {
  try {
    const respuesta = await fetch(API_URL);

    if (!respuesta.ok) {
      throw new Error(`Error HTTP ${respuesta.status}`);
    }

    usuarios = await respuesta.json();
    llenarSelector();
    mensaje.hidden = true;
  } catch (error) {
    console.error(error);
    selector.innerHTML = '<option value="">No disponible</option>';
    mostrarError(
      'No se pudo conectar con el servidor. ¿Está corriendo el backend en el puerto 3000?'
    );
  }
}

function llenarSelector() {
  selector.innerHTML = '<option value="">-- Elige un usuario --</option>';

  usuarios.forEach((usuario) => {
    const opcion = document.createElement('option');
    opcion.value = usuario.id_usuario;
    opcion.textContent = `${usuario.nombres} ${usuario.apellido}`;
    selector.appendChild(opcion);
  });
}

function pintarProgreso({ asistencia, cuotas }) {
  asistenciaPorcentaje.textContent = `${asistencia.porcentaje}%`;
  asistenciaBarra.style.width = `${asistencia.porcentaje}%`;
  asistenciaDetalle.textContent =
    `${asistencia.asistencias} asistencias + ${asistencia.justificados} justificadas ` +
    `de ${asistencia.total_registros} reuniones`;

  cuotasPorcentaje.textContent = `${cuotas.porcentaje}%`;
  cuotasBarra.style.width = `${cuotas.porcentaje}%`;
  cuotasBarra.classList.toggle('bajo-meta', cuotas.porcentaje < META_CUOTAS);
  cuotasDetalle.textContent =
    `${cuotas.semanas_pagadas} de ${cuotas.semanas_registradas} semanas pagadas ` +
    `(meta: ${META_CUOTAS}%)`;

  totalPagado.textContent = formatoMoneda.format(cuotas.total_pagado);
}

async function cargarProgreso(idUsuario, version) {
  try {
    const respuesta = await fetch(`${API_PROGRESO}/${idUsuario}`);

    if (!respuesta.ok) {
      throw new Error(`Error HTTP ${respuesta.status}`);
    }

    const progreso = await respuesta.json();

    if (!seleccionVigente(idUsuario, version)) return;

    pintarProgreso(progreso);
    dashboardError.hidden = true;
    dashboardMetricas.hidden = false;
    dashboard.hidden = false;
  } catch (error) {
    console.error(error);

    if (!seleccionVigente(idUsuario, version)) return;

    dashboardError.textContent = 'No se pudo cargar el progreso de este usuario.';
    dashboardError.hidden = false;
    dashboardMetricas.hidden = true;
    dashboard.hidden = false;
  }
}

function resolverImagen(ruta) {
  if (typeof ruta !== 'string' || !ruta.trim()) return null;

  try {
    const url = new URL(ruta, document.baseURI);

    if (!['http:', 'https:', 'file:'].includes(url.protocol)) {
      return null;
    }

    return url.href;
  } catch {
    return null;
  }
}

function pintarEspecialidades(lista) {
  especialidadesLista.replaceChildren();
  const fragmento = document.createDocumentFragment();

  lista.forEach((especialidad) => {
    const item = document.createElement('li');
    item.className = 'banda-item';

    const nombre = document.createElement('span');
    nombre.className = 'banda-nombre';
    nombre.textContent = especialidad.nombre;

    const fallback = document.createElement('span');
    fallback.className = 'banda-fallback';
    fallback.textContent = 'Imagen no disponible';
    fallback.hidden = true;

    const ruta = resolverImagen(especialidad.url_imagen);

    if (ruta) {
      const imagen = document.createElement('img');
      imagen.className = 'banda-insignia';
      imagen.alt = `Insignia de ${especialidad.nombre}`;
      imagen.width = 80;
      imagen.height = 80;
      imagen.decoding = 'async';

      imagen.addEventListener('error', () => {
        imagen.hidden = true;
        fallback.hidden = false;
      }, { once: true });

      imagen.src = ruta;
      item.appendChild(imagen);
    } else {
      fallback.hidden = false;
    }

    item.append(fallback, nombre);
    fragmento.appendChild(item);
  });

  especialidadesLista.appendChild(fragmento);
}

async function cargarEspecialidades(idUsuario, version) {
  try {
    const respuesta = await fetch(`${API_ESPECIALIDADES}/${idUsuario}`);

    if (!respuesta.ok) {
      throw new Error(`Error HTTP ${respuesta.status}`);
    }

    const lista = await respuesta.json();

    if (!Array.isArray(lista)) {
      throw new Error('Respuesta de especialidades inválida');
    }

    if (!seleccionVigente(idUsuario, version)) return;

    pintarEspecialidades(lista);
    especialidadesEstado.textContent = lista.length
      ? ''
      : 'Aún no hay especialidades obtenidas';
    especialidadesEstado.hidden = lista.length > 0;
  } catch (error) {
    console.error(error);

    if (!seleccionVigente(idUsuario, version)) return;

    especialidadesLista.replaceChildren();
    especialidadesEstado.textContent =
      'No se pudieron cargar las especialidades. Vuelve a seleccionar al usuario para reintentar.';
    especialidadesEstado.hidden = false;
  }
}

function mostrarTarjeta(idUsuario) {
  // Evita que una respuesta anterior pinte la banda de otro usuario.
  const version = ++seleccionVersion;

  especialidadesLista.replaceChildren();
  especialidadesSeccion.hidden = true;
  dashboard.hidden = true;

  const usuario = usuarios.find((u) => u.id_usuario === idUsuario);

  if (!usuario) {
    tarjeta.hidden = true;
    return;
  }

  tarjetaNombre.textContent = `${usuario.nombres} ${usuario.apellido}`;
  tarjetaRol.textContent = capitalizar(usuario.rol);
  tarjetaUnidad.textContent = usuario.unidad || 'Sin asignar';
  tarjetaClase.textContent = usuario.clase || 'Sin asignar';
  tarjeta.hidden = false;

  especialidadesSeccion.hidden = false;
  especialidadesEstado.textContent = 'Cargando especialidades…';
  especialidadesEstado.hidden = false;

  cargarProgreso(idUsuario, version);
  cargarEspecialidades(idUsuario, version);
}

selector.addEventListener('change', (evento) => {
  mostrarTarjeta(evento.target.value);
});

cargarUsuarios();