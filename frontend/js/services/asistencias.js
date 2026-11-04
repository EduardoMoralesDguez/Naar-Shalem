import {crearRpc} from '../lib/rpc.js';
// frontend/js/services/asistencias.js
import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

const rpc = crearRpc(15000);

export function listarReuniones() {
  return consultarTodasLasFilas(() =>
    obtenerSupabase()
      .rpc('reuniones_listar_turnos').abortSignal(AbortSignal.timeout(15000))
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
  return consultarTodasLasFilas(() => obtenerSupabase().rpc('historial_matriz_turnos').abortSignal(AbortSignal.timeout(15000))
    .order('fecha').order('numero').order('reunion').order('id_usuario'));
}
export const obtenerContextoAsistencias=()=>rpc('asistencias_contexto',{});
export const obtenerBitacoraAsistencias=()=>consultarTodasLasFilas(()=>obtenerSupabase().rpc('asistencias_bitacora').abortSignal(AbortSignal.timeout(15000)).order('fecha',{ascending:false}).order('id'));
export const enviarAsistencia=o=>rpc('asistencia_operar',{p_operacion:o.id,p_epoca:o.epoca,p_id:o.reunion,p_version:o.version,p_accion:o.accion,p_datos:o.datos});
export async function verificarAsistenciaCuenta(id){const {data,error}=await obtenerSupabase().auth.getSession();if(error||data.session?.user.id!==id)throw new Error('Inicia sesión con la cuenta que guardó las asistencias.');await obtenerContextoAsistencias();}
