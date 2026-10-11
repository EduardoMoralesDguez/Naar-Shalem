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

export function obtenerListaAsistencias() {
  return consultarTodasLasFilas(() =>
    obtenerSupabase()
      .rpc('integrantes_asistencias')
      .order('apellido')
      .order('nombres')
      .order('id_usuario')
  );
}

export function obtenerHistorialAsistencias(id) {
  return consultarTodasLasFilas(() =>
    obtenerSupabase()
      .from('asistencias')
      .select('id_asistencia,fecha,estado')
      .eq('id_usuario', id)
      .order('fecha', { ascending: false })
      .order('id_asistencia')
  );
}