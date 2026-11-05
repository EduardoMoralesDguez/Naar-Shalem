import {rutaFoto} from '../lib/foto-estatica.js';
// frontend/js/modules/integrantes-admin.js

import {
  obtenerOpcionesIntegrante,
  obtenerIntegranteEditable,
  guardarIntegrante,
} from '../services/integrantes-admin.js';

import {
  nuevoId,
  firmarFotos,
} from '../services/fotos.js';

import { mostrarFoto } from './usuarios.js';

const $ = id => document.getElementById(id);
const form = $('adminFormulario');
const campo = nombre => form.elements.namedItem(nombre);

let registro = null;
let revision = 0;
let sucio = false;
let guardando = false;
let alGuardar = null;

function mostrarError(error) {
  console.error(error);
  $('adminError').textContent =
    error.message || 'No se pudo completar la operación.';
  $('adminError').hidden = false;
}

export function puedeSalir() {
  return !guardando && (
    !sucio ||
    confirm('Tienes cambios sin guardar. ¿Quieres descartarlos?')
  );
}

export function reiniciarEditor() {
  revision += 1;
  registro = null;
  sucio = false;
  guardando = false;

  form.reset();
  $('fotoPreview').textContent = 'NS';
  $('adminError').hidden = true;
}

export async function abrirEditor(id, callback) {
  reiniciarEditor();

  const actual = revision;
  alGuardar = callback;

  $('adminTitulo').textContent = id
    ? 'Editar integrante'
    : 'Registrar integrante';

  $('adminEstado').textContent = 'Cargando formulario…';
  $('adminCampos').disabled = true;
  $('adminGuardar').disabled = true;
  $('cancelarEdicion').href = id ? `#perfil/${id}` : '#integrantes';

  try {
    const [opciones, usuario] = await Promise.all([
      obtenerOpcionesIntegrante(),
      id ? obtenerIntegranteEditable(id) : null,
    ]);

    if (actual !== revision) return;

    if (usuario && !usuario.es_activo) {
      throw new Error(
        'Reactiva al integrante antes de editar su perfil.'
      );
    }

    if (!usuario && opciones.ciclos.length !== 1) {
      throw new Error('Debe existir exactamente un ciclo activo.');
    }

    registro = usuario || {
      id_usuario: nuevoId(),
      version_perfil: null,
      nombres: '',
      apellido: '',
      rol: 'conquistador',
      id_unidad: null,
      id_clase: null,
      url_foto: null,
      foto_path: null,
    };

    $('fotoRuta').value = registro.url_foto?.startsWith('img/perfiles/') ? registro.url_foto : '';
    $('fotoRuta').placeholder = `img/perfiles/${registro.id_usuario}.webp`;

    ['nombres', 'apellido', 'rol'].forEach(nombre => {
      campo(nombre).value = registro[nombre];
    });

    campo('rol').disabled = registro.rol === 'directiva';

    for (const [clave, lista] of [
      ['id_unidad', opciones.unidades],
      ['id_clase', opciones.clases],
    ]) {
      campo(clave).replaceChildren(new Option('Sin asignar', ''));

      lista.forEach(valor => {
        campo(clave).add(new Option(valor.nombre, valor[clave]));
      });

      campo(clave).value = registro[clave] || '';
    }

    const [foto] = await firmarFotos([registro]);

    if (actual !== revision) return;

    mostrarFoto($('fotoPreview'), foto);

    $('adminEstado').textContent = '';

    $('adminCampos').disabled = false;
    $('adminGuardar').disabled = false;
    campo('nombres').focus();
  } catch (error) {
    if (actual === revision) {
      $('adminEstado').textContent = '';
      mostrarError(error);
    }
  }
}

form.addEventListener('input', () => {
  sucio = true;
});

$('fotoRuta').addEventListener('change', () => {
  if (!registro) return;
  try {
    const ruta = rutaFoto($('fotoRuta').value);
    registro.url_foto = ruta;
    registro.foto_path = null;
    $('adminError').hidden = true;
    mostrarFoto($('fotoPreview'), registro);
  } catch (error) { mostrarError(error); }
});

$('quitarFoto').addEventListener('click', () => {
  if (!registro) return;

  registro.foto_path = null;
  registro.url_foto = null;
  $('fotoRuta').value = '';
  sucio = true;

  mostrarFoto($('fotoPreview'), registro);
});

form.addEventListener('submit', async evento => {
  evento.preventDefault();

  if (
    !registro ||
    guardando ||
    !form.reportValidity()
  ) {
    return;
  }

  const actual = revision;
  guardando = true;

  $('adminCampos').disabled = true;
  $('adminGuardar').disabled = true;
  $('adminGuardar').textContent = 'Guardando…';
  $('adminError').hidden = true;

  try {
    if ($('fotoRuta').value.trim()) { registro.url_foto = rutaFoto($('fotoRuta').value); registro.foto_path = null; }
    const datos = {
      ...registro,
      nombres: campo('nombres').value.trim(),
      apellido: campo('apellido').value.trim(),
      rol: campo('rol').value,
      id_unidad: campo('id_unidad').value || null,
      id_clase: campo('id_clase').value || null,
      foto_path: registro.foto_path,
      url_foto: registro.url_foto,
    };

    const id = await guardarIntegrante(datos);

    if (actual !== revision) return;

    sucio = false;
    guardando = false;
    registro = null;

    $('adminEstado').textContent = 'Perfil guardado.';

    try {
      await alGuardar(id);
    } catch {
      mostrarError(new Error(
        'El perfil se guardó. Recarga la página para actualizar el directorio.'
      ));
    }
  } catch (error) {
    if (actual === revision) mostrarError(error);
  } finally {
    if (actual === revision) {
      guardando = false;
      $('adminCampos').disabled = !registro;
      $('adminGuardar').disabled = !registro;
      $('adminGuardar').textContent = 'Guardar integrante';
    }
  }
});

window.addEventListener('beforeunload', evento => {
  if (sucio || guardando) {
    evento.preventDefault();
    evento.returnValue = '';
  }
});