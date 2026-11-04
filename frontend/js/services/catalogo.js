// frontend/js/services/catalogo.js

import { firmarFotos } from './fotos.js';
import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

export async function obtenerUsuarios() {
  const filas = await consultarTodasLasFilas(() =>
    obtenerSupabase()
      .rpc('directorio_portal')
      .order('nombres')
      .order('apellido')
      .order('id_usuario')
  );

  const presentacion = await consultarTodasLasFilas(() => obtenerSupabase()
    .rpc('presentacion_integrantes').order('id_usuario'));
  const colores = await consultarTodasLasFilas(() => obtenerSupabase().rpc('colores_integrantes').order('id_usuario'));
  const porColor = new Map(colores.map(c=>[c.id_usuario,c.color_clase]));
  const porId = new Map(presentacion.map(p => [p.id_usuario, p]));
  return firmarFotos(filas.map(u => ({ ...u, ...porId.get(u.id_usuario), color_clase:porColor.get(u.id_usuario) })));
}

export async function obtenerProgreso(idUsuario, cobraCuotas = true) {
  const supabase = obtenerSupabase();

  const [asistencias, cuotas] = await Promise.all([
    supabase.rpc('asistencia_resumen', { p_usuario: idUsuario }).then(({ data, error }) => { if (error) throw error; return data; }),
    cobraCuotas ? supabase.rpc('cuotas_resumen', { p_usuario: idUsuario }).then(({ data, error }) => { if (error) throw error; return data; }) : Promise.resolve(null),
  ]);

  const progreso = {cuotas: {total_pagado: 0, semanas_pagadas: 0, semanas_registradas: 0, porcentaje: 0}};
  progreso.asistencia = asistencias;
  if (cuotas) progreso.cuotas = cuotas;
  return progreso;
}

export async function obtenerEspecialidades(idUsuario) {
  const especialidades = await consultarTodasLasFilas(() =>
    obtenerSupabase()
      .rpc('especialidades_visibles', {
        p_id_usuario: idUsuario,
      })
      .order('id_especialidad')
  );

  return especialidades.sort((a, b) =>
    a.nombre.localeCompare(b.nombre, 'es')
  );
}