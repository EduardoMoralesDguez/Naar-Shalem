import {crearRpc} from '../lib/rpc.js';
import { obtenerSupabase } from '../lib/supabase.js';
const rpc = crearRpc(15000);
export async function obtenerOrganizacion(ciclo=null) {
 const panel=await rpc('organizacion_panel',{p_ciclo:ciclo});
 const paths=panel.unidades.map(u=>u.foto_path).filter(Boolean);
 if(paths.length){const {data,error}=await obtenerSupabase().storage.from('unidades-fotos').createSignedUrls(paths,900);
 if(!error) for(const u of panel.unidades) u.foto=data.find(f=>f.path===u.foto_path)?.signedUrl;}
 for(const u of panel.unidades)if(u.url_foto)u.foto=u.url_foto;
 return panel;
}
export const guardarOrganizacion=(accion,datos)=>rpc('organizacion_guardar',{p_accion:accion,p_datos:datos});
