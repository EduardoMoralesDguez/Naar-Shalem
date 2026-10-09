// app.js

// ============================================================
// CONFIGURACIÓN DE SUPABASE: EDITA ÚNICAMENTE ESTAS DOS LÍNEAS.
//
// 1. En tu proyecto de Supabase, abre "Connect" o la configuración
//    de API y copia la "Project URL". Pégala entre las comillas.
//
// 2. Copia la clave pública "anon" desde la sección "API Keys"
//    y pégala entre las comillas de SUPABASE_ANON_KEY.
//    También puedes usar la nueva clave pública "publishable".
//
// No necesitas un archivo .env.
// Nunca pegues una clave "service_role" ni una clave "secret":
// esas claves son privadas y no deben estar en el navegador.
// ============================================================

const SUPABASE_URL = 'https://azjakonzmibocgxszujj.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_9f2b9linwSSoasYqx2pg7A_hIBrNTjO';

// Nuestro schema.sql creó tablas en minúsculas.
// PostgreSQL convierte USUARIOS sin comillas a usuarios.
// Por eso las consultas usan .from('usuarios').
//
// Para que funcionen las consultas, Supabase debe permitir
// SELECT sobre las tablas y relaciones utilizadas mediante
// permisos y políticas RLS adecuados al acceso de tu aplicación.
//
// Ejecutar schema.sql no configura estas políticas.
// Con RLS activado y sin una política de lectura aplicable,
// Supabase puede devolver un arreglo vacío.
//
// Seleccionar aquí solo ciertas columnas no protege las demás:
// restringe en Supabase el acceso a los datos médicos y personales.
// No desactives RLS como solución general.

let clienteSupabase = null;
let errorConfiguracion = '';

try {
  if (
    SUPABASE_URL.includes('TU-PROYECTO') ||
    SUPABASE_ANON_KEY === 'PEGA_AQUI_TU_ANON_KEY'
  ) {
    throw new Error(
      'Abre js/app.js y pega tu Project URL y tu anon key en las dos constantes del inicio.'
    );
  }

  if (!window.supabase) {
    throw new Error(
      'No se pudo cargar Supabase desde el CDN. Revisa tu conexión y recarga la página.'
    );
  }

  clienteSupabase = window.supabase.createClient(
    SUPABASE_URL,
    SUPABASE_ANON_KEY
  );
} catch (error) {
  errorConfiguracion = error.message;
}

const META_CUOTAS = 70;
const TAMANO_PAGINA = 500;

const formatoMoneda = new Intl.NumberFormat('es-MX', {
  style: 'currency',
  currency: 'MXN',
  maximumFractionDigits: 0,
});

const selector = document.getElementById('selectorUsuario');
const mensaje = document.getElementById('mensaje');
const tarjeta = document.getElementById('tarjeta');
const tarjetaNombre = document.getElementById('tarjetaNombre');
const tarjetaRol = document.getElementById('tarjetaRol');
const tarjetaUnidad = document.getElementById('tarjetaUnidad');
const tarjetaClase = document.getElementById('tarjetaClase');

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

const especialidadesSeccion = document.getElementById('especialidades');
const especialidadesEstado = document.getElementById('especialidadesEstado');
const especialidadesLista = document.getElementById('especialidadesLista');

let usuarios = [];
let seleccionVersion = 0;

function capitalizar(texto) {
  return texto.charAt(0).toUpperCase() + texto.slice(1);
}

function mostrarError(texto) {
  mensaje.textContent = texto;
  mensaje.hidden = false;
}

function seleccionVigente(idUsuario, version) {
  return version === seleccionVersion && selector.value === idUsuario;
}

// Lee por páginas para no limitar los cálculos a la primera
// página de resultados devuelta por Supabase.
// Cada consulta debe tener un orden estable.
async function consultarTodasLasFilas(crearConsulta) {
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

    if (data.length === 0) break;

    filas.push(...data);
    inicio += data.length;
  }

  return filas;
}

async function cargarUsuarios() {
  selector.disabled = true;
  mensaje.hidden = true;

  try {
    if (!clienteSupabase) {
      throw new Error(errorConfiguracion || 'Supabase no está configurado.');
    }

    const filas = await consultarTodasLasFilas(() =>
      clienteSupabase
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

    usuarios = filas.map((usuario) => ({
      id_usuario: usuario.id_usuario,
      nombres: usuario.nombres,
      apellido: usuario.apellido,
      rol: usuario.rol,
      unidad: usuario.unidad?.nombre || null,
      clase: usuario.clase?.nombre || null,
    }));

    llenarSelector();
  } catch (error) {
    console.error('Error al cargar usuarios desde Supabase:', error);

    selector.replaceChildren(new Option('No disponible', ''));

    mostrarError(
      errorConfiguracion ||
      'No se pudieron cargar los usuarios. Revisa la conexión e inténtalo de nuevo.'
    );
  } finally {
    selector.disabled = usuarios.length === 0;
  }
}

function llenarSelector() {
  selector.replaceChildren(
    new Option(
      usuarios.length
        ? '-- Elige un usuario --'
        : 'No hay usuarios disponibles',
      ''
    )
  );

  usuarios.forEach((usuario) => {
    const opcion = document.createElement('option');
    opcion.value = usuario.id_usuario;
    opcion.textContent = `${usuario.nombres} ${usuario.apellido}`;
    selector.appendChild(opcion);
  });
}

function pintarProgreso({ asistencia, cuotas }) {
  asistenciaPorcentaje.textContent = `${asistencia.porcentaje}%`;
  asistenciaBarra.style.width = `${asistencia.porcentaje}%`;
  asistenciaDetalle.textContent =
    `${asistencia.asistencias} asistencias + ${asistencia.justificados} justificadas ` +
    `de ${asistencia.total_registros} reuniones`;

  cuotasPorcentaje.textContent = `${cuotas.porcentaje}%`;
  cuotasBarra.style.width = `${cuotas.porcentaje}%`;
  cuotasBarra.classList.toggle('bajo-meta', cuotas.porcentaje < META_CUOTAS);

  cuotasDetalle.textContent =
    `${cuotas.semanas_pagadas} de ${cuotas.semanas_registradas} semanas pagadas ` +
    `(meta: ${META_CUOTAS}%)`;

  totalPagado.textContent = formatoMoneda.format(cuotas.total_pagado);
}

async function cargarProgreso(idUsuario, version) {
  try {
    // Conserva las mismas reglas del backend anterior:
    // asistencia = (asistencias + justificadas) / registros;
    // cuotas = semanas con pago positivo / semanas registradas.
    // Ambas consultas consideran únicamente ciclos activos.
    const [registrosAsistencia, registrosCuotas] = await Promise.all([
      consultarTodasLasFilas(() =>
        clienteSupabase
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
        clienteSupabase
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

    if (!seleccionVigente(idUsuario, version)) return;

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

    const total = registrosCuotas.reduce(
      (suma, registro) => suma + Number(registro.monto_pagado),
      0
    );

    pintarProgreso({
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
        total_pagado: total,
        semanas_pagadas: semanasPagadas,
        semanas_registradas: semanasRegistradas,
        porcentaje: semanasRegistradas
          ? Math.round((semanasPagadas / semanasRegistradas) * 100)
          : 0,
      },
    });

    dashboardError.hidden = true;
    dashboardMetricas.hidden = false;
    dashboard.hidden = false;
  } catch (error) {
    console.error('Error al cargar progreso desde Supabase:', error);

    if (!seleccionVigente(idUsuario, version)) return;

    dashboardError.textContent = 'No se pudo cargar el progreso de este usuario.';
    dashboardError.hidden = false;
    dashboardMetricas.hidden = true;
    dashboard.hidden = false;
  }
}

function resolverImagen(ruta) {
  if (typeof ruta !== 'string' || !ruta.trim()) return null;

  try {
    // Las rutas img/especialidades/... siguen apuntando
    // a las imágenes del frontend, junto a index.html.
    const url = new URL(ruta, document.baseURI);

    if (!['http:', 'https:', 'file:'].includes(url.protocol)) {
      return null;
    }

    return url.href;
  } catch {
    return null;
  }
}

function pintarEspecialidades(lista) {
  especialidadesLista.replaceChildren();
  const fragmento = document.createDocumentFragment();

  lista.forEach((especialidad) => {
    const item = document.createElement('li');
    item.className = 'banda-item';

    const nombre = document.createElement('span');
    nombre.className = 'banda-nombre';
    nombre.textContent = especialidad.nombre;

    const fallback = document.createElement('span');
    fallback.className = 'banda-fallback';
    fallback.textContent = 'Imagen no disponible';
    fallback.hidden = true;

    const ruta = resolverImagen(especialidad.url_imagen);

    if (ruta) {
      const imagen = document.createElement('img');
      imagen.className = 'banda-insignia';
      imagen.alt = `Insignia de ${especialidad.nombre}`;
      imagen.width = 80;
      imagen.height = 80;
      imagen.decoding = 'async';

      imagen.addEventListener('error', () => {
        imagen.hidden = true;
        fallback.hidden = false;
      }, { once: true });

      imagen.src = ruta;
      item.appendChild(imagen);
    } else {
      fallback.hidden = false;
    }

    item.append(fallback, nombre);
    fragmento.appendChild(item);
  });

  especialidadesLista.appendChild(fragmento);
}

async function cargarEspecialidades(idUsuario, version) {
  try {
    // Supabase utiliza la clave foránea de la tabla intermedia
    // para relacionar cada asignación con su especialidad.
    const asignaciones = await consultarTodasLasFilas(() =>
      clienteSupabase
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

    if (!seleccionVigente(idUsuario, version)) return;

    const lista = asignaciones
      .map((asignacion) => asignacion.especialidad)
      .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));

    pintarEspecialidades(lista);

    especialidadesEstado.textContent = lista.length
      ? ''
      : 'Aún no hay especialidades obtenidas';
    especialidadesEstado.hidden = lista.length > 0;
  } catch (error) {
    console.error('Error al cargar especialidades desde Supabase:', error);

    if (!seleccionVigente(idUsuario, version)) return;

    especialidadesLista.replaceChildren();
    especialidadesEstado.textContent =
      'No se pudieron cargar las especialidades. Vuelve a seleccionar al usuario para reintentar.';
    especialidadesEstado.hidden = false;
  }
}

function mostrarTarjeta(idUsuario) {
  // Descarta respuestas de selecciones anteriores.
  const version = ++seleccionVersion;

  especialidadesLista.replaceChildren();
  especialidadesSeccion.hidden = true;
  dashboard.hidden = true;

  const usuario = usuarios.find((u) => u.id_usuario === idUsuario);

  if (!usuario) {
    tarjeta.hidden = true;
    return;
  }

  tarjetaNombre.textContent = `${usuario.nombres} ${usuario.apellido}`;
  tarjetaRol.textContent = capitalizar(usuario.rol);
  tarjetaUnidad.textContent = usuario.unidad || 'Sin asignar';
  tarjetaClase.textContent = usuario.clase || 'Sin asignar';
  tarjeta.hidden = false;

  especialidadesSeccion.hidden = false;
  especialidadesEstado.textContent = 'Cargando especialidades…';
  especialidadesEstado.hidden = false;

  cargarProgreso(idUsuario, version);
  cargarEspecialidades(idUsuario, version);
}

selector.addEventListener('change', (evento) => {
  mostrarTarjeta(evento.target.value);
});

cargarUsuarios();