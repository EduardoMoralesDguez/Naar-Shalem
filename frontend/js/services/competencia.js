import {obtenerSupabase} from '../lib/supabase.js';
async function rpc(nombre,datos){const {data,error}=await obtenerSupabase().rpc(nombre,datos).abortSignal(AbortSignal.timeout(20000));if(error)throw error;return data;}
export const obtenerCompetencia=(reunion=null,desde=null,hasta=null)=>rpc('competencia_panel',{p_reunion:reunion,p_desde:desde,p_hasta:hasta});
export const guardarCompetencia=(id,accion,datos)=>rpc('competencia_guardar',{p_operacion:id,p_accion:accion,p_datos:datos});
