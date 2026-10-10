// frontend/js/app.js

import { obtenerSupabase } from './lib/supabase.js';
import { obtenerUsuarios } from './services/catalogo.js';

import {
  mostrarCargaUsuarios,
  mostrarUsuarios,
  mostrarErrorUsuarios,
  mostrarPerfil,
  ocultarPerfil,
  obtenerUsuarioSeleccionado,
  alCambiarUsuario,
} from './modules/usuarios.js';

import {
  reiniciarProgreso,
  cargarProgreso,
} from './modules/progreso.js';

import {
  reiniciarEspecialidades,
  cargarEspecialidades,
} from './modules/especialidades.js';

// El archivo principal coordina el inicio y la selección.
// Las consultas y la representación visual viven en sus módulos.

let usuarios = [];
let seleccionVersion = 0;

function seleccionarUsuario(idUsuario) {
  const versionActual = ++seleccionVersion;

  reiniciarProgreso();
  reiniciarEspecialidades();

  const usuario = usuarios.find(
    (miembro) => miembro.id_usuario === idUsuario
  );

  if (!usuario) {
    ocultarPerfil();
    return;
  }

  mostrarPerfil(usuario);

  // Evita que respuestas antiguas sobrescriban el perfil actual,
  // incluso si se selecciona A, después B y después A nuevamente.
  const sigueVigente = () =>
    versionActual === seleccionVersion &&
    obtenerUsuarioSeleccionado() === idUsuario;

  // Ambas secciones cargan de forma independiente y manejan
  // sus errores dentro de sus respectivos módulos.
  void cargarProgreso(idUsuario, sigueVigente);
  void cargarEspecialidades(idUsuario, sigueVigente);
}

async function iniciarAplicacion() {
  mostrarCargaUsuarios();

  try {
    obtenerSupabase();
  } catch (error) {
    console.error('Error de configuración de Supabase:', error);
    mostrarErrorUsuarios(error.message);
    return;
  }

  try {
    usuarios = await obtenerUsuarios();
    mostrarUsuarios(usuarios);
  } catch (error) {
    console.error('Error al cargar usuarios desde Supabase:', error);

    mostrarErrorUsuarios(
      'No se pudieron cargar los usuarios. Revisa la conexión e inténtalo de nuevo.'
    );
  }
}

alCambiarUsuario(seleccionarUsuario);
void iniciarAplicacion();