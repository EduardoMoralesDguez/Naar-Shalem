import {obtenerSupabase} from './supabase.js';

// Conserva el error original (code/details) para conflictos y reintentos offline.
// El timeout se configura por servicio; no se reintentan escrituras automáticamente.
export function crearRpc(timeout = 15000, cliente = obtenerSupabase) {
  return async function rpc(nombre, datos = {}) {
    const {data, error} = await cliente()
      .rpc(nombre, datos)
      .abortSignal(AbortSignal.timeout(timeout));
    if (error) throw error;
    return data;
  };
}
