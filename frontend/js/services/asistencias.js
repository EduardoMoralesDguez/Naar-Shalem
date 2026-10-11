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
      .rpc('reuniones_listar_turnos')
      .order('fecha', { ascending: false })
      .order('numero', { ascending: false })
      .order('id')
  );
}

export const crearReunion = (fecha, nombre) =>
  rpc('reunion_crear_turno', { p_fecha: fecha, p_nombre: nombre });

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
  return consultarTodasLasFilas(() => obtenerSupabase().rpc('historial_matriz_turnos')
    .order('fecha').order('numero').order('reunion').order('id_usuario'));
}
