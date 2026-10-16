import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import WebSocket from 'ws';
import assert from 'node:assert/strict';
const root=new URL('../frontend/',import.meta.url).pathname;
const output=fs.mkdtempSync('/tmp/naar-ui-');
const setup=`
Object.defineProperty(navigator,'onLine',{get:()=>localStorage.getItem('offline')!=='1'});
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
export async function actuarReunion(p,accion,datos){const m=f.meetings.find(m=>m.id===p.id);if(f.conflict||m.version!==p.version){f.conflict=false;throw {code:'40001',message:'La reunión cambió. Actualiza.'};}
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
export async function verificarAsistenciaCuenta(id){if(f.redCaida)throw new Error('Sin acceso al servidor');if(!navigator.onLine)throw new Error('Offline');if(id!=='auth-'+f.actor)throw new Error('Cuenta incorrecta');}
export async function obtenerBitacoraAsistencias(){return [];}
export async function enviarAsistencia(o){if(!navigator.onLine)throw new Error('Offline');f.ops ||= [];if(f.ops.includes(o.id))return;await actuarReunion({id:o.reunion,version:o.version},o.accion,o.datos);f.ops.push(o.id);if(f.respuestaPerdida){f.respuestaPerdida=false;throw new Error('Respuesta perdida');}}
`;
const mocks={'/js/services/asistencias.js':attendance,'/js/lib/supabase.js':lib,'/js/services/auth.js':auth,'/js/services/catalogo.js':catalogo,'/js/services/integrantes-admin.js':admin};
let serverOffline=false;
const server=http.createServer((req,res)=>{
 let url=new URL(req.url,'http://localhost').pathname;
 if(serverOffline){res.destroy();return;}
 if(mocks[url]){res.setHeader('Content-Type','text/javascript');return res.end(mocks[url]);}
 const p=path.join(root,url==='/'?'index.html':url);
 if(!p.startsWith(root)||!fs.existsSync(p)){res.statusCode=404;return res.end('missing');}
 let data=fs.readFileSync(p);if(p.endsWith('.html'))data=data.toString().replace(/<script src="[^"]*supabase[^>]+><\/script>/,'<script>'+setup+'</script>');
 res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.css')?'text/css':p.endsWith('.js')?'text/javascript':'image/png');res.end(data);
});
await new Promise(r=>server.listen(8099,'127.0.0.1',r));
const chrome=spawn(process.env.CHROMIUM_PATH||'/usr/bin/chromium',['--headless','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=9239','--user-data-dir='+fs.mkdtempSync('/tmp/naar-offline-chrome-'),'about:blank'],{stdio:'ignore'});
let pages;
for(let i=0;i<100;i++){try{pages=await (await fetch('http://127.0.0.1:9239/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
const ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.on('open',r));let seq=0;const jobs=new Map();
ws.on('message',raw=>{const m=JSON.parse(raw);if(m.id){const j=jobs.get(m.id);jobs.delete(m.id);m.error?j.reject(m.error):j.resolve(m.result)}else if(m.method==='Page.javascriptDialogOpening')void send('Page.handleJavaScriptDialog',{accept:true,promptText:'Motivo de prueba'})});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;jobs.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))})}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,replMode:true,awaitPromise:true,returnByValue:true,userGesture:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function waitFor(expr){for(let i=0;i<100;i++){if(await evaluate(expr))return;await new Promise(r=>setTimeout(r,40));}throw new Error('Timeout: '+expr)}
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try{
await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:950,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8099/'});await waitFor("document.getElementById('panelLogin')&&!document.getElementById('panelLogin').hidden");
await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
await evaluate("location.hash='asistencias'");await waitFor("document.querySelectorAll('#asGrupos button').length===3&&!document.getElementById('asCampos').disabled");
await waitFor('navigator.serviceWorker.controller!==null');
await evaluate("window.off=await import('/js/services/asistencias-offline.js')");
await evaluate("localStorage.setItem('offline','1');window.dispatchEvent(new Event('offline'));document.querySelector('#asLista button[data-estado=asistencia]').click();document.getElementById('asGuardar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('1 pendientes')");
assert.equal(await evaluate("(await off.estadoAsistencias()).cola.length"),1);
assert.equal(await evaluate('fixture.meeting.version'),1);
assert.equal(await evaluate("document.getElementById('asCerrar').disabled"),true);
await evaluate("document.querySelectorAll('#asGrupos button')[1].click();document.querySelector('#asLista button[data-estado=justificado]').click();document.getElementById('asGuardar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('2 pendientes')");
// Actual server outage + reload: shell and data survive independently of the network.
serverOffline=true;await evaluate('window.reloadMarker=true');await send('Page.reload');await waitFor('window.reloadMarker===undefined');
await waitFor("document.getElementById('asConexion')?.textContent.includes('2 pendientes')&&!document.getElementById('asCampos').disabled");
await evaluate("window.off=await import('/js/services/asistencias-offline.js')");
assert.equal(await evaluate("(await off.obtenerReunion('meeting-1')).version"),3);
assert.equal(await evaluate("(await off.obtenerReunion('meeting-1')).integrantes.find(u=>u.clave==='sin-unidad').estado"),'asistencia');
assert.equal(await evaluate("document.querySelector('#asLista [data-color-integrante]').style.color"),'rgb(19, 133, 74)');
await shot('asistencia-offline-desktop');
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('asistencia-offline-mobile');
assert.equal(await evaluate('document.documentElement.scrollWidth<=innerWidth'),true);
// Login is restored online, then both queued unit saves are applied in order.
serverOffline=false;
await evaluate("localStorage.removeItem('offline');fixture.actor=0;document.getElementById('asRecargar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('Sin pendientes')");
assert.equal(await evaluate('fixture.meeting.version'),3);
assert.equal(await evaluate('fixture.ops.length'),2);
// Response lost after commit: retry same UUID, never an extra write.
await evaluate("fixture.respuestaPerdida=true;document.getElementById('asGuardar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('1 pendientes')");
assert.equal(await evaluate('fixture.meeting.version'),4);
await evaluate("document.getElementById('asRecargar').click()");await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('Sin pendientes')");
assert.equal(await evaluate('fixture.meeting.version'),4);
assert.equal(await evaluate('fixture.ops.length'),3);
// navigator.onLine puede ser true aunque no haya acceso al servidor.
await evaluate("fixture.redCaida=true;document.getElementById('asGuardar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('1 pendientes')");
assert.equal(await evaluate('fixture.meeting.version'),4);
await evaluate("fixture.redCaida=false;document.getElementById('asRecargar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('Sin pendientes')");
assert.equal(await evaluate('fixture.meeting.version'),5);
// Concurrent remote edit leaves local intent available for review.
await evaluate("localStorage.setItem('offline','1');document.getElementById('asGuardar').click()");await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('1 pendientes')");
await evaluate("fixture.meeting.version++;localStorage.removeItem('offline');document.getElementById('asRecargar').click()");await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asCola').textContent.includes('Resolver registro')");
assert.equal(await evaluate('(await off.estadoAsistencias()).cola[0].revisar'),true);
assert.equal(await evaluate('fixture.ops.length'),4);
// Another account cannot see this account's queue.
await evaluate("off.iniciarAsistenciasLocal('auth-2')");assert.equal(await evaluate('(await off.estadoAsistencias()).cola.length'),0);
await evaluate("off.iniciarAsistenciasLocal('auth-0')");assert.equal(await evaluate('(await off.estadoAsistencias()).cola.length'),1);
await evaluate("document.querySelector('#asCola button').click()");await waitFor("!document.getElementById('asCampos').disabled&&document.getElementById('asConexion').textContent.includes('Sin pendientes')");
await evaluate("document.getElementById('asBitacora').click()");await waitFor("!document.getElementById('asCampos').disabled&&!document.getElementById('asVistaBitacora').hidden");
await evaluate('fixture.emit(2)');await waitFor("document.getElementById('asBitacora').hidden&&!document.getElementById('asCampos').disabled");
console.log('Asistencias offline UI OK: IndexedDB, recarga sin servidor, secuencia, idempotencia, conflictos, aislamiento y bitácora. Capturas: '+output);
} catch(e){console.error(await evaluate('document.body.innerText'));throw e;} finally{ws.close();chrome.kill();server.close()}
