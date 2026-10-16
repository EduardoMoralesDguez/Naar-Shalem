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
function init(){if(f.cp)return;f.cp={admin:true,id_ciclo:'ciclo',anio:2026,hoy:'2026-10-16',desde:'2026-10-01',hasta:'2026-10-16',version_config:1,justificados:true,criterios,unidades:[{id:'u',nombre:'Diamante'}],reuniones:[{id:'meeting-1',nombre:'Reunión regular',fecha:'2026-10-16',hora:'09:00',guardada:false}],cortes:[],bitacora:[],resultados:{unidades:[{id_unidad:'u',nombre:'Diamante',puntos:40}],individual:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez',puntos:20}],destacados:[{id_usuario:f.users[1].id_usuario,nombre:'Ana Pérez'}]},anual:{unidades:[{id_unidad:'u',nombre:'Diamante',puntos:40}],individual:[]}};
f.captura={id:'meeting-1',nombre:'Reunión regular',fecha:'2026-10-16',version:0,version_reunion:1,version_config:1,cerrada:false,criterios:structuredClone(criterios),integrantes:f.users.filter(u=>u.rol!=='directiva').map(u=>({id_usuario:u.id_usuario,nombre:u.nombres+' '+u.apellido,id_unidad:'u',unidad:'Diamante',cobra:u.rol!=='consejero',cumplidos:[],automaticos:[]})),extras:[]};}
export async function obtenerCompetencia(reunion=null,desde=null,hasta=null){init();const p=structuredClone(f.cp);p.admin=f.actor===0;p.desde=desde||p.desde;p.hasta=hasta||p.hasta;p.captura=reunion&&p.admin?structuredClone(f.captura):null;if(!p.admin){p.reuniones=[];p.criterios=[];p.resultados.individual=[];p.anual=null;}return p;}
export async function guardarCompetencia(id,accion,datos){f.intentos ||= [];f.intentos.push({id,accion,datos});if(f.fallar){f.fallar=false;throw new Error('Sin confirmación');}if(f.actor!==0)throw new Error('Solo directiva');f.ultimaOperacion={id,accion,datos};if(accion==='captura'){f.captura.version++;for(const u of f.captura.integrantes)u.cumplidos=datos.integrantes.find(i=>i.id_usuario===u.id_usuario).cumplidos;f.captura.extras=datos.extras;f.cp.reuniones[0].guardada=true;}if(accion==='criterios'){for(const k of datos.criterios){let v=f.cp.criterios.find(c=>c.id===k.id);if(v)Object.assign(v,k);else f.cp.criterios.push({...k,id:'nuevo',fuente:'manual'});}f.cp.version_config++;}if(accion==='corte'){f.cp.cortes.push({...datos,id:'corte'});f.captura.cerrada=true;}}
`;
const mocks={'/js/services/competencia.js':competencia,'/js/services/asistencias.js':attendance,'/js/lib/supabase.js':lib,'/js/services/auth.js':auth,'/js/services/catalogo.js':catalogo,'/js/services/integrantes-admin.js':admin};
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
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try{
await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8100/'});await waitFor("document.getElementById('panelLogin')&&!document.getElementById('panelLogin').hidden");
await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
assert.equal(await evaluate("document.querySelectorAll('#inicio a[href=\"#competencia\"]').length"),1);
await evaluate("location.hash='competencia'");await waitFor("document.getElementById('cpGuardar')&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('.cp-matriz tbody tr').length"),4);
assert.equal(await evaluate("document.querySelectorAll('.cp-matriz tbody tr:first-child input[type=checkbox]').length"),5);
await evaluate("document.querySelector('.cp-matriz input').click()");assert.equal(await evaluate("document.querySelector('[data-cp-total]').textContent"),'5');
await evaluate("document.querySelector('#cpExtraForm [name=motivo]').value='Servicio';document.querySelector('#cpExtraForm [name=puntos]').value='7';document.getElementById('cpExtraForm').requestSubmit()");
assert.equal(await evaluate("document.querySelector('[data-cp-total]').textContent"),'12');
await evaluate("document.querySelector('#cpExtraForm [name=tipo]').value='unidad';document.querySelector('#cpExtraForm [name=tipo]').dispatchEvent(new Event('change'));document.querySelector('#cpExtraForm [name=motivo]').value='Dinámica';document.getElementById('cpExtraForm').requestSubmit()");
assert.equal(await evaluate("document.querySelectorAll('#cpExtras tbody tr').length"),2);
await shot('competencia-matriz-desktop');
await evaluate("fixture.fallar=true;document.getElementById('cpGuardar').click()");await waitFor("document.getElementById('cpMensaje').textContent.includes('Sin confirmación')&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpGuardar').click()");await waitFor("fixture.captura.version===1&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate('fixture.intentos[0].id===fixture.intentos[1].id'),true);
assert.equal(await evaluate('fixture.ultimaOperacion.datos.extras[0].motivo'),'Servicio');
await evaluate("document.querySelector('[data-cp-tab=criterios]').click()");await waitFor("!document.getElementById('cpCriterios').hidden");
await evaluate("document.querySelector('#cpConfig input[type=number]').value='8';document.querySelector('#cpNuevoCriterio [name=nombre]').value='Uniforme';document.getElementById('cpNuevoCriterio').requestSubmit()");await waitFor("fixture.cp.criterios.length===8&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate('fixture.cp.criterios[0].valor'),8);
assert.equal(await evaluate('fixture.captura.criterios[0].valor'),5);
await evaluate("document.querySelector('[data-cp-tab=puntaje]').click()");
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('competencia-matriz-mobile');assert.equal(await evaluate('document.documentElement.scrollWidth<=innerWidth'),true);
await evaluate("location.hash='asistencias'");await waitFor("!document.getElementById('vistaAsistencias').hidden&&!document.getElementById('asCampos').disabled");
assert.equal(await evaluate("document.querySelectorAll('#vistaAsistencias .cp-nav a').length"),3);
await evaluate("location.hash='competencia/cortes'");await waitFor("!document.getElementById('cpCortes').hidden&&!document.getElementById('cpCampos').disabled");
await evaluate("document.getElementById('cpTipoCorte').value='personalizado';document.getElementById('cpTipoCorte').dispatchEvent(new Event('change'));document.getElementById('cpCorteHasta').value='2026-10-16';document.getElementById('cpCortar').requestSubmit()");await waitFor("fixture.cp.cortes.length===1&&!document.getElementById('cpCampos').disabled");
await evaluate("document.querySelector('[data-cp-tab=puntaje]').click()");await waitFor("!document.getElementById('cpPuntaje').hidden");assert.equal(await evaluate("document.getElementById('cpGuardar')===null"),true);
await evaluate('fixture.emit(2)');await waitFor("!document.getElementById('cpResultados').hidden&&!document.getElementById('cpCampos').disabled");
assert.equal(await evaluate("document.querySelector('[data-cp-tab=puntaje]').hidden"),true);
assert.equal(await evaluate("document.querySelector('[data-cp-tab=criterios]').hidden"),true);
assert.equal(await evaluate("document.getElementById('cpRanking').textContent.includes('Clasificación individual')"),false);
assert.equal(await evaluate("document.querySelector('.cp-destacado').textContent"),'Ana Pérez');
await shot('competencia-destacados-mobile');assert.equal(await evaluate('document.documentElement.scrollWidth<=innerWidth'),true);
// Competencia conserva el acceso a Asistencias aun sin conexión.
await evaluate("Object.defineProperty(navigator,'onLine',{configurable:true,get:()=>false});location.hash='inicio'");await waitFor("!document.getElementById('inicio').hidden");
await evaluate("location.hash='competencia'");await waitFor("!document.getElementById('vistaCompetencia').hidden&&document.getElementById('cpMensaje').textContent.includes('Conecta')");
assert.equal(await evaluate("document.querySelector('#vistaCompetencia a[href=\"#asistencias\"]').offsetParent!==null"),true);
await evaluate("document.querySelector('#vistaCompetencia a[href=\"#asistencias\"]').click()");await waitFor("!document.getElementById('vistaAsistencias').hidden");
console.log('Competencia UI OK: matriz, extras, reintento, criterios, cortes, navegación, roles y móvil. Capturas: '+output);
}catch(e){console.error(await evaluate('document.body.innerText'));await shot('error');console.error(output);throw e;}finally{ws.close();chrome.kill();server.close();}
