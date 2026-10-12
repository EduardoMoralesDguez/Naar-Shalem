import { obtenerSupabase } from '../lib/supabase.js';
async function rpc(nombre, datos = {}) {
  const { data, error } = await obtenerSupabase().rpc(nombre, datos).abortSignal(AbortSignal.timeout(15000));
  if (error) throw error;
  return data;
}
export const obtenerCuotas = () => rpc('cuotas_panel');
export const enviarCuota = o => rpc('cuotas_operar', { p_operacion: o.id, p_accion: o.accion, p_datos: o.datos });
export async function verificarCuenta(id) {
  const { data, error } = await obtenerSupabase().auth.getSession();
  if (error || data.session?.user.id !== id) throw new Error('Inicia sesión con la cuenta que guardó estos movimientos.');
  const perfiles = await rpc('mi_perfil');
  if (!perfiles?.length) throw new Error('La cuenta ya no tiene un perfil activo.');
}
