import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';
export const listarActividades = (desde, hasta) => consultarTodasLasFilas(() => obtenerSupabase()
  .rpc('calendario_listar', { p_desde: desde, p_hasta: hasta }).order('fecha').order('hora').order('id'));
export async function guardarActividad(actividad) {
  const { data, error } = await obtenerSupabase().rpc('calendario_guardar', {
    p_id: actividad.id, p_version: actividad.version, p_fecha: actividad.fecha,
    p_hora: actividad.hora, p_nombre: actividad.nombre, p_cobra: actividad.cobra_cuota,
    p_tipo: actividad.tipo, p_fecha_fin: actividad.fecha_fin,
    p_unidad: actividad.destinatario_unidad, p_clase: actividad.destinatario_clase,
  }).abortSignal(AbortSignal.timeout(15000));
  if (error) throw error; return data;
}
export async function cancelarActividad(actividad, motivo) {
  const { error } = await obtenerSupabase().rpc('calendario_cancelar', {
    p_id: actividad.id, p_version: actividad.version, p_motivo: motivo,
  }).abortSignal(AbortSignal.timeout(15000));
  if (error) throw error;
}

export async function eliminarActividad(actividad) {
  const { error } = await obtenerSupabase().rpc('calendario_eliminar', {
    p_id: actividad.id, p_version: actividad.version,
  }).abortSignal(AbortSignal.timeout(15000));
  if (error) throw error;
}
