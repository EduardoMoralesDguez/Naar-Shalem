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
export async function obtenerUsuarios(){const f=window.fixture;return firmarFotos(f.users.filter(u=>f.actor===0||u.es_activo).map(u=>({...u,es_directiva:u.rol==='directiva',rol:f.actor===0||u===f.users[f.actor]?u.rol:null})));}
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
export async function obtenerReunion(id=f.meeting.id){const actor=f.users[f.actor];const p=structuredClone(f.meetings.find(m=>m.id===id));p.rol=actor.rol;p.clave_actor=actor.unidad||'sin-unidad';p.puede_justificar=actor.rol==='capitan';if(actor.rol!=='directiva'){p.integrantes=p.integrantes.filter(u=>['capitan','consejero'].includes(actor.rol)?u.clave===actor.unidad:u.id_usuario===actor.id_usuario);p.grupos=p.grupos.filter(g=>p.integrantes.some(u=>u.clave===g.clave));}p.integrantes.forEach(u=>u.puede_justificar=p.puede_justificar);return p;}
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
`;
const mocks={'/js/services/asistencias.js':attendance,'/js/lib/supabase.js':lib,'/js/services/auth.js':auth,'/js/services/catalogo.js':catalogo,'/js/services/integrantes-admin.js':admin};
const server=http.createServer((req,res)=>{
 let url=new URL(req.url,'http://localhost').pathname;
 if(url==='/sw.js'){res.statusCode=404;return res.end();}
 if(mocks[url]){res.setHeader('Content-Type','text/javascript');return res.end(mocks[url]);}
 const p=path.join(root,url==='/'?'index.html':url);
 if(!p.startsWith(root)||!fs.existsSync(p)){res.statusCode=404;return res.end('missing');}
 let data=fs.readFileSync(p);if(p.endsWith('.html'))data=data.toString().replace(/<script src="[^"]*supabase[^>]+><\/script>/,'<script>'+setup+'</script>');
 res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.css')?'text/css':p.endsWith('.js')?'text/javascript':'image/png');res.end(data);
});
await new Promise(r=>server.listen(8096,'127.0.0.1',r));
const chrome=spawn(process.env.CHROMIUM_PATH||'/usr/bin/chromium',['--headless','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=9236','--user-data-dir=/tmp/naar-reuniones-chrome','about:blank'],{stdio:'ignore'});
let pages;
for(let i=0;i<100;i++){try{pages=await (await fetch('http://127.0.0.1:9236/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
const ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.on('open',r));let seq=0;const jobs=new Map();
ws.on('message',raw=>{const m=JSON.parse(raw);if(m.id){const j=jobs.get(m.id);jobs.delete(m.id);m.error?j.reject(m.error):j.resolve(m.result)}else if(m.method==='Page.javascriptDialogOpening')void send('Page.handleJavaScriptDialog',{accept:true,promptText:'Motivo de prueba'})});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;jobs.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))})}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function waitFor(expr){for(let i=0;i<100;i++){if(await evaluate(expr))return;await new Promise(r=>setTimeout(r,40));}throw new Error('Timeout: '+expr)}
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try{
await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:950,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8096/'});await waitFor("document.getElementById('panelLogin')&&!document.getElementById('panelLogin').hidden");



await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
await evaluate("location.hash='asistencias'");await waitFor("document.querySelectorAll('#asGrupos button').length===3&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.getElementById('asReunion').tagName"),'INPUT');
assert.ok(await evaluate("!document.getElementById('asFechaTitulo').textContent.includes('2099')"));
assert.equal(await evaluate("document.getElementById('asCerrar').disabled"),true);
await evaluate("document.querySelector('#asLista button[data-estado=asistencia]').click();document.getElementById('asGuardar').click()");
await waitFor("!document.getElementById('asCampos').disabled&&fixture.meeting.grupos.some(g=>g.revisada)");
for(let i=0;i<3;i++){
 await evaluate(`document.querySelectorAll('#asGrupos button')[${i}].click();document.getElementById('asGuardar').click()`);
 await waitFor(`!document.getElementById('asCampos').disabled&&fixture.meeting.grupos[${i}].revisada`);
}
await shot('reunion-desktop');
await evaluate("document.getElementById('asCerrar').click()");await waitFor("fixture.meeting.estado==='cerrada'&&!document.getElementById('asCampos').disabled");
await evaluate("document.getElementById('asHistorial').click()");await waitFor("document.querySelectorAll('#asMatriz tbody tr').length>0&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('#asMatriz thead th').length"),4);
await evaluate("document.getElementById('asFiltroUnidad').value='sin-unidad';document.getElementById('asFiltroUnidad').dispatchEvent(new Event('change'))");
assert.equal(await evaluate("document.querySelector('#asMatriz tbody tr td:last-child').textContent"),'50%');
await evaluate("document.querySelectorAll('#asMatriz tbody button')[1].click();document.querySelectorAll('#asCeldaOpciones button')[2].click()");
await waitFor("!document.querySelector('dialog').open&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.querySelector('#asMatriz tbody tr td:last-child').textContent"),'0%');
await shot('matriz-desktop');
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('matriz-mobile');
assert.equal(await evaluate('document.documentElement.scrollWidth<=window.innerWidth'),true);
await evaluate("fixture.meeting.integrantes.find(u=>u.id_usuario===fixture.users[2].id_usuario).estado='asistencia';fixture.emit(2)");
await waitFor("document.querySelectorAll('#asLista tr').length===2&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('#asGrupos button').length"),0);
assert.equal(await evaluate("document.querySelectorAll('#asLista button').length"),1);
await evaluate("document.getElementById('asHistorial').click()");await waitFor("document.querySelectorAll('#asMatriz tbody tr').length===2&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('#asMatriz button').length"),0);
assert.equal(await evaluate("document.getElementById('asFiltroUnidadCampo').hidden"),true);
await evaluate('fixture.emit(3)');await waitFor("!document.getElementById('asCampos').disabled&&document.querySelectorAll('#asLista tr').length===2");
assert.equal(await evaluate("document.querySelectorAll('#asLista button').length"),0);
await evaluate("location.hash='perfil/'+fixture.users[3].id_usuario");await waitFor("!document.getElementById('dashboard').hidden");
assert.equal(await evaluate("document.getElementById('cuotasPorcentaje').closest('.metrica').hidden"),true);
assert.equal(await evaluate("fixture.progress.at(-1).cobraCuotas"),false);
await evaluate("fixture.emit(0);location.hash='perfil/'+fixture.users[0].id_usuario");await waitFor("document.getElementById('dashboard').hidden&&!document.getElementById('vistaPerfil').hidden&&document.getElementById('tarjetaUnidad').parentElement.hidden");
assert.equal(await evaluate("document.getElementById('tarjetaClase').parentElement.hidden"),true);
await evaluate("location.hash='consultar'");await waitFor("!document.getElementById('directorio').hidden");
assert.equal(await evaluate("document.querySelector('a[href=\"#perfil/'+fixture.users[0].id_usuario+'\"] .integrante-detalles').hidden"),true);
await evaluate("location.hash='perfil/'+fixture.users[1].id_usuario");await waitFor("!document.getElementById('dashboard').hidden&&!document.getElementById('cuotasPorcentaje').closest('.metrica').hidden");
assert.equal(await evaluate('fixture.progress.at(-1).cobraCuotas'),true);

// Segundo pase del mismo día y exclusión de directiva.
await evaluate("location.hash='asistencias'");await waitFor("!document.getElementById('asCampos').disabled&&!document.getElementById('vistaAsistencias').hidden");
assert.equal(await evaluate("document.getElementById('asCrearPanel').hidden"),false);
assert.ok(await evaluate("!document.getElementById('asLista').textContent.includes('Ezequiel')"));
await evaluate("document.getElementById('asNombrePase').value='Tarde';document.getElementById('asCrear').click()");
await waitFor("fixture.meetings.length===2&&!document.getElementById('asCampos').disabled");
assert.ok(await evaluate("document.getElementById('asFechaTitulo').textContent.includes('Tarde')"));
assert.equal(await evaluate("document.querySelectorAll('#asPasesHoy button').length"),2);
for(let i=0;i<3;i++){
 await evaluate(`document.querySelectorAll('#asGrupos button')[${i}].click();document.getElementById('asGuardar').click()`);
 await waitFor(`!document.getElementById('asCampos').disabled&&fixture.meetings[1].grupos[${i}].revisada`);
}
await evaluate("document.getElementById('asCerrar').click()");await waitFor("fixture.meetings[1].estado==='cerrada'&&!document.getElementById('asCampos').disabled");
await evaluate("document.getElementById('asNombrePase').value='Tarde';document.getElementById('asCrear').click()");await waitFor("!document.getElementById('asCampos').disabled");
assert.equal(await evaluate('fixture.meetings.length'),2);
await evaluate("document.getElementById('asHistorial').click()");await waitFor("document.querySelectorAll('#asMatriz thead th').length===5&&!document.getElementById('asCampos').disabled");
assert.ok(await evaluate("document.getElementById('asMatriz').textContent.includes('Tarde')"));
assert.ok(await evaluate("!document.getElementById('asMatriz').textContent.includes('Ezequiel')"));
await shot('pases-mismo-dia-mobile');
assert.equal(await evaluate('document.documentElement.scrollWidth<=window.innerWidth'),true);
await evaluate("document.getElementById('botonSalir').click()");await waitFor("!document.getElementById('panelLogin').hidden");
console.log('UI OK: varios pases por día, directiva exenta, reunión actual, botones A/J/F, matriz editable/porcentajes, permisos, perfiles por rol, móvil y logout. Capturas: '+output);
} finally{ws.close();chrome.kill();server.close()}
