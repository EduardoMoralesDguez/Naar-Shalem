// frontend/js/services/fotos.js

import { obtenerSupabase } from '../lib/supabase.js';

const BUCKET = 'integrantes-fotos';

export function nuevoId() {
  if (crypto.randomUUID) return crypto.randomUUID();

  const bytes = crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;

  const hex = [...bytes]
    .map(valor => valor.toString(16).padStart(2, '0'))
    .join('');

  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20),
  ].join('-');
}

export async function firmarFotos(filas) {
  const paths = [...new Set(
    filas.map(usuario => usuario.foto_path).filter(Boolean)
  )];

  if (!paths.length) return filas;

  const urls = new Map();

  try {
    const { data, error } = await obtenerSupabase()
      .storage.from(BUCKET)
      .createSignedUrls(paths, 900);

    if (error) throw error;

    for (const item of data || []) {
      if (item.signedUrl) {
        urls.set(item.path, item.signedUrl);
      }
    }
  } catch (error) {
    console.error('No se pudieron resolver las fotos:', error);
  }

  return filas.map(usuario => ({
    ...usuario,
    url_foto: usuario.foto_path
      ? urls.get(usuario.foto_path) || null
      : usuario.url_foto,
  }));
}
