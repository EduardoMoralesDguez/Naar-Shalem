import { obtenerSupabase } from '../lib/supabase.js';
import { prepararFoto } from './fotos.js';
async function rpc(nombre, datos) {
 const {data,error}=await obtenerSupabase().rpc(nombre,datos).abortSignal(AbortSignal.timeout(15000));
 if(error) throw error; return data;
}
export async function obtenerOrganizacion(ciclo=null) {
 const panel=await rpc('organizacion_panel',{p_ciclo:ciclo});
 const paths=panel.unidades.map(u=>u.foto_path).filter(Boolean);
 if(paths.length){const {data,error}=await obtenerSupabase().storage.from('unidades-fotos').createSignedUrls(paths,900);
 if(!error) for(const u of panel.unidades) u.foto=data.find(f=>f.path===u.foto_path)?.signedUrl;}
 return panel;
}
export const guardarOrganizacion=(accion,datos)=>rpc('organizacion_guardar',{p_accion:accion,p_datos:datos});
export async function subirFotoUnidad(id,file){
 const blob=await prepararFoto(file),path=`${id}/${crypto.randomUUID()}.webp`;
 const {error}=await obtenerSupabase().storage.from('unidades-fotos').upload(path,blob,{contentType:'image/webp',upsert:false});
 if(error) throw error;return path;
}
