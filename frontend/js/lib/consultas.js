// frontend/js/lib/consultas.js

import { TAMANO_PAGINA } from '../config.js';

// Cada consulta debe tener un orden estable para poder paginar.
// Se continúa hasta recibir una página vacía, incluso si
// Supabase aplica un límite menor al tamaño solicitado.
export async function consultarTodasLasFilas(crearConsulta) {
  const filas = [];
  let inicio = 0;

  while (true) {
    const { data, error } = await crearConsulta().range(
      inicio,
      inicio + TAMANO_PAGINA - 1
    );

    if (error) throw error;

    if (!Array.isArray(data)) {
      throw new Error('Supabase devolvió una respuesta inesperada.');
    }

    if (data.length === 0) {
      return filas;
    }

    filas.push(...data);
    inicio += data.length;
  }
}