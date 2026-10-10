// frontend/js/app.js

import { obtenerSupabase } from './lib/supabase.js';
import { obtenerUsuarios } from './services/catalogo.js';

import {
  mostrarCargaUsuarios,
  mostrarUsuarios,
  mostrarErrorUsuarios,
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

let usuarios = [];
let seleccionVersion = 0;

function seleccionarUsuario(idUsuario) {
  const usuario = usuarios.find(
    (miembro) => miembro.id_usuario === idUsuario
  );

  if (!usuario) return;

  const versionActual = ++seleccionVersion;

  reiniciarProgreso();
  reiniciarEspecialidades();
  mostrarPerfil(usuario);

  // Una respuesta anterior no puede modificar otro perfil,
  // ni reaparecer después de volver al directorio.
  const sigueVigente = () =>
    versionActual === seleccionVersion &&
    obtenerUsuarioSeleccionado() === idUsuario;

  void cargarProgreso(idUsuario, sigueVigente);
  void cargarEspecialidades(idUsuario, sigueVigente);
}

function volverAlDirectorio() {
  seleccionVersion += 1;

  reiniciarProgreso();
  reiniciarEspecialidades();
  mostrarDirectorio();
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
      'No se pudieron cargar los integrantes. Revisa la conexión y recarga la página.'
    );
  }
}

alElegirUsuario(seleccionarUsuario);
alVolverDirectorio(volverAlDirectorio);

void iniciarAplicacion();