// frontend/js/modules/usuarios.js

const selector = document.getElementById('selectorUsuario');
const mensaje = document.getElementById('mensaje');
const tarjeta = document.getElementById('tarjeta');
const nombre = document.getElementById('tarjetaNombre');
const rol = document.getElementById('tarjetaRol');
const unidad = document.getElementById('tarjetaUnidad');
const clase = document.getElementById('tarjetaClase');

function capitalizar(texto = '') {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

export function mostrarCargaUsuarios() {
  selector.disabled = true;
  selector.replaceChildren(new Option('Cargando usuarios...', ''));
  mensaje.textContent = '';
  mensaje.hidden = true;
  tarjeta.hidden = true;
}

export function mostrarUsuarios(usuarios) {
  selector.replaceChildren(
    new Option(
      usuarios.length
        ? '-- Elige un usuario --'
        : 'No hay usuarios disponibles',
      ''
    )
  );

  const fragmento = document.createDocumentFragment();

  usuarios.forEach((usuario) => {
    const opcion = document.createElement('option');
    opcion.value = usuario.id_usuario;
    opcion.textContent = `${usuario.nombres} ${usuario.apellido}`;
    fragmento.appendChild(opcion);
  });

  selector.appendChild(fragmento);
  selector.disabled = usuarios.length === 0;
  mensaje.hidden = true;
}

export function mostrarErrorUsuarios(texto) {
  selector.replaceChildren(new Option('No disponible', ''));
  selector.disabled = true;
  tarjeta.hidden = true;
  mensaje.textContent = texto;
  mensaje.hidden = false;
}

export function mostrarPerfil(usuario) {
  nombre.textContent = `${usuario.nombres} ${usuario.apellido}`;
  rol.textContent = capitalizar(usuario.rol);
  unidad.textContent = usuario.unidad || 'Sin asignar';
  clase.textContent = usuario.clase || 'Sin asignar';
  tarjeta.hidden = false;
}

export function ocultarPerfil() {
  tarjeta.hidden = true;
}

export function obtenerUsuarioSeleccionado() {
  return selector.value;
}

export function alCambiarUsuario(callback) {
  selector.addEventListener('change', (evento) => {
    callback(evento.target.value);
  });
}