// frontend/js/services/asistencias.js
import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

async function rpc(nombre, parametros) {
  const { data, error } = await obtenerSupabase().rpc(
    nombre,
    parametros
  );

  if (error) throw error;

  return data;
}

export function listarReuniones() {
  return consultarTodasLasFilas(() =>
    obtenerSupabase()
      .rpc('reuniones_listar')
      .order('fecha', { ascending: false })
      .order('id')
  );
}

export const crearReunion = fecha =>
  rpc('reunion_crear', { p_fecha: fecha });

export const obtenerReunion = id =>
  rpc('reunion_panel', { p_id: id });

export const actuarReunion = (panel, accion, datos = {}) =>
  rpc('reunion_accion', {
    p_id: panel.id,
    p_version: panel.version,
    p_accion: accion,
    p_datos: datos,
  });

export function obtenerMatriz() {
  return consultarTodasLasFilas(() => obtenerSupabase().rpc('historial_matriz')
    .order('fecha').order('reunion').order('id_usuario'));
}
