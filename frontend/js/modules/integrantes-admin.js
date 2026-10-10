// frontend/js/modules/integrantes-admin.js

import {
  obtenerOpcionesIntegrante,
  obtenerIntegranteEditable,
  guardarIntegrante,
} from '../services/integrantes-admin.js';

import { obtenerUsuarioSeleccionado } from './usuarios.js';

// El módulo instala su formulario y sus estilos sin modificar index.html.
const estilos = document.createElement('link');
estilos.rel = 'stylesheet';
estilos.href = new URL(
  '../../css/integrantes-admin.css',
  import.meta.url
).href;
document.head.append(estilos);

const acciones = document.createElement('div');
acciones.className = 'admin-acciones';
acciones.hidden = true;

const nuevo = document.createElement('button');
nuevo.type = 'button';
nuevo.className = 'boton-volver admin-principal';
nuevo.textContent = 'Registrar integrante';

acciones.append(nuevo);
document.querySelector('.directorio-cabecera').append(acciones);

const editar = document.createElement('button');
editar.type = 'button';
editar.className = 'boton-volver';
editar.textContent = 'Editar perfil';
editar.hidden = true;

document.getElementById('navegacionPerfil').append(editar);

const aviso = document.createElement('p');
aviso.className = 'admin-aviso';
aviso.setAttribute('role', 'status');
aviso.hidden = true;

document.getElementById('aplicacion').prepend(aviso);

const dialogo = document.createElement('dialog');
dialogo.className = 'admin-dialogo';
dialogo.setAttribute('aria-labelledby', 'adminTitulo');
dialogo.setAttribute('aria-describedby', 'adminDescripcion');

// Marcado fijo: los datos del integrante se asignan con value/textContent.
dialogo.innerHTML = `
  <h2 id="adminTitulo">Registrar integrante</h2>

  <p id="adminDescripcion" class="admin-ayuda">
    Este formulario guarda el perfil.
    La cuenta para iniciar sesión se vincula por separado.
  </p>

  <p id="adminEstado" role="status" class="admin-ayuda"></p>
  <p id="adminError" role="alert" class="mensaje" hidden></p>

  <form id="adminFormulario" hidden>
    <fieldset class="admin-campos" id="adminCampos">
      <label>
        <span class="etiqueta">Nombre(s)</span>
        <input
          name="nombres"
          maxlength="100"
          autocomplete="off"
          required
        >
      </label>

      <label>
        <span class="etiqueta">Apellidos</span>
        <input
          name="apellido"
          maxlength="100"
          autocomplete="off"
          required
        >
      </label>

      <label>
        <span class="etiqueta">Rol</span>
        <select name="rol" required>
          <option value="conquistador">Conquistador</option>
          <option value="consejero">Consejero</option>
          <option value="capitan">Capitán</option>
          <option value="directiva">Directiva</option>
        </select>
      </label>

      <label>
        <span class="etiqueta">Unidad</span>
        <select name="id_unidad"></select>
      </label>

      <label>
        <span class="etiqueta">Clase</span>
        <select name="id_clase"></select>
      </label>

      <label class="admin-ancho">
        <span class="etiqueta">Foto (opcional)</span>
        <input
          name="url_foto"
          maxlength="500"
          autocomplete="off"
          placeholder="https://… o img/integrantes/foto.jpg"
          aria-describedby="adminFotoAyuda"
        >
      </label>

      <p id="adminFotoAyuda" class="admin-ayuda admin-ancho">
        Usa una imagen ya disponible por HTTPS o dentro de img/.
        Si lo dejas vacío, se mostrarán las iniciales.
      </p>
    </fieldset>
  </form>

  <div class="admin-acciones">
    <button
      type="submit"
      form="adminFormulario"
      id="adminGuardar"
      class="boton-volver admin-principal"
      hidden
    >
      Guardar perfil
    </button>

    <button
      type="button"
      id="adminCerrar"
      class="boton-volver"
    >
      Cancelar
    </button>
  </div>
`;

document.body.append(dialogo);

const form = dialogo.querySelector('form');
const campos = dialogo.querySelector('#adminCampos');
const titulo = dialogo.querySelector('#adminTitulo');
const estado = dialogo.querySelector('#adminEstado');
const errorTexto = dialogo.querySelector('#adminError');
const guardar = dialogo.querySelector('#adminGuardar');
const cerrar = dialogo.querySelector('#adminCerrar');

const campo = (nombre) => form.elements.namedItem(nombre);

let autorizado = false;
let alGuardar = null;
let registro = null;
let revision = 0;
let guardando = false;

function crearId() {
  if (globalThis.crypto.randomUUID) {
    return globalThis.crypto.randomUUID();
  }

  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;

  const hex = Array.from(
    bytes,
    (b) => b.toString(16).padStart(2, '0')
  ).join('');

  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
}

function llenarOpciones(nombre, filas, clave, valor) {
  const select = campo(nombre);
  select.replaceChildren(new Option('Sin asignar', ''));

  filas.forEach((fila) => {
    select.add(new Option(fila.nombre, fila[clave]));
  });

  select.value = valor || '';
}

function mostrarError(error) {
  console.error('Administración de integrantes:', error);

  errorTexto.textContent = [
    '22023',
    '23505',
    '40001',
    '42501',
  ].includes(error.code)
    ? error.message
    : 'No se pudo completar la operación. Revisa la conexión y vuelve a intentarlo.';

  errorTexto.hidden = false;
}

export function reiniciarAdministracion() {
  revision += 1;
  autorizado = false;
  alGuardar = null;
  registro = null;
  guardando = false;

  acciones.hidden = true;
  editar.hidden = true;
  aviso.hidden = true;
  aviso.textContent = '';

  if (dialogo.open) {
    dialogo.close();
  }

  form.reset();
  form.hidden = true;
  estado.textContent = '';
  errorTexto.textContent = '';
  errorTexto.hidden = true;
}

export function configurarAdministracion(perfil, callback) {
  reiniciarAdministracion();

  autorizado = perfil?.rol === 'directiva';
  alGuardar = callback;
  acciones.hidden = !autorizado;
  editar.hidden = !autorizado;
}

async function abrir(idUsuario = null) {
  if (!autorizado || dialogo.open) return;

  const actual = ++revision;

  registro = null;
  form.reset();
  form.hidden = true;
  campos.disabled = false;
  guardar.hidden = true;
  guardar.disabled = false;
  cerrar.disabled = false;
  errorTexto.hidden = true;
  aviso.hidden = true;

  titulo.textContent = idUsuario
    ? 'Editar integrante'
    : 'Registrar integrante';

  estado.textContent = 'Cargando formulario…';
  dialogo.showModal();

  try {
    const [opciones, existente] = await Promise.all([
      obtenerOpcionesIntegrante(),
      idUsuario
        ? obtenerIntegranteEditable(idUsuario)
        : Promise.resolve(null),
    ]);

    if (actual !== revision || !autorizado) return;

    if (!idUsuario && opciones.ciclos.length !== 1) {
      throw {
        code: '22023',
        message: 'Debe existir exactamente un ciclo activo para registrar integrantes.',
      };
    }

    if (existente && !existente.es_activo) {
      throw {
        code: '22023',
        message: 'Este integrante está inactivo.',
      };
    }

    registro = existente || {
      id_usuario: crearId(),
      version_perfil: null,
      nombres: '',
      apellido: '',
      rol: 'conquistador',
      id_unidad: null,
      id_clase: null,
      url_foto: '',
    };

    for (const nombre of ['nombres', 'apellido', 'rol', 'url_foto']) {
      campo(nombre).value = registro[nombre] || '';
    }

    campo('rol').disabled = existente?.rol === 'directiva';

    llenarOpciones(
      'id_unidad',
      opciones.unidades,
      'id_unidad',
      registro.id_unidad
    );

    llenarOpciones(
      'id_clase',
      opciones.clases,
      'id_clase',
      registro.id_clase
    );

    estado.textContent = existente
      ? 'Se conservarán las asistencias, cuotas, insignias y la cuenta vinculada.'
      : `Se registrará en el ciclo ${opciones.ciclos[0].anio}, sin cuenta vinculada.`;

    form.hidden = false;
    guardar.hidden = false;
    campo('nombres').focus();
  } catch (error) {
    if (actual !== revision) return;

    estado.textContent = '';
    mostrarError(error);
  }
}

form.addEventListener('submit', async (evento) => {
  evento.preventDefault();

  if (
    !autorizado ||
    !registro ||
    guardando ||
    !form.reportValidity()
  ) {
    return;
  }

  const actual = revision;

  const datos = {
    ...registro,
    nombres: campo('nombres').value.trim(),
    apellido: campo('apellido').value.trim(),
    rol: campo('rol').value,
    id_unidad: campo('id_unidad').value || null,
    id_clase: campo('id_clase').value || null,
    url_foto: campo('url_foto').value.trim() || null,
  };

  guardando = true;
  campos.disabled = true;
  guardar.disabled = true;
  cerrar.disabled = true;
  guardar.textContent = 'Guardando…';
  errorTexto.hidden = true;

  try {
    const id = await guardarIntegrante(datos);

    if (actual !== revision) return;

    let texto = registro.version_perfil === null
      ? 'Integrante registrado. Su perfil todavía no tiene cuenta vinculada.'
      : 'Perfil actualizado. Su historial se conserva.';

    try {
      await alGuardar?.(id);
    } catch (error) {
      console.error(
        'El perfil se guardó, pero no se pudo refrescar la lista:',
        error
      );

      texto = 'El perfil se guardó. Recarga la página para actualizar el directorio.';
    }

    if (actual !== revision) return;

    dialogo.close();
    aviso.textContent = texto;
    aviso.hidden = false;
  } catch (error) {
    if (actual === revision) {
      mostrarError(error);
    }
  } finally {
    if (actual === revision) {
      guardando = false;
      campos.disabled = false;
      guardar.disabled = false;
      cerrar.disabled = false;
      guardar.textContent = 'Guardar perfil';
    }
  }
});

nuevo.addEventListener('click', () => {
  void abrir();
});

editar.addEventListener('click', () => {
  const id = obtenerUsuarioSeleccionado();

  if (id) {
    void abrir(id);
  }
});

cerrar.addEventListener('click', () => {
  dialogo.close();
});

dialogo.addEventListener('cancel', (evento) => {
  if (guardando) {
    evento.preventDefault();
  }
});

dialogo.addEventListener('close', () => {
  revision += 1;
  registro = null;
  guardando = false;
  form.reset();
  guardar.textContent = 'Guardar perfil';
});