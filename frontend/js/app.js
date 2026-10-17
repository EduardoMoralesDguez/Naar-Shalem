import {obtenerPuntajePerfil,obtenerPublicacion} from './services/competencia.js';
import {abrirCompetencia,reiniciarCompetencia,puedeSalirCompetencia} from './modules/competencia.js';
import {pendientesAsistencias} from './services/asistencias-offline.js';
import {configurarColores} from './lib/colores.js';
import { abrirOrganizacion, reiniciarOrganizacion, puedeSalirOrganizacion } from './modules/organizacion.js';
// frontend/js/app.js
import { abrirCalendario, reiniciarCalendario, puedeSalirCalendario } from './modules/calendario.js';
import { SUPABASE_URL } from './config.js';
import { abrirCuotas, reiniciarCuotas, puedeSalirCuotas, pendientesCuotas } from './modules/cuotas.js';
import { localCuotas, recordarCuenta, olvidarCuenta, cuentaRecordada } from './lib/cuotas-local.js';
import { obtenerSupabase } from './lib/supabase.js';

import {
  iniciarSesion,
  cerrarSesion,
  obtenerMiPerfil,
} from './services/auth.js';

import { obtenerUsuarios } from './services/catalogo.js';

import {
  obtenerIntegranteEditable,
  cambiarEstado,
} from './services/integrantes-admin.js';

import {
  mostrarUsuarios,
  mostrarPerfil,
  mostrarFoto,
  limpiarUsuarios,
  nombreRol,
} from './modules/usuarios.js';

import {
  abrirEditor,
  reiniciarEditor,
  puedeSalir,
} from './modules/integrantes-admin.js';

import {
  reiniciarProgreso,
  cargarProgreso,
} from './modules/progreso.js';

import {
  reiniciarEspecialidades,
  cargarEspecialidades,
} from './modules/especialidades.js';

import {
  abrirAsistencias,
  reiniciarAsistencias,
  puedeSalirAsistencias,
} from './modules/asistencias.js';

const $ = id => document.getElementById(id);

const vistas = [
  'inicio',
  'menuIntegrantes',
  'directorio',
  'vistaPerfil',
  'editor',
  'vistaAsistencias',
  'vistaCuotas',
  'vistaCalendario',
  'vistaOrganizacion',
  'vistaCompetencia',
];

let perfil = null;
let usuarios = [];
let sesion = null;
let authRevision = 0;
let vistaRevision = 0;
let rutaActual = '';
let token;
let temporizador;
let cerrando = false;
let cambiandoEstado = false;

const admin = () => perfil?.rol === 'directiva';

function aviso(texto) {
  $('avisoGlobal').textContent = texto;
  $('avisoGlobal').hidden = !texto;
}

function ocultarVistas() {
  vistas.forEach(id => $(id).hidden = true);
  reiniciarProgreso();
  reiniciarEspecialidades();
}

function limpiar() {
  authRevision += 1;
  vistaRevision += 1;
  perfil = null;
  usuarios = [];
  rutaActual = '';

  reiniciarAsistencias();
  reiniciarCuotas();
  reiniciarCalendario();
  reiniciarOrganizacion();
  reiniciarCompetencia();
  reiniciarEditor();
  limpiarUsuarios();
  ocultarVistas();
  aviso('');

  $('aplicacion').hidden = true;
  $('barraSesion').hidden = true;
  $('sesionNombre').textContent = '';
  $('sesionRol').textContent = '';
  $('sesionAvatar').replaceChildren();
}

function estado(texto, reintentar = false) {
  $('panelLogin').hidden = true;
  $('panelEstadoAcceso').hidden = false;
  $('estadoAcceso').textContent = texto;
  $('reintentarAcceso').hidden = !reintentar;
}

function cuenta() {
  configurarColores(usuarios);
  if(navigator.onLine&&sesion?.user.id) void localCuotas(sesion.user.id,d=>{d.colores=usuarios.map(u=>({id_usuario:u.id_usuario,color_clase:u.color_clase,clase:u.clase,unidad:u.unidad,es_directiva:u.es_directiva,rol:u.rol}));});
  const usuario = usuarios.find(
    integrante => integrante.id_usuario === perfil.id_usuario
  ) || perfil;

  $('sesionNombre').textContent =
    `${usuario.nombres} ${usuario.apellido}`;

  $('sesionRol').textContent = nombreRol(perfil.rol);
  $('saludoNombre').textContent = usuario.nombres;
  $('miPerfil').href = `#perfil/${perfil.id_usuario}`;

  mostrarFoto($('sesionAvatar'), usuario);
}

async function renderRuta(forzar = false) {
  if (!perfil || cerrando) return;

  let ruta = location.hash.slice(1) || 'inicio';

  if (
    !forzar &&
    (
      cambiandoEstado ||
      !puedeSalir() ||
      !puedeSalirAsistencias() ||
      !puedeSalirCuotas() || !puedeSalirCalendario() || !puedeSalirOrganizacion() || !puedeSalirCompetencia()
    )
  ) {
    history.replaceState(null, '', `#${rutaActual || 'inicio'}`);
    return;
  }

  if (
    !admin() &&
    (/^(registrar|editar\/)/.test(ruta) || ruta === 'integrantes')
  ) {
    ruta = 'consultar';
  }

  if (
    !/^(inicio|competencia(?:\/(?:puntaje|resultados|admin|criterios|cortes|estadisticas|bitacora))?|organizacion|calendario|cuotas|asistencias(?:\/[0-9a-f-]{36})?|integrantes|consultar|registrar|perfil\/[0-9a-f-]{36}|editar\/[0-9a-f-]{36})$/.test(ruta)
  ) {
    ruta = 'inicio';
  }

  if (!navigator.onLine && ruta !== 'cuotas' && !ruta.startsWith('competencia') && !ruta.startsWith('asistencias') && ruta !== 'inicio') ruta = 'inicio';
  history.replaceState(null, '', `#${ruta}`);
  rutaActual = ruta;

  const actual = ++vistaRevision;

  reiniciarAsistencias();
  reiniciarCuotas();
  reiniciarCalendario();
  reiniciarOrganizacion();
  reiniciarCompetencia();
  reiniciarEditor();
  ocultarVistas();
  aviso('');

  $('subtituloPagina').textContent = '';

  const enlaceModulo = document.querySelector(
    '.ruta a:nth-of-type(2)'
  );

  enlaceModulo.href =
    ruta.startsWith('competencia') ? '#competencia' : ruta === 'organizacion' ? '#organizacion' : ruta === 'calendario' ? '#calendario' : ruta === 'cuotas' ? '#cuotas' : ruta.startsWith('asistencias') ? '#asistencias' : '#integrantes';

  enlaceModulo.textContent =
    ruta.startsWith('competencia') ? 'Competencia' : ruta === 'organizacion' ? 'Organización' : ruta === 'calendario' ? 'Calendario' : ruta === 'cuotas' ? 'Cuotas' : ruta.startsWith('asistencias') ? 'Asistencias' : 'Integrantes';

  try {
    if (ruta === 'inicio') {
      void cargarAnuncioCompetencia(actual);
      $('inicio').hidden = false;
    } else if (ruta.startsWith('competencia')) {
      $('vistaCompetencia').hidden = false;
      await abrirCompetencia(perfil,ruta.split('/')[1]);
    } else if (ruta === 'organizacion') {
      $('vistaOrganizacion').hidden = false;
      await abrirOrganizacion(perfil, async () => { const rev = authRevision; const lista = await obtenerUsuarios(); if (rev !== authRevision) return; usuarios = lista; cuenta(); }, async () => {
        if ((await pendientesCuotas(sesion.user.id))+(await pendientesAsistencias(sesion.user.id))) throw new Error('Sincroniza o resuelve tus cuotas y asistencias pendientes antes de iniciar otro ciclo.');
      });
    } else if (ruta === 'cuotas') {
      $('vistaCuotas').hidden = false;
      await abrirCuotas(perfil, sesion.user.id);
    } else if (ruta === 'calendario') {
      $('vistaCalendario').hidden = false;
      await abrirCalendario(perfil);
    } else if (ruta.startsWith('asistencias')) {
      $('vistaAsistencias').hidden = false;
      await abrirAsistencias(perfil, ruta.split('/')[1],sesion.user.id);
    } else if (ruta === 'integrantes') {
      $('menuIntegrantes').hidden = false;
    } else if (ruta === 'registrar' || ruta.startsWith('editar/')) {
      $('editor').hidden = false;

      $('subtituloPagina').textContent =
        ruta === 'registrar' ? ' / Registrar' : ' / Editar';

      await abrirEditor(ruta.split('/')[1] || null, async id => {
        const revision = authRevision;
        const lista = await obtenerUsuarios();

        if (revision !== authRevision) return;

        usuarios = lista;
        cuenta();
        location.hash = `perfil/${id}`;
      });
    } else {
      aviso('Cargando integrantes…');

      const lista = await obtenerUsuarios();

      if (actual !== vistaRevision || !perfil) return;

      usuarios = lista;
      cuenta();
      aviso('');

      if (ruta === 'consultar') {
        mostrarUsuarios(usuarios, admin());
        $('directorio').hidden = false;
        $('subtituloPagina').textContent = ' / Consultar';
      } else {
        const id = ruta.split('/')[1];

        const usuario = usuarios.find(
          integrante => integrante.id_usuario === id
        );

        if (!usuario) {
          throw new Error(
            'Este perfil no está disponible para tu cuenta.'
          );
        }

        mostrarPerfil(usuario);
        $('perfilPuntaje').hidden=true;
        $('perfilPuntaje').replaceChildren();
        $('vistaPerfil').hidden = false;

        $('editarPerfil').hidden = !admin() || !usuario.es_activo;
        $('editarPerfil').href = `#editar/${id}`;

        $('estadoPerfil').hidden =
          !admin() || id === perfil.id_usuario;

        $('estadoPerfil').textContent = usuario.es_activo
          ? 'Desactivar integrante'
          : 'Reactivar integrante';

        $('subtituloPagina').textContent =
          id === perfil.id_usuario ? ' / Mi perfil' : ' / Perfil';

        const vigente = () =>
          actual === vistaRevision && Boolean(perfil);

        // El dashboard incluye cuotas y conserva sus permisos.
        // Al abrir el perfil consulta nuevamente los registros guardados.
        if ((admin() || id === perfil.id_usuario) && !usuario.es_directiva && usuario.rol !== 'directiva') {
          void obtenerPuntajePerfil(id).then(p=>{if(!vigente()||!p)return;const titulo=document.createElement('h3');titulo.textContent=p.nombre;const valor=document.createElement('strong');valor.textContent=`${p.puntos} puntos`;const fechas=document.createElement('small');fechas.textContent=`${p.desde} · ${p.hasta}`;$('perfilPuntaje').replaceChildren(titulo,valor,fechas);$('perfilPuntaje').hidden=false;}).catch(()=>{if(vigente()){$('perfilPuntaje').textContent='No se pudo consultar el puntaje.';$('perfilPuntaje').hidden=false;}});
          void cargarProgreso(id, vigente, ['conquistador', 'capitan', 'subcapitan'].includes(usuario.rol));
        }

        void cargarEspecialidades(id, vigente);
      }
    }

    if (actual !== vistaRevision) return;

    window.scrollTo({ top: 0, behavior: 'instant' });
  } catch (error) {
    if (actual !== vistaRevision) return;

    console.error(error);

    aviso(
      error.message ||
      'No se pudo cargar la pantalla. Vuelve a intentarlo desde Inicio.'
    );
  }
}

async function aplicarSesion(nueva, forzar = false) {
  if (cerrando && nueva) return;

  if (!forzar && token === (nueva?.access_token || null)) {
    return;
  }

  token = nueva?.access_token || null;
  sesion = nueva;
  limpiar();

  const actual = authRevision;

  if (!sesion) {
    $('panelEstadoAcceso').hidden = true;
    $('panelLogin').hidden = false;
    return;
  }

  estado('Comprobando acceso…');

  try {
    const cache = !navigator.onLine ? await localCuotas(sesion.user.id) : null;
    if (cache && !cache.perfil) throw new Error('Abre la app con conexión antes de usar este dispositivo sin internet.');
    const propio = cache ? cache.perfil : await obtenerMiPerfil();
    const lista = cache ? [{...propio,color_clase:cache.colores?.find(u=>u.id_usuario===propio.id_usuario)?.color_clase}] : await obtenerUsuarios();
    if (actual !== authRevision) return;

    perfil = propio;
    if (navigator.onLine) {
      await localCuotas(sesion.user.id, d => { d.perfil = propio; d.colores=lista.map(u=>({id_usuario:u.id_usuario,color_clase:u.color_clase,clase:u.clase,unidad:u.unidad,es_directiva:u.es_directiva,rol:u.rol})); });
      if (actual !== authRevision) return;
      recordarCuenta(sesion.user.id);
    }
    usuarios = lista;
    cuenta();
    if(cache?.colores) configurarColores(cache.colores);

    $('panelEstadoAcceso').hidden = true;
    $('panelLogin').hidden = true;
    $('barraSesion').hidden = false;
    $('aplicacion').hidden = false;

    await renderRuta(true);
  } catch (error) {
    if (actual !== authRevision) return;

    console.error(error);
    limpiar();

    $('barraSesion').hidden = false;
    $('miPerfil').removeAttribute('href');

    estado(
      error.code === 'SIN_EXPEDIENTE'
        ? error.message
        : 'No se pudo comprobar el acceso. Revisa la conexión.',
      true
    );
  }
}

$('formLogin').addEventListener('submit', async evento => {
  evento.preventDefault();
  $('botonLogin').disabled = true;
  $('errorLogin').hidden = true;

  try {
    await iniciarSesion(
      $('loginCorreo').value.trim(),
      $('loginPassword').value
    );
  } catch (error) {
    $('errorLogin').textContent =
      error.code === 'invalid_credentials'
        ? 'Correo o contraseña incorrectos.'
        : 'No se pudo iniciar sesión. Revisa tus datos y la conexión.';

    $('errorLogin').hidden = false;
  } finally {
    $('loginPassword').value = '';
    $('botonLogin').disabled = false;
  }
});

$('verPassword').addEventListener('click', () => {
  const visible = $('loginPassword').type === 'password';

  $('loginPassword').type = visible ? 'text' : 'password';
  $('verPassword').textContent = visible ? 'Ocultar' : 'Mostrar';
  $('verPassword').setAttribute('aria-pressed', String(visible));
});

$('botonSalir').addEventListener('click', async () => {
  if (
    cerrando ||
    cambiandoEstado ||
    !puedeSalir() ||
    !puedeSalirAsistencias() ||
    !puedeSalirCuotas() || !puedeSalirCalendario() || !puedeSalirOrganizacion() || !puedeSalirCompetencia()
  ) {
    return;
  }

  const pendientes = (await pendientesCuotas(sesion?.user.id))+(await pendientesAsistencias(sesion?.user.id));
  if (pendientes && !confirm(`Hay ${pendientes} movimientos sin sincronizar. Quedarán guardados para esta cuenta; tendrás que volver a iniciar sesión para enviarlos. ¿Cerrar sesión?`)) return;
  olvidarCuenta();
  cerrando = true;
  clearTimeout(temporizador);
  limpiar();
  estado('Cerrando sesión…');
  $('botonSalir').disabled = true;

  try {
    if (navigator.onLine) await cerrarSesion();
    else {
      // Elimina la sesión local de Auth incluso cuando no hay servidor disponible.
      obtenerSupabase().auth.stopAutoRefresh();
      localStorage.removeItem(`sb-${new URL(SUPABASE_URL).hostname.split('.')[0]}-auth-token`);
      location.reload();
      return;
    }
    history.replaceState(null, '', '#inicio');
    await aplicarSesion(null, true);
  } catch {
    $('barraSesion').hidden = false;
    estado('No se pudo cerrar la sesión. Pulsa Salir para reintentar.');
  } finally {
    cerrando = false;
    $('botonSalir').disabled = false;
  }
});

$('reintentarAcceso').addEventListener('click', async () => {
  try {
    const { data, error } = await obtenerSupabase().auth.getSession();

    if (error) throw error;

    await aplicarSesion(data.session, true);
  } catch {
    estado('No se pudo recuperar la sesión. Revisa tu conexión.', true);
  }
});

$('estadoPerfil').addEventListener('click', async () => {
  if (!admin() || cambiandoEstado) return;

  const id = rutaActual.split('/')[1];

  const usuario = usuarios.find(
    integrante => integrante.id_usuario === id
  );

  if (!usuario) return;

  const texto = usuario.es_activo
    ? `¿Desactivar a ${usuario.nombres} ${usuario.apellido}? Conservará su historial, pero perderá el acceso al portal.`
    : `¿Reactivar a ${usuario.nombres} ${usuario.apellido}?`;

  if (!confirm(texto)) return;

  const actual = authRevision;
  cambiandoEstado = true;
  $('estadoPerfil').disabled = true;

  try {
    const vigente = await obtenerIntegranteEditable(id);

    if (actual !== authRevision) return;

    await cambiarEstado(vigente, !usuario.es_activo);

    if (actual !== authRevision) return;

    cambiandoEstado = false;
    await renderRuta(true);

    aviso(
      usuario.es_activo
        ? 'Integrante desactivado. Su historial se conserva.'
        : 'Integrante reactivado.'
    );
  } catch (error) {
    if (actual === authRevision) {
      aviso(error.message || 'No se pudo cambiar el estado.');
    }
  } finally {
    cambiandoEstado = false;
    $('estadoPerfil').disabled = false;
  }
});

window.addEventListener('hashchange', () => {
  void renderRuta();
});

try {
  obtenerSupabase().auth.onAuthStateChange((evento, nueva) => {
    clearTimeout(temporizador);

    temporizador = setTimeout(() => {
      // Renovar el token no borra un formulario en edición.
      if (
        evento === 'TOKEN_REFRESHED' &&
        !sesion?.access_token?.startsWith('offline-') &&
        perfil &&
        sesion?.user.id === nueva?.user.id
      ) {
        sesion = nueva;
        token = nueva.access_token;
        return;
      }

      if (!navigator.onLine) {
        const id = cuentaRecordada();
        if (!id) { void aplicarSesion(null, true); return; }
        void aplicarSesion({ user: { id }, access_token: 'offline-' + id });
      } else void aplicarSesion(nueva);
    }, 0);
  });
} catch (error) {
  limpiar();
  estado(error.message);
}
// Recuperación offline no depende de renovar el token contra la red.
if (!navigator.onLine && cuentaRecordada()) {
  const id = cuentaRecordada();
  void aplicarSesion({ user: { id }, access_token: 'offline-' + id });
}
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register(new URL('../sw.js', import.meta.url)).catch(console.error);
}
window.addEventListener('online', async () => {
  if (!sesion?.access_token?.startsWith('offline-')) return;
  const { data } = await obtenerSupabase().auth.getSession();
  await aplicarSesion(data.session, true);
});

const anuncioCompetencia=document.createElement('a');anuncioCompetencia.className='competencia-anuncio';anuncioCompetencia.href='#competencia/resultados';anuncioCompetencia.hidden=true;document.querySelector('#inicio .menu-grid').before(anuncioCompetencia);
let anuncioTimer;
async function cargarAnuncioCompetencia(actual){clearTimeout(anuncioTimer);anuncioCompetencia.hidden=true;try{const p=await obtenerPublicacion();if(actual!==vistaRevision||!perfil||!p)return;const restante=new Date(p.publicado_hasta)-Date.now();if(restante<=0)return;anuncioCompetencia.textContent=`${p.nombre} · Resultados publicados →`;anuncioCompetencia.hidden=false;anuncioTimer=setTimeout(()=>{anuncioCompetencia.hidden=true;},Math.min(restante,2147483647));}catch{/* El acceso al inicio no depende del aviso. */}}
