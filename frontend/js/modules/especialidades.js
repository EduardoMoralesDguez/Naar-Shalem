// frontend/js/modules/especialidades.js

import { obtenerEspecialidades } from '../services/catalogo.js';

const seccion = document.getElementById('especialidades');
const estado = document.getElementById('especialidadesEstado');
const lista = document.getElementById('especialidadesLista');

export function reiniciarEspecialidades() {
  lista.replaceChildren();
  estado.textContent = '';
  estado.hidden = true;
  seccion.hidden = true;
}

function resolverImagen(ruta) {
  if (typeof ruta !== 'string' || !ruta.trim()) return null;

  try {
    // La ruta continúa siendo relativa a index.html,
    // aunque este archivo esté dentro de js/modules/.
    const url = new URL(ruta, document.baseURI);

    if (!['http:', 'https:', 'file:'].includes(url.protocol)) {
      return null;
    }

    return url.href;
  } catch {
    return null;
  }
}

function crearInsignia(especialidad) {
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
  return item;
}

function pintarEspecialidades(especialidades) {
  const fragmento = document.createDocumentFragment();

  especialidades.forEach((especialidad) => {
    fragmento.appendChild(crearInsignia(especialidad));
  });

  lista.replaceChildren(fragmento);
}

export async function cargarEspecialidades(idUsuario, sigueVigente) {
  seccion.hidden = false;
  estado.textContent = 'Cargando especialidades…';
  estado.hidden = false;

  try {
    const especialidades = await obtenerEspecialidades(idUsuario);

    if (!sigueVigente()) return;

    pintarEspecialidades(especialidades);

    estado.textContent = especialidades.length
      ? ''
      : 'Aún no hay especialidades obtenidas';

    estado.hidden = especialidades.length > 0;
  } catch (error) {
    if (!sigueVigente()) return;

    console.error('Error al cargar especialidades desde Supabase:', error);

    lista.replaceChildren();
    estado.textContent =
      'No se pudieron cargar las especialidades. Vuelve a seleccionar al usuario para reintentar.';
    estado.hidden = false;
  }
}