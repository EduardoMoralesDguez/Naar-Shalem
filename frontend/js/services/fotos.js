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

export async function prepararFoto(file) {
  if (
    !['image/jpeg', 'image/png', 'image/webp'].includes(file.type) ||
    file.size > 8 * 1024 * 1024
  ) {
    throw new Error(
      'Selecciona una imagen JPG, PNG o WebP de hasta 8 MB.'
    );
  }

  const bitmap = await createImageBitmap(file);

  try {
    if (bitmap.width * bitmap.height > 25000000) {
      throw new Error(
        'La imagen es demasiado grande. Usa una de menos de 25 megapíxeles.'
      );
    }

    const ratio = Math.min(
      1,
      640 / Math.max(bitmap.width, bitmap.height)
    );

    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * ratio));
    canvas.height = Math.max(1, Math.round(bitmap.height * ratio));

    canvas.getContext('2d').drawImage(
      bitmap,
      0,
      0,
      canvas.width,
      canvas.height
    );

    const blob = await new Promise(resolve => {
      canvas.toBlob(resolve, 'image/webp', .85);
    });

    if (
      !blob ||
      blob.type !== 'image/webp' ||
      blob.size > 2097152
    ) {
      throw new Error(
        'No se pudo preparar la foto. Prueba con otra imagen.'
      );
    }

    return blob;
  } finally {
    bitmap.close();
  }
}

export async function subirFoto(id, blob) {
  const path = `${id}/${nuevoId()}.webp`;

  const { error } = await obtenerSupabase()
    .storage.from(BUCKET)
    .upload(path, blob, {
      contentType: 'image/webp',
      upsert: false,
    });

  if (error) throw error;

  return path;
}

export async function limpiarFoto(path) {
  if (!path) return;

  try {
    const { error } = await obtenerSupabase()
      .storage.from(BUCKET)
      .remove([path]);

    if (error) throw error;
  } catch (error) {
    console.error('No se pudo limpiar una foto sin uso:', error);
  }
}