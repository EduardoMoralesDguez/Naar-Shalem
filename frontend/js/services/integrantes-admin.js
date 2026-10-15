// frontend/js/services/integrantes-admin.js

import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

export async function obtenerOpcionesIntegrante() {
  const db = obtenerSupabase();

  const [unidades, clases, ciclos] = await Promise.all([
    consultarTodasLasFilas(() =>
      db.from('unidades')
        .select('id_unidad,nombre,ciclos!inner(es_activo)')
        .eq('ciclos.es_activo', true).eq('es_activa', true)
        .order('nombre')
        .order('id_unidad')
    ),
    consultarTodasLasFilas(() =>
      db.from('clases')
        .select('id_clase,nombre').eq('es_activa', true)
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

export async function obtenerIntegranteEditable(id) {
  const { data, error } = await obtenerSupabase()
    .from('usuarios')
    .select(
      'id_usuario,nombres,apellido,rol,id_unidad,id_clase,url_foto,foto_path,es_activo,version_perfil'
    )
    .eq('id_usuario', id)
    .single();

  if (error) throw error;

  return data;
}

export async function guardarIntegrante(usuario) {
  const { data, error } = await obtenerSupabase()
    .rpc('admin_guardar_perfil', {
      p_id_usuario: usuario.id_usuario,
      p_version: usuario.version_perfil,
      p_nombres: usuario.nombres,
      p_apellido: usuario.apellido,
      p_rol: usuario.rol,
      p_id_unidad: usuario.id_unidad,
      p_id_clase: usuario.id_clase,
      p_url_foto: usuario.url_foto,
      p_foto_path: usuario.foto_path,
    });

  if (error) throw error;

  return data;
}

export async function cambiarEstado(usuario, activo) {
  const { error } = await obtenerSupabase()
    .rpc('admin_estado_integrante', {
      p_id_usuario: usuario.id_usuario,
      p_version: usuario.version_perfil,
      p_activo: activo,
    });

  if (error) throw error;
}