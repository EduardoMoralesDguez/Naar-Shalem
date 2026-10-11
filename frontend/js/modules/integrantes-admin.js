// frontend/js/modules/integrantes-admin.js

import {
  obtenerOpcionesIntegrante,
  obtenerIntegranteEditable,
  guardarIntegrante,
} from '../services/integrantes-admin.js';

import {
  nuevoId,
  firmarFotos,
  prepararFoto,
  subirFoto,
  limpiarFoto,
} from '../services/fotos.js';

import { mostrarFoto } from './usuarios.js';

const $ = id => document.getElementById(id);
const form = $('adminFormulario');
const campo = nombre => form.elements.namedItem(nombre);

let registro = null;
let revision = 0;
let sucio = false;
let guardando = false;
let preparando = false;
let blob = null;
let preview = null;
let pendiente = null;
let alGuardar = null;
let fotoOriginal = null;

function mostrarError(error) {
  console.error(error);
  $('adminError').textContent =
    error.message || 'No se pudo completar la operación.';
  $('adminError').hidden = false;
}

function soltarPreview() {
  if (preview) URL.revokeObjectURL(preview);
  preview = null;
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
  preparando = false;
  blob = null;

  if (pendiente) void limpiarFoto(pendiente);

  pendiente = null;
  soltarPreview();

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

    fotoOriginal = registro.foto_path;

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

    $('adminEstado').textContent = usuario
      ? 'Actualiza su información conservando el historial.'
      : `Nuevo integrante · Ciclo ${opciones.ciclos[0].anio}`;

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

$('fotoArchivo').addEventListener('change', async () => {
  const archivo = $('fotoArchivo').files[0];

  if (!archivo || !registro) return;

  const actual = revision;
  preparando = true;

  $('adminGuardar').disabled = true;
  $('adminCampos').disabled = true;

  try {
    const preparado = await prepararFoto(archivo);

    if (actual !== revision) return;

    if (pendiente) void limpiarFoto(pendiente);

    pendiente = null;
    blob = preparado;
    soltarPreview();
    preview = URL.createObjectURL(blob);

    mostrarFoto($('fotoPreview'), {
      ...registro,
      url_foto: preview,
    });

    sucio = true;
  } catch (error) {
    if (actual === revision) mostrarError(error);
  } finally {
    if (actual === revision) {
      preparando = false;
      $('adminGuardar').disabled = false;
      $('adminCampos').disabled = false;
    }
  }
});

$('quitarFoto').addEventListener('click', () => {
  if (!registro) return;

  if (pendiente) void limpiarFoto(pendiente);

  pendiente = null;
  blob = null;
  soltarPreview();

  registro.foto_path = null;
  registro.url_foto = null;
  $('fotoArchivo').value = '';
  sucio = true;

  mostrarFoto($('fotoPreview'), registro);
});

form.addEventListener('submit', async evento => {
  evento.preventDefault();

  if (
    !registro ||
    guardando ||
    preparando ||
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
    if (blob && !pendiente) {
      const path = await subirFoto(registro.id_usuario, blob);

      if (actual !== revision) {
        void limpiarFoto(path);
        return;
      }

      pendiente = path;
    }

    const datos = {
      ...registro,
      nombres: campo('nombres').value.trim(),
      apellido: campo('apellido').value.trim(),
      rol: campo('rol').value,
      id_unidad: campo('id_unidad').value || null,
      id_clase: campo('id_clase').value || null,
      foto_path: pendiente || registro.foto_path,
      url_foto: pendiente ? null : registro.url_foto,
    };

    const id = await guardarIntegrante(datos);

    if (actual !== revision) return;

    if (fotoOriginal && fotoOriginal !== datos.foto_path) {
      void limpiarFoto(fotoOriginal);
    }

    pendiente = null;
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