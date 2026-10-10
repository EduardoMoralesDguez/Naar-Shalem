// frontend/js/services/integrantes-admin.js

import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

export async function obtenerOpcionesIntegrante() {
  const db = obtenerSupabase();

  const [unidades, clases, ciclos] = await Promise.all([
    consultarTodasLasFilas(() =>
      db.from('unidades')
        .select('id_unidad,nombre')
        .order('nombre')
        .order('id_unidad')
    ),
    consultarTodasLasFilas(() =>
      db.from('clases')
        .select('id_clase,nombre')
        .order('nombre')
        .order('id_clase')
    ),
    consultarTodasLasFilas(() =>
      db.from('ciclos')
        .select('id_ciclo,anio')
        .eq('es_activo', true)
        .order('id_ciclo')
    ),
  ]);

  return { unidades, clases, ciclos };
}

export async function obtenerIntegranteEditable(idUsuario) {
  const { data, error } = await obtenerSupabase()
    .from('usuarios')
    .select(
      'id_usuario,nombres,apellido,rol,id_unidad,id_clase,url_foto,es_activo,version_perfil'
    )
    .eq('id_usuario', idUsuario)
    .single();

  if (error) throw error;

  return data;
}

export async function guardarIntegrante(registro) {
  const { data, error } = await obtenerSupabase().rpc(
    'admin_guardar_integrante',
    {
      p_id_usuario: registro.id_usuario,
      p_version: registro.version_perfil,
      p_nombres: registro.nombres,
      p_apellido: registro.apellido,
      p_rol: registro.rol,
      p_id_unidad: registro.id_unidad,
      p_id_clase: registro.id_clase,
      p_url_foto: registro.url_foto,
    }
  );

  if (error) throw error;

  return data;
}