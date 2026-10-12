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
  const porId = new Map(presentacion.map(p => [p.id_usuario, p]));
  return firmarFotos(filas.map(u => ({ ...u, ...porId.get(u.id_usuario) })));
}

export function calcularProgreso(registrosAsistencia, registrosCuotas) {
  const asistencias = registrosAsistencia.filter(
    registro => registro.estado === 'asistencia'
  ).length;

  const justificados = registrosAsistencia.filter(
    registro => registro.estado === 'justificado'
  ).length;

  const faltas = registrosAsistencia.filter(
    registro => registro.estado === 'falta'
  ).length;

  const totalRegistros = registrosAsistencia.length;
  const semanasRegistradas = registrosCuotas.length;

  const semanasPagadas = registrosCuotas.filter(
    registro => Number(registro.monto_pagado) > 0
  ).length;

  const totalPagado = registrosCuotas.reduce(
    (suma, registro) => suma + Number(registro.monto_pagado),
    0
  );

  return {
    asistencia: {
      asistencias,
      justificados,
      faltas,
      total_registros: totalRegistros,
      porcentaje: totalRegistros
        ? Math.round(((asistencias + justificados) / totalRegistros) * 100)
        : 0,
    },
    cuotas: {
      total_pagado: totalPagado,
      semanas_pagadas: semanasPagadas,
      semanas_registradas: semanasRegistradas,
      porcentaje: semanasRegistradas
        ? Math.round((semanasPagadas / semanasRegistradas) * 100)
        : 0,
    },
  };
}

export async function obtenerProgreso(idUsuario, cobraCuotas = true) {
  const supabase = obtenerSupabase();

  const [asistencias, cuotas] = await Promise.all([
    consultarTodasLasFilas(() =>
      supabase
        .from('asistencias')
        .select(`
          id_asistencia,
          estado,
          ciclos!inner(es_activo)
        `)
        .eq('id_usuario', idUsuario)
        .eq('ciclos.es_activo', true)
        .order('id_asistencia')
    ),
    cobraCuotas ? supabase.rpc('cuotas_resumen', { p_usuario: idUsuario }).then(({ data, error }) => { if (error) throw error; return data; }) : Promise.resolve(null),
  ]);

  const progreso = calcularProgreso(asistencias, []);
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