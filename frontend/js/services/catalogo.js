// frontend/js/services/catalogo.js

import { obtenerSupabase } from '../lib/supabase.js';
import { consultarTodasLasFilas } from '../lib/consultas.js';

// Este archivo consulta y transforma datos.
// No modifica elementos del HTML.

export async function obtenerUsuarios() {
  const supabase = obtenerSupabase();

  const filas = await consultarTodasLasFilas(() =>
    supabase
      .from('usuarios')
      .select(`
        id_usuario,
        nombres,
        apellido,
        rol,
        unidad:unidades(nombre),
        clase:clases(nombre),
        ciclos!inner(es_activo)
      `)
      .eq('es_activo', true)
      .eq('ciclos.es_activo', true)
      .order('nombres')
      .order('apellido')
      .order('id_usuario')
  );

  return filas.map((usuario) => ({
    id_usuario: usuario.id_usuario,
    nombres: usuario.nombres,
    apellido: usuario.apellido,
    rol: usuario.rol,
    unidad: usuario.unidad?.nombre || null,
    clase: usuario.clase?.nombre || null,
  }));
}

export function calcularProgreso(registrosAsistencia, registrosCuotas) {
  const asistencias = registrosAsistencia.filter(
    (registro) => registro.estado === 'asistencia'
  ).length;

  const justificados = registrosAsistencia.filter(
    (registro) => registro.estado === 'justificado'
  ).length;

  const faltas = registrosAsistencia.filter(
    (registro) => registro.estado === 'falta'
  ).length;

  const totalRegistros = registrosAsistencia.length;
  const semanasRegistradas = registrosCuotas.length;

  const semanasPagadas = registrosCuotas.filter(
    (registro) => Number(registro.monto_pagado) > 0
  ).length;

  const totalPagado = registrosCuotas.reduce(
    (suma, registro) => suma + Number(registro.monto_pagado),
    0
  );

  // Conserva las fórmulas utilizadas por el dashboard actual.
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

export async function obtenerProgreso(idUsuario) {
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
    consultarTodasLasFilas(() =>
      supabase
        .from('cuotas')
        .select(`
          id_cuota,
          monto_pagado,
          ciclos!inner(es_activo)
        `)
        .eq('id_usuario', idUsuario)
        .eq('ciclos.es_activo', true)
        .order('id_cuota')
    ),
  ]);

  return calcularProgreso(asistencias, cuotas);
}

export async function obtenerEspecialidades(idUsuario) {
  const supabase = obtenerSupabase();

  const asignaciones = await consultarTodasLasFilas(() =>
    supabase
      .from('conquistador_especialidades')
      .select(`
        id_especialidad,
        especialidad:especialidades!inner(
          id_especialidad,
          nombre,
          url_imagen
        )
      `)
      .eq('id_usuario', idUsuario)
      .order('id_especialidad')
  );

  return asignaciones
    .map((asignacion) => asignacion.especialidad)
    .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
}