// frontend/js/modules/progreso.js

import { META_CUOTAS, FORMATO_MONEDA } from '../config.js';
import { obtenerProgreso } from '../services/catalogo.js';

const dashboard = document.getElementById('dashboard');
const dashboardError = document.getElementById('dashboardError');
const dashboardMetricas = document.getElementById('dashboardMetricas');

const asistenciaPorcentaje = document.getElementById('asistenciaPorcentaje');
const asistenciaBarra = document.getElementById('asistenciaBarra');
const asistenciaDetalle = document.getElementById('asistenciaDetalle');

const cuotasPorcentaje = document.getElementById('cuotasPorcentaje');
const cuotasBarra = document.getElementById('cuotasBarra');
const cuotasDetalle = document.getElementById('cuotasDetalle');
const totalPagado = document.getElementById('totalPagado');

const formatoMoneda = new Intl.NumberFormat(FORMATO_MONEDA.locale, {
  style: 'currency',
  currency: FORMATO_MONEDA.currency,
  maximumFractionDigits: 2,
});

export function reiniciarProgreso() {
  dashboard.hidden = true;
  dashboardError.hidden = true;
  dashboardError.textContent = '';
}

function pintarProgreso({ asistencia, cuotas }, cobraCuotas,admin) {
  dashboardMetricas.classList.toggle('solo-asistencia', !cobraCuotas);
  cuotasPorcentaje.closest('.metrica').hidden = !cobraCuotas;
  totalPagado.closest('.total-pagado').hidden = !cobraCuotas||!admin;
  asistenciaPorcentaje.textContent = `${asistencia.porcentaje}%`;
  asistenciaBarra.style.width = `${asistencia.porcentaje}%`;

  asistenciaDetalle.textContent =
    `${asistencia.asistencias} asistencias + ${asistencia.justificados} justificadas ` +
    `de ${asistencia.total_registros} reuniones`;

  if (!cobraCuotas) return;

  cuotasPorcentaje.textContent = `${cuotas.porcentaje}%`;
  cuotasBarra.style.width = `${cuotas.porcentaje}%`;

  cuotasBarra.classList.toggle(
    'bajo-meta',
    cuotas.porcentaje < META_CUOTAS
  );

  cuotasDetalle.hidden=!admin;
  cuotasDetalle.textContent = !admin?'':
    `${cuotas.semanas_pagadas} de ${cuotas.semanas_registradas} cuotas pagadas ` +
    `(meta: ${META_CUOTAS}%)`;

  totalPagado.textContent = admin?formatoMoneda.format(cuotas.total_pagado):'';
}

export async function cargarProgreso(idUsuario, sigueVigente, cobraCuotas = true,admin=false) {
  try {
    const progreso = await obtenerProgreso(idUsuario, cobraCuotas);

    if (!sigueVigente()) return;

    pintarProgreso(progreso, cobraCuotas,admin);
    dashboardError.hidden = true;
    dashboardMetricas.hidden = false;
    dashboard.hidden = false;
  } catch (error) {
    if (!sigueVigente()) return;

    console.error('Error al cargar progreso desde Supabase:', error);

    dashboardError.textContent =
      'No se pudo cargar el progreso de este usuario.';
    dashboardError.hidden = false;
    dashboardMetricas.hidden = true;
    dashboard.hidden = false;
  }
}