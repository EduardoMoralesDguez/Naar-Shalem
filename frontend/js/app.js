// frontend/js/app.js
import { obtenerSupabase } from './lib/supabase.js';
import { obtenerUsuarios } from './services/catalogo.js';

import {
  iniciarSesion,
  cerrarSesion,
  obtenerMiPerfil,
} from './services/auth.js';

import {
  mostrarCargaUsuarios,
  mostrarUsuarios,
  mostrarPerfil,
  mostrarDirectorio,
  obtenerUsuarioSeleccionado,
  alElegirUsuario,
  alVolverDirectorio,
} from './modules/usuarios.js';

import {
  reiniciarProgreso,
  cargarProgreso,
} from './modules/progreso.js';

import {
  reiniciarEspecialidades,
  cargarEspecialidades,
} from './modules/especialidades.js';

const aplicacion = document.getElementById('aplicacion');
const panelLogin = document.getElementById('panelLogin');
const formLogin = document.getElementById('formLogin');
const correo = document.getElementById('loginCorreo');
const password = document.getElementById('loginPassword');
const botonLogin = document.getElementById('botonLogin');
const errorLogin = document.getElementById('errorLogin');

const barraSesion = document.getElementById('barraSesion');
const sesionNombre = document.getElementById('sesionNombre');
const sesionRol = document.getElementById('sesionRol');
const botonSalir = document.getElementById('botonSalir');

const panelEstado = document.getElementById('panelEstadoAcceso');
const estadoAcceso = document.getElementById('estadoAcceso');
const botonReintentar = document.getElementById('reintentarAcceso');
const subtitulo = document.getElementById('subtituloPagina');

let usuarios = [];
let perfilActual = null;
let seleccionVersion = 0;
let accesoVersion = 0;
let tokenProcesado;
let sesionActual = null;
let temporizadorAuth = null;
let cerrando = false;

function limpiarDatos() {
  seleccionVersion += 1;
  usuarios = [];
  perfilActual = null;
  aplicacion.hidden = true;

  mostrarCargaUsuarios();
  mostrarUsuarios([]);
  reiniciarProgreso();
  reiniciarEspecialidades();

  for (const id of [
    'tarjetaNombre',
    'tarjetaRol',
    'tarjetaUnidad',
    'tarjetaClase',
    'asistenciaPorcentaje',
    'asistenciaDetalle',
    'cuotasPorcentaje',
    'cuotasDetalle',
    'totalPagado',
  ]) {
    document.getElementById(id).textContent = '';
  }

  document.getElementById('asistenciaBarra').style.width = '0%';
  document.getElementById('cuotasBarra').style.width = '0%';

  subtitulo.textContent = 'Acceso al club';
}

function mostrarLogin(texto = '') {
  aplicacion.hidden = true;
  panelEstado.hidden = true;
  barraSesion.hidden = true;
  panelLogin.hidden = false;

  sesionNombre.textContent = '';
  sesionRol.textContent = '';
  password.value = '';

  errorLogin.textContent = texto;
  errorLogin.hidden = !texto;
}

function mostrarEstado(texto, reintentar = false) {
  panelLogin.hidden = true;
  aplicacion.hidden = true;
  panelEstado.hidden = false;

  estadoAcceso.textContent = texto;
  botonReintentar.hidden = !reintentar;

  barraSesion.hidden = !sesionActual;
  sesionNombre.textContent = sesionActual?.user?.email || '';
  sesionRol.textContent = '';
}

function seleccionarUsuario(idUsuario) {
  if (!perfilActual || cerrando) return;

  if (
    perfilActual.rol !== 'directiva' &&
    idUsuario !== perfilActual.id_usuario
  ) {
    return;
  }

  const usuario = usuarios.find(
    (integrante) => integrante.id_usuario === idUsuario
  );

  if (!usuario) return;

  const version = ++seleccionVersion;

  reiniciarProgreso();
  reiniciarEspecialidades();
  mostrarPerfil(usuario);

  document.getElementById('navegacionPerfil').hidden =
    perfilActual.rol !== 'directiva';

  if (perfilActual.rol !== 'directiva') {
    subtitulo.textContent = 'Mi perfil';
  }

  const sigueVigente = () =>
    version === seleccionVersion &&
    Boolean(perfilActual) &&
    obtenerUsuarioSeleccionado() === idUsuario;

  void cargarProgreso(idUsuario, sigueVigente);
  void cargarEspecialidades(idUsuario, sigueVigente);
}

async function aplicarSesion(sesion, forzar = false) {
  if (cerrando && sesion) return;

  const token = sesion?.access_token || null;

  if (!forzar && tokenProcesado === token) return;

  tokenProcesado = token;
  sesionActual = sesion;

  const version = ++accesoVersion;

  limpiarDatos();

  if (!sesion) {
    mostrarLogin();
    return;
  }

  mostrarEstado('Comprobando acceso…');

  try {
    // El rol procede de la base de datos.
    // No se utiliza user_metadata para conceder permisos.
    const perfil = await obtenerMiPerfil();

    if (version !== accesoVersion) return;

    const integrantes = perfil.rol === 'directiva'
      ? await obtenerUsuarios()
      : [perfil];

    if (version !== accesoVersion) return;

    perfilActual = perfil;
    usuarios = integrantes;

    mostrarUsuarios(usuarios);

    panelEstado.hidden = true;
    panelLogin.hidden = true;
    barraSesion.hidden = false;

    sesionNombre.textContent =
      `${perfil.nombres} ${perfil.apellido}`;

    sesionRol.textContent = perfil.rol === 'directiva'
      ? 'Directiva'
      : 'Cuenta personal';

    aplicacion.hidden = false;

    if (perfil.rol === 'directiva') {
      subtitulo.textContent = 'Conoce a los integrantes del club';
    } else {
      seleccionarUsuario(perfil.id_usuario);
    }
  } catch (error) {
    if (version !== accesoVersion) return;

    console.error('Error al comprobar acceso:', error);

    limpiarDatos();

    mostrarEstado(
      error.code === 'SIN_EXPEDIENTE'
        ? error.message
        : 'No se pudo comprobar tu acceso. Revisa la conexión y vuelve a intentarlo.',
      true
    );
  }
}

formLogin.addEventListener('submit', async (evento) => {
  evento.preventDefault();

  botonLogin.disabled = true;
  botonLogin.textContent = 'Entrando…';
  errorLogin.hidden = true;

  try {
    await iniciarSesion(correo.value.trim(), password.value);

    // onAuthStateChange abre la pantalla correspondiente.
  } catch (error) {
    console.error('Error al iniciar sesión:', error);

    errorLogin.textContent = error.code === 'invalid_credentials'
      ? 'Correo o contraseña incorrectos.'
      : error.code === 'email_not_confirmed'
        ? 'Tu correo todavía no está confirmado. Contacta a la directiva.'
        : 'No se pudo iniciar sesión. Revisa tus datos y la conexión.';

    errorLogin.hidden = false;
  } finally {
    password.value = '';
    botonLogin.disabled = false;
    botonLogin.textContent = 'Entrar';
  }
});

botonSalir.addEventListener('click', async () => {
  if (cerrando) return;

  cerrando = true;
  accesoVersion += 1;

  clearTimeout(temporizadorAuth);
  limpiarDatos();
  mostrarEstado('Cerrando sesión…');

  botonSalir.disabled = true;

  try {
    await cerrarSesion();
    await aplicarSesion(null, true);
  } catch (error) {
    console.error('Error al cerrar sesión:', error);

    mostrarEstado(
      'No se pudo cerrar la sesión. Revisa la conexión y pulsa Cerrar sesión nuevamente.'
    );
  } finally {
    cerrando = false;
    botonSalir.disabled = false;
  }
});

botonReintentar.addEventListener('click', async () => {
  botonReintentar.disabled = true;

  try {
    const { data, error } = await obtenerSupabase().auth.getSession();

    if (error) throw error;

    await aplicarSesion(data.session, true);
  } catch (error) {
    console.error('Error al recuperar sesión:', error);

    mostrarEstado(
      'No se pudo recuperar tu sesión. Revisa la conexión.',
      true
    );
  } finally {
    botonReintentar.disabled = false;
  }
});

alElegirUsuario(seleccionarUsuario);

alVolverDirectorio(() => {
  if (perfilActual?.rol !== 'directiva') return;

  seleccionVersion += 1;

  reiniciarProgreso();
  reiniciarEspecialidades();
  mostrarDirectorio();
});

try {
  const supabase = obtenerSupabase();

  // INITIAL_SESSION restaura una sesión guardada.
  // También se reciben cierres desde otras pestañas y renovaciones.
  supabase.auth.onAuthStateChange((_evento, sesion) => {
    clearTimeout(temporizadorAuth);

    // Ejecutar consultas fuera del callback evita bloqueos de Auth.
    temporizadorAuth = setTimeout(() => {
      void aplicarSesion(sesion);
    }, 0);
  });
} catch (error) {
  limpiarDatos();
  mostrarLogin(error.message);
}