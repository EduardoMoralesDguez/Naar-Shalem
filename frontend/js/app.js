const API_URL = 'http://localhost:3000/api/usuarios';
const API_PROGRESO = 'http://localhost:3000/api/progreso';
const META_CUOTAS = 70; // % de cumplimiento financiero esperado

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

let usuarios = [];

// Pone la primera letra en mayúscula (capitan -> Capitan)
function capitalizar(texto) {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function mostrarError(texto) {
  mensaje.textContent = texto;
  mensaje.hidden = false;
}

async function cargarUsuarios() {
  try {
    const respuesta = await fetch(API_URL);
    if (!respuesta.ok) {
      throw new Error(`Error HTTP ${respuesta.status}`);
    }
    usuarios = await respuesta.json();
    llenarSelector();
  } catch (error) {
    console.error(error);
    selector.innerHTML = '<option value="">No disponible</option>';
    mostrarError('No se pudo conectar con el servidor. ¿Está corriendo el backend en el puerto 3000?');
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

async function cargarProgreso(idUsuario) {
  try {
    const respuesta = await fetch(`${API_PROGRESO}/${idUsuario}`);
    if (!respuesta.ok) {
      throw new Error(`Error HTTP ${respuesta.status}`);
    }
    const progreso = await respuesta.json();

    // Si el usuario cambió de selección mientras cargaba, se descarta
    if (selector.value !== idUsuario) return;

    pintarProgreso(progreso);
    dashboardError.hidden = true;
    dashboardMetricas.hidden = false;
    dashboard.hidden = false;
  } catch (error) {
    console.error(error);
    if (selector.value !== idUsuario) return;

    dashboardError.textContent = 'No se pudo cargar el progreso de este usuario.';
    dashboardError.hidden = false;
    dashboardMetricas.hidden = true;
    dashboard.hidden = false;
  }
}

function mostrarTarjeta(idUsuario) {
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

  // Fase 2: el dashboard se oculta y se vuelve a pintar con datos nuevos
  dashboard.hidden = true;
  cargarProgreso(idUsuario);
}

selector.addEventListener('change', (evento) => {
  mostrarTarjeta(evento.target.value);
});

cargarUsuarios();
