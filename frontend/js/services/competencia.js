import {obtenerSupabase} from '../lib/supabase.js';
async function rpc(nombre,datos){const {data,error}=await obtenerSupabase().rpc(nombre,datos).abortSignal(AbortSignal.timeout(20000));if(error)throw error;return data;}
export async function obtenerCompetencia(reunion=null,desde=null,hasta=null){const p=await rpc('reunion_integrada_panel',{p_reunion:reunion,p_desde:desde,p_hasta:hasta});if(p?.api_version!==22)throw new Error('La base de datos necesita actualizar Competencia. Directiva debe aplicar la migración 022 después de 021.');return p;}
export const guardarCompetencia=(id,accion,datos)=>rpc('reunion_integrada_guardar',{p_operacion:id,p_accion:accion,p_datos:datos});

export const obtenerPuntajePerfil=usuario=>rpc('competencia_perfil',{p_usuario:usuario});
export const obtenerPublicacion=()=>rpc('competencia_publicacion',{});
export const obtenerPuntajeUnidad=unidad=>rpc('competencia_unidad',{p_unidad:unidad});
