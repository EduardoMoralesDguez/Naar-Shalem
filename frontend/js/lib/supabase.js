// frontend/js/lib/supabase.js

import {
  SUPABASE_URL,
  SUPABASE_PUBLIC_KEY,
} from '../config.js';

let cliente = null;

// Todos los módulos comparten una sola instancia.
// La inicialización se realiza al solicitar el cliente,
// para poder mostrar errores de configuración en la pantalla.
export function obtenerSupabase() {
  if (cliente) return cliente;

  if (!SUPABASE_URL || !SUPABASE_PUBLIC_KEY) {
    throw new Error(
      'Falta configurar la URL o la clave pública en js/config.js.'
    );
  }

  let url;

  try {
    url = new URL(SUPABASE_URL);
  } catch {
    throw new Error(
      'La URL de Supabase en js/config.js no es válida.'
    );
  }

  if (
    url.protocol !== 'https:' ||
    !['', '/'].includes(url.pathname) ||
    url.search ||
    url.hash
  ) {
    throw new Error(
      'La URL de Supabase debe comenzar con https:// y no incluir /rest/v1 ni otras rutas.'
    );
  }

  if (!window.supabase?.createClient) {
    throw new Error(
      'No se pudo cargar Supabase. Revisa tu conexión y recarga la página.'
    );
  }

  cliente = window.supabase.createClient(
    url.origin,
    SUPABASE_PUBLIC_KEY
  );

  return cliente;
}