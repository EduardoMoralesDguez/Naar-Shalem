import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import WebSocket from 'ws';
import assert from 'node:assert/strict';
const root=new URL('../frontend/',import.meta.url).pathname;
const output=fs.mkdtempSync('/tmp/naar-ui-');
const setup=`
window.fixture={actor:null,listener:null,progress:[],saves:0,
 users:[{id_usuario:'d0000000-0000-4000-8000-000000000004',nombres:'Ezequiel Eduardo',apellido:'Morales Dominguez',rol:'directiva',unidad:'Jaspe',clase:null,es_activo:true,version_perfil:1},
{id_usuario:'d0000000-0000-4000-8000-000000000003',nombres:'Ana',apellido:'Pérez',rol:'conquistador',unidad:'Diamante',clase:'Compañero',es_activo:true,version_perfil:1}]};
window.fixture.emit=function(n){this.actor=n;this.listener('SIGNED_IN',{access_token:'token-'+n,user:{id:'auth-'+n}})};
window.fixture.storage=new Map();
`;
const lib=`export function obtenerSupabase(){return {auth:{onAuthStateChange(cb){window.fixture.listener=cb;cb('INITIAL_SESSION',null)},async getSession(){return {data:{session:{access_token:'token-'+window.fixture.actor,user:{id:'auth-'+window.fixture.actor}}}}}},storage:{from(){return {
async upload(path,blob){window.fixture.storage.set(path,URL.createObjectURL(blob));return {error:null}},
async createSignedUrls(paths){return {data:paths.map(path=>({path,signedUrl:window.fixture.storage.get(path)}))}},
async remove(paths){for(const p of paths)if(!window.fixture.users.some(u=>u.foto_path===p))window.fixture.storage.delete(p);return {error:null}}
}}}}}`;
const auth=`export async function iniciarSesion(){window.fixture.emit(0)}
export async function cerrarSesion(){window.fixture.actor=null;window.fixture.listener('SIGNED_OUT',null)}
export async function obtenerMiPerfil(){return {...window.fixture.users[window.fixture.actor]}}`;
const catalogo=`import {firmarFotos} from './fotos.js';
export async function obtenerUsuarios(){const f=window.fixture;return firmarFotos(f.users.filter(u=>f.actor===0||u.es_activo).map(u=>({...u,color_clase:'#13854a',es_directiva:u.rol==='directiva',rol:f.actor===0||u===f.users[f.actor]?u.rol:null})));}
export async function obtenerProgreso(id,cobraCuotas){window.fixture.progress.push({id,cobraCuotas});return {asistencia:{porcentaje:50,asistencias:2,justificados:0,total_registros:4},cuotas:{porcentaje:50,semanas_pagadas:2,semanas_registradas:4,total_pagado:20}};}
export async function obtenerEspecialidades(){return []}`;
const admin=`export async function obtenerOpcionesIntegrante(){return {unidades:[{id_unidad:'u',nombre:'Jaspe'}],clases:[{id_clase:'c',nombre:'Amigo'}],ciclos:[{anio:2026}]}}
export async function obtenerIntegranteEditable(id){return {...window.fixture.users.find(u=>u.id_usuario===id)}}
export async function guardarIntegrante(u){window.fixture.saves++;const i=window.fixture.users.findIndex(x=>x.id_usuario===u.id_usuario);const val={...u,es_activo:true,version_perfil:(u.version_perfil||0)+1};if(i>=0)window.fixture.users[i]=val;else window.fixture.users.push(val);return u.id_usuario}
export async function cambiarEstado(u,a){const t=window.fixture.users.find(x=>x.id_usuario===u.id_usuario);t.es_activo=a;t.version_perfil++}`;
const attendance=`
const f=window.fixture;
f.users[0].unidad=null;
f.users.push({id_usuario:'d0000000-0000-4000-8000-000000000002',nombres:'Daniel',apellido:'Torres',rol:'capitan',unidad:'Jaspe',es_activo:true},
{id_usuario:'d0000000-0000-4000-8000-000000000001',nombres:'Laura',apellido:'Mendoza',rol:'consejero',unidad:'Jaspe',es_activo:true},{id_usuario:'d0000000-0000-4000-8000-000000000005',nombres:'Otro',apellido:'Integrante',rol:'conquistador',unidad:null,es_activo:true});
const parts=new Intl.DateTimeFormat('en',{timeZone:'America/Mexico_City',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const today=['year','month','day'].map(t=>parts.find(p=>p.type===t).value).join('-');
f.meeting={id:'meeting-1',nombre:'General',numero:1,fecha:today,hoy:today,estado:'borrador',version:1,importada:false,
 grupos:[{clave:'Diamante',nombre:'Diamante',revisada:false},{clave:'Jaspe',nombre:'Jaspe',revisada:false},{clave:'sin-unidad',nombre:'Sin unidad',revisada:false}],
 integrantes:f.users.filter(u=>u.rol!=='directiva').map(u=>({id_usuario:u.id_usuario,nombre:u.nombres+' '+u.apellido,clave:u.unidad||'sin-unidad',estado:'falta',motivo:null}))};
f.meetings=[f.meeting];
export async function listarReuniones(){return [{id:'future',fecha:'2099-01-01',nombre:'Futuro',numero:1,estado:'borrador'},...f.meetings.slice().reverse().map(m=>({id:m.id,fecha:m.fecha,nombre:m.nombre,numero:m.numero,estado:m.estado})),{id:'older',fecha:'2020-01-01',nombre:'General',numero:1,estado:'cerrada'}];}
export async function crearReunion(fecha,nombre){const previo=f.meetings.find(m=>m.nombre.toLowerCase()===nombre.trim().toLowerCase());if(previo)return previo.id;const m=structuredClone(f.meeting);m.id='meeting-'+(f.meetings.length+1);m.nombre=nombre.trim();m.numero=f.meetings.length+1;m.estado='borrador';m.grupos.forEach(g=>g.revisada=false);m.integrantes.forEach(u=>u.estado='falta');f.meetings.push(m);return m.id;}
export async function obtenerReunion(id=f.meeting.id){const actor=f.users[f.actor];const p=structuredClone(f.meetings.find(m=>m.id===id)||{...f.meeting,id,fecha:id==='future'?'2099-01-01':'2020-01-01',estado:id==='future'?'borrador':'cerrada'});p.rol=actor.rol;p.clave_actor=actor.unidad||'sin-unidad';p.puede_justificar=actor.rol==='capitan';if(actor.rol!=='directiva'){p.integrantes=p.integrantes.filter(u=>['capitan','consejero'].includes(actor.rol)?u.clave===actor.unidad:u.id_usuario===actor.id_usuario);p.grupos=p.grupos.filter(g=>p.integrantes.some(u=>u.clave===g.clave));}p.integrantes.forEach(u=>u.puede_justificar=p.puede_justificar);return p;}
export async function actuarReunion(p,accion,datos){const m=f.meetings.find(m=>m.id===p.id);if(f.conflict){f.conflict=false;throw {code:'40001'};}
 if(accion==='unidad'){for(const x of datos.integrantes)Object.assign(m.integrantes.find(u=>u.id_usuario===x.id_usuario),x);m.grupos.find(g=>g.clave===datos.clave).revisada=true;}
 if(accion==='celda')Object.assign(m.integrantes.find(u=>u.id_usuario===datos.id_usuario),{estado:datos.estado});
 if(accion==='cerrar')m.estado='cerrada';
 if(accion==='justificar')Object.assign(m.integrantes.find(u=>u.id_usuario===datos.id_usuario),{estado:'justificado',motivo:datos.motivo});
 if(accion==='anular')m.estado='anulada';
 if(accion==='restaurar'){m.estado='borrador';m.grupos.forEach(g=>g.revisada=false);}
 m.version++;
}
export async function obtenerListaAsistencias(){const a=f.users[f.actor];return f.users.filter(u=>a.rol==='directiva'||u.id_usuario===a.id_usuario||(['capitan','consejero'].includes(a.rol)&&u.unidad===a.unidad));}
export async function obtenerMatriz(){const registros=[];for(const m of f.meetings){if(m.estado!=='cerrada')continue;const p=await obtenerReunion(m.id);for(const u of p.integrantes)registros.push({reunion:p.id,fecha:p.fecha,version:p.version,id_usuario:u.id_usuario,nombre:u.nombre,unidad_clave:u.clave,unidad:u.clave==='sin-unidad'?'Sin unidad':u.clave,estado:u.estado,nombre_pase:p.nombre,numero:p.numero});}const p=await obtenerReunion();return [...p.integrantes.map(u=>({reunion:'older',fecha:'2020-01-01',version:1,id_usuario:u.id_usuario,nombre:u.nombre,unidad_clave:u.clave,unidad:u.clave==='sin-unidad'?'Sin unidad':u.clave,estado:'falta',nombre_pase:'General',numero:1})),...registros];}
export async function obtenerHistorialAsistencias(id){return f.meeting.estado==='cerrada'?f.meeting.integrantes.filter(u=>u.id_usuario===id).map(u=>({...u,fecha:f.meeting.fecha})):[];}

export async function obtenerContextoAsistencias(){return {epoca:'test-epoca',ciclo:'test-ciclo'};}
export async function verificarAsistenciaCuenta(id){if(!navigator.onLine)throw new Error('Offline');if(id!=='auth-'+f.actor)throw new Error('Cuenta incorrecta');}
export async function obtenerBitacoraAsistencias(){return [];}
export async function enviarAsistencia(o){if(!navigator.onLine)throw new Error('Offline');f.ops ||= [];if(f.ops.includes(o.id))return;await actuarReunion({id:o.reunion,version:o.version},o.accion,o.datos);f.ops.push(o.id);if(f.respuestaPerdida){f.respuestaPerdida=false;throw new Error('Respuesta perdida');}}
`;
const competencia=`
const f=window.fixture;
const criterios=['Biblia','Puntualidad','Versículo','Cuadernillo','Limpieza','Asistencia','Cuota'].map((nombre,i)=>({id:'k'+i,nombre,valor:5,activo:true,fuente:i<5?'manual':i===5?'asistencia':'cuota'}));
function init(){if(f.cp)return;f.cp={admin:true,id_ciclo:'ciclo',anio:2026,hoy:'2026-10-16',desde:'2026-10-01',hasta:'2026-10-16',version_config:1,justificados:true,criterios,unidades:[{id:'u',nombre:'Diamante'}],reuniones:[{id:'meeting-1',nombre:'Reunión regular',fecha:'2026-10-16',hora:'09:00',guardada:false}],periodos:[],cortes:[],bitacora:[],estadisticas:[{criterio:'Biblia',integrantes:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez',puntos:5}]}],estadisticas_consejeros:[{criterio:'Puntualidad',integrantes:[{id_usuario:f.users[3].id_usuario,nombre:'Laura Mendoza',puntos:5}]}],resultados:{unidades:[{id_unidad:'u',nombre:'Diamante',puntos:40}],individual:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez',puntos:20}],destacados:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez'}]},anual:{unidades:[{id_unidad:'u',nombre:'Diamante',puntos:40}],individual:[]}};
f.captura={id:'meeting-1',nombre:'Reunión regular',fecha:'2026-10-16',version:0,version_reunion:1,version_config:1,cerrada:false,criterios:structuredClone(criterios),integrantes:f.users.filter(u=>u.rol!=='directiva').map(u=>({id_usuario:u.id_usuario,nombre:u.nombres+' '+u.apellido,id_unidad:u.unidad,unidad:u.unidad||'Sin unidad',rol:u.rol,asistencia:null,cobra:u.rol!=='consejero',cumplidos:[],automaticos:[]})),extras:[]};}
export async function obtenerCompetencia(reunion=null,desde=null,hasta=null){init();const p=structuredClone(f.cp);p.admin=f.actor===0;p.desde=desde||p.desde;p.hasta=hasta||p.hasta;p.captura=reunion?structuredClone(f.captura):null;p.historial_puntos=f.captura.integrantes.map(u=>({...u,reunion:'meeting-1',fecha:'2026-10-16',reunion_nombre:'Regular',puntos:5}));if(p.captura)p.captura.version_reunion=f.meeting.version;
if(!p.admin){p.criterios=[];p.resultados.individual=[];p.anual=null;if(p.captura){p.captura.cerrada=true;p.captura.solo_lectura=true;p.captura.integrantes=p.captura.integrantes.filter(u=>u.id_unidad===f.users[f.actor].unidad);}}
p.publicacion=f.cp.cortes.length||p.ciclo_finalizado?{nombre:p.ciclo_finalizado?'Ciclo 2026':'Octubre',desde:p.desde,hasta:p.hasta,anual:!!p.ciclo_finalizado,publicado_hasta:f.publicacionHasta||new Date(Date.now()+86400000).toISOString()}:null;
if(p.publicacion)p.publicados={unidades:p.resultados.unidades,top_ordenado:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez',puntos:20}],consejeros:[{id_usuario:f.users[3].id_usuario,nombre:'Laura Mendoza',puntos:15}]};return p;}
export async function guardarCompetencia(id,accion,datos){f.intentos ||= [];f.intentos.push({id,accion,datos});if(f.fallar){f.fallar=false;throw new Error('Sin confirmación');}if(f.actor!==0)throw new Error('Solo directiva');f.ultimaOperacion={id,accion,datos};if(accion==='captura'&&datos.version_reunion!==f.meeting.version)throw {code:'40001',message:'Cambió el pase'};if(accion==='captura'){f.captura.version++;for(const u of f.captura.integrantes)u.cumplidos=datos.integrantes.find(i=>i.id_usuario===u.id_usuario).cumplidos;f.captura.extras=datos.extras;f.cp.reuniones[0].guardada=true;}if(accion==='criterios'){for(const k of datos.criterios){let v=f.cp.criterios.find(c=>c.id===k.id);if(v)Object.assign(v,k);else f.cp.criterios.push({...k,id:'nuevo',fuente:'manual'});}f.cp.version_config++;}if(accion==='finalizar_ciclo'){f.cp.ciclo_finalizado=true;f.captura.cerrada=true;}if(accion==='reabrir_ciclo'){f.cp.ciclo_finalizado=false;f.captura.cerrada=false;f.cp.cortes=[];}if(accion==='reabrir_corte'){f.cp.cortes=[];f.cp.periodos[0].corte=null;f.captura.cerrada=false;}if(accion==='periodo')f.cp.periodos.push({...datos,id:'periodo',corte:null});if(accion==='finalizar'){f.cp.periodos[0].corte='corte';f.cp.cortes.push({...f.cp.periodos[0],id:'corte'});f.captura.cerrada=true;}}
`;
const mocks={'/js/services/cuotas.js':`export async function verificarCuenta(id){if(id!=='auth-'+window.fixture.actor)throw new Error('Cuenta incorrecta');}export async function enviarCuota(){}export async function obtenerCuotas(){return {epoca:'epoca',id_ciclo:'ciclo',periodos:[],cargos:[],integrantes:[],ingresos:[],aplicaciones:[],bitacora:[]};}`, '/js/services/competencia.js':competencia+`export async function obtenerPublicacion(){return window.fixture.cp?.cortes.length?{nombre:'Octubre',publicado_hasta:new Date(Date.now()+86400000).toISOString()}:null;}export async function obtenerPuntajeUnidad(){return null;}export async function obtenerPuntajePerfil(){return {nombre:'Octubre',desde:'2026-10-01',hasta:'2026-10-16',puntos:20};}`,'/js/services/asistencias.js':attendance,'/js/lib/supabase.js':lib,'/js/services/auth.js':auth,'/js/services/catalogo.js':catalogo,'/js/services/integrantes-admin.js':admin};
const server=http.createServer((req,res)=>{
 let url=new URL(req.url,'http://localhost').pathname;
 if(url==='/sw.js'){res.statusCode=404;return res.end();}
 if(mocks[url]){res.setHeader('Content-Type','text/javascript');return res.end(mocks[url]);}
 const p=path.join(root,url==='/'?'index.html':url);
 if(!p.startsWith(root)||!fs.existsSync(p)){res.statusCode=404;return res.end('missing');}
 let data=fs.readFileSync(p);if(p.endsWith('.html'))data=data.toString().replace(/<script src="[^"]*supabase[^>]+><\/script>/,'<script>'+setup+'</script>');
 res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.css')?'text/css':p.endsWith('.js')?'text/javascript':'image/png');res.end(data);
});
await new Promise(r=>server.listen(8100,'127.0.0.1',r));
const chrome=spawn(process.env.CHROMIUM_PATH||'/usr/bin/chromium',['--headless','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=9240','--user-data-dir='+fs.mkdtempSync('/tmp/naar-competencia-chrome-'),'about:blank'],{stdio:'ignore'});
let pages;
for(let i=0;i<100;i++){try{pages=await (await fetch('http://127.0.0.1:9240/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
const ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.on('open',r));let seq=0;const jobs=new Map();
ws.on('message',raw=>{const m=JSON.parse(raw);if(m.id){const j=jobs.get(m.id);jobs.delete(m.id);m.error?j.reject(m.error):j.resolve(m.result)}else if(m.method==='Page.javascriptDialogOpening')void send('Page.handleJavaScriptDialog',{accept:true,promptText:'Motivo de prueba'})});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;jobs.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))})}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function waitFor(expr){for(let i=0;i<100;i++){if(await evaluate(expr))return;await new Promise(r=>setTimeout(r,40));}throw new Error('Timeout: '+expr)}
async function shot(name){await new Promise(r=>setTimeout(r,220));const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try{
await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8100/'});await waitFor("document.getElementById('panelLogin')&&!document.getElementById('panelLogin').hidden");
await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
assert.equal(await evaluate("document.querySelectorAll('#inicio a[href=\"#cuotas\"]').length"),0);
assert.ok(await evaluate("document.querySelector('#inicio a[href=\"#competencia\"]').textContent.includes('Puntos, clasificación, cuotas')"));
await evaluate("location.hash='competencia/puntaje'");await waitFor("document.getElementById('cpGuardar')&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('.cp-menu .cp-tarjeta').length>=5"),true);
assert.equal(await evaluate("document.querySelectorAll('[data-cp-sub]').length"),0);
assert.equal(await evaluate("document.getElementById('cpExtraForm').hidden"),false);
await evaluate("document.getElementById('cpActualizar').click()");await waitFor("!document.getElementById('cpCampos').disabled&&document.getElementById('cpConexion').textContent.includes('Actualizado')");
await evaluate("Object.defineProperty(navigator,'onLine',{configurable:true,get:()=>false});document.querySelector('.cp-matriz input').click();document.getElementById('cpGuardar').click()");await waitFor("document.getElementById('cpConexion').textContent.includes('1 pendientes')&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("fixture.captura.version"),0);
await evaluate("Object.defineProperty(navigator,'onLine',{configurable:true,get:()=>true});document.getElementById('cpActualizar').click()");await waitFor("fixture.captura.version===1&&!document.getElementById('cpCampos').disabled");
assert.ok(await evaluate("document.querySelector('#cpMatriz tfoot').textContent.includes('5')"));
// Un fallo de conexión conserva el mismo UUID y una sola captura pendiente.
await evaluate("fixture.fallar=true;document.querySelector('.cp-matriz input').click();document.getElementById('cpGuardar').click()");await waitFor("document.getElementById('cpConexion').textContent.includes('1 pendientes')&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("fixture.captura.version"),1);
await evaluate("document.getElementById('cpActualizar').click()");await waitFor("fixture.captura.version===2&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("fixture.intentos.at(-1).id===fixture.intentos.at(-2).id"),true);
// Un pase modificado por otra persona exige revisar, sin perder el intento local.
await evaluate("Object.defineProperty(navigator,'onLine',{configurable:true,get:()=>false});document.querySelector('.cp-matriz input').click();document.getElementById('cpGuardar').click()");await waitFor("document.getElementById('cpConexion').textContent.includes('1 pendientes')&&!document.getElementById('cpCampos').disabled");
await evaluate("fixture.meeting.version++;Object.defineProperty(navigator,'onLine',{configurable:true,get:()=>true});document.getElementById('cpActualizar').click()");await waitFor("document.getElementById('cpPendientes').textContent.includes('Cambió el pase')&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("fixture.captura.version"),2);
await evaluate("document.querySelector('#cpPendientes button').click()");await waitFor("document.getElementById('cpPendientes').hidden&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpPorReunion').click()");assert.equal(await evaluate("document.getElementById('cpHistorialPuntos').hidden"),false);assert.ok(await evaluate("document.querySelector('#cpHistorialPuntos tfoot')!==null"));await shot('puntos-por-reunion');
await evaluate("document.getElementById('cpPorCriterio').click()");await shot('puntos-criterios-extras');
await evaluate("location.hash='asistencias'");await waitFor("!document.getElementById('vistaAsistencias').hidden&&!document.getElementById('asCampos').disabled");assert.equal(await evaluate("document.querySelectorAll('#vistaAsistencias .cp-menu .cp-tarjeta').length"),5);
await evaluate("location.hash='cuotas'");await waitFor("!document.getElementById('vistaCuotas').hidden&&!document.getElementById('cuSync').disabled&&document.getElementById('cuEstado').textContent.includes('Todos los movimientos')");assert.equal(await evaluate("document.querySelectorAll('#vistaCuotas .cp-menu .cp-tarjeta').length"),5);
await evaluate("location.hash='consultar'");await waitFor("!document.getElementById('directorio').hidden");assert.equal(await evaluate("getComputedStyle(document.querySelector('.integrante-avatar')).color"),'rgb(255, 255, 255)');
assert.equal(await evaluate("getComputedStyle(document.querySelector('a[href=\"#perfil/'+fixture.users[0].id_usuario+'\"] .integrante-nombre')).color"),'rgb(17, 17, 17)');
await evaluate("location.hash='competencia/cortes'");await waitFor("!document.getElementById('cpCortes').hidden&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpTipoCorte').value='personalizado';document.getElementById('cpTipoCorte').dispatchEvent(new Event('change'));document.getElementById('cpCorteHasta').value='2026-10-16';document.getElementById('cpCortar').requestSubmit()");await waitFor("fixture.cp.periodos.length===1&&!document.getElementById('cpCampos').disabled");
await evaluate("[...document.querySelectorAll('#cpCortesLista button')].find(b=>b.textContent==='Finalizar').click()");await waitFor("fixture.cp.cortes.length===1&&!document.getElementById('cpCampos').disabled");
await evaluate("[...document.querySelectorAll('#cpCortesLista button')].find(b=>b.textContent==='Reabrir').click()");await waitFor("fixture.cp.cortes.length===0&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpFinalizarCiclo').click()");await waitFor("fixture.cp.ciclo_finalizado&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpFinalizarCiclo').click()");await waitFor("!fixture.cp.ciclo_finalizado&&!document.getElementById('cpCampos').disabled");
await evaluate("location.hash='competencia/puntaje'");await waitFor("!document.getElementById('cpCampos').disabled&&!!document.getElementById('cpGuardar')");
await evaluate('fixture.emit(2)');await waitFor("!document.getElementById('cpCampos').disabled&&document.getElementById('cpGuardar')===null&&document.querySelector('.cp-matriz')");
assert.equal(await evaluate("document.querySelectorAll('.cp-matriz tbody tr').length"),2);assert.equal(await evaluate("[...document.querySelectorAll('.cp-matriz input')].every(e=>e.disabled)"),true);
assert.equal(await evaluate("document.querySelector('[data-cp-tab=admin]').hidden"),true);
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('lectura-unidad-mobile');assert.equal(await evaluate('document.documentElement.scrollWidth<=innerWidth'),true);
await evaluate("location.hash='competencia/resultados'");await waitFor("!document.getElementById('cpCampos').disabled&&!document.getElementById('cpResultados').hidden");assert.equal(await evaluate("document.querySelector('.cp-destacado strong').textContent"),'Ana Pérez');
await shot('top-permanente-mobile');assert.equal(await evaluate('document.documentElement.scrollWidth<=innerWidth'),true);
console.log('Competencia UI OK: navegación uniforme, preparación conjunta, captura offline, sincronización, lectura por unidad, totales, reaperturas y Top permanente. Capturas: '+output);
}catch(e){console.error(await evaluate('document.body.innerText'));await shot('error');console.error(output);throw e;}finally{ws.close();chrome.kill();server.close();}
