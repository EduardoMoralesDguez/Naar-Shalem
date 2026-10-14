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

const calendarMock=`
const f=window.fixture;f.actividades=[];
export async function listarActividades(desde,hasta){return f.actividades.filter(a=>!a.eliminado&&a.fecha<=hasta&&(a.fecha_fin||a.fecha)>=desde).map(a=>({...a,cobro_compartido:false}));}
export async function guardarActividad(a){if(f.users[f.actor].rol!=='directiva')throw new Error('No autorizado');const prev=f.actividades.find(x=>x.id===a.id);if(prev){Object.assign(prev,a,{version:prev.version+1});const m=f.meetings.find(m=>m.id===a.id);if(m)Object.assign(m,a);}else{const row={...a,version:1,estado:'borrador'};f.actividades.push(row);if(a.tipo==='regular'){const m=structuredClone(f.meeting);Object.assign(m,row);f.meetings.push(m);}}return a.id;}
export async function cancelarActividad(a,motivo){f.actividades.find(x=>x.id===a.id).estado='anulada';const m=f.meetings.find(x=>x.id===a.id);if(m)m.estado='anulada';}
export async function eliminarActividad(a){f.actividades.find(x=>x.id===a.id).eliminado=true;}

`;
mocks['/js/services/calendario.js']=calendarMock;

const server=http.createServer((req,res)=>{
 let url=new URL(req.url,'http://localhost').pathname;
 if(url==='/sw.js'){res.statusCode=404;return res.end();}
 if(mocks[url]){res.setHeader('Content-Type','text/javascript');return res.end(mocks[url]);}
 const p=path.join(root,url==='/'?'index.html':url);
 if(!p.startsWith(root)||!fs.existsSync(p)){res.statusCode=404;return res.end('missing');}
 let data=fs.readFileSync(p);if(p.endsWith('.html'))data=data.toString().replace(/<script src="[^"]*supabase[^>]+><\/script>/,'<script>'+setup+'</script>');
 res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.css')?'text/css':p.endsWith('.js')?'text/javascript':'image/png');res.end(data);
});
await new Promise(r=>server.listen(8098,'127.0.0.1',r));
const chrome=spawn(process.env.CHROMIUM_PATH||'/usr/bin/chromium',['--headless','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=9238','--user-data-dir='+output+'/chrome','about:blank'],{stdio:'ignore'});
let pages;
for(let i=0;i<100;i++){try{pages=await (await fetch('http://127.0.0.1:9238/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
const ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.on('open',r));let seq=0;const jobs=new Map();
ws.on('message',raw=>{const m=JSON.parse(raw);if(m.id){const j=jobs.get(m.id);jobs.delete(m.id);m.error?j.reject(m.error):j.resolve(m.result)}else if(m.method==='Page.javascriptDialogOpening')void send('Page.handleJavaScriptDialog',{accept:true,promptText:'Motivo de prueba'})});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;jobs.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}))})}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function waitFor(expr){for(let i=0;i<100;i++){if(await evaluate(expr))return;await new Promise(r=>setTimeout(r,40));}throw new Error('Timeout: '+expr)}
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try {
await send('Page.enable');await send('Runtime.enable');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:950,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8098/'});await waitFor('window.fixture&&fixture.listener');
await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
await evaluate("location.hash='calendario'");await waitFor("!document.getElementById('vistaCalendario').hidden&&!document.getElementById('calNueva').disabled");
assert.ok(await evaluate("document.querySelectorAll('#calDias button').length>=28"));
assert.deepEqual(await evaluate("[...document.querySelectorAll('.cal-semana span')].map(e=>e.textContent)"),['Dom','Lun','Mar','Mié','Jue','Vie','Sáb']);
assert.equal(await evaluate("[...document.getElementById('calDias').children].findIndex(e=>e.tagName==='BUTTON')"),await evaluate("new Date(fixture.meeting.fecha.slice(0,7)+'-01T12:00:00').getDay()"));
await evaluate("document.getElementById('calNueva').click();document.getElementById('calNombre').value='Camporee — mañana';const d=new Date(fixture.meeting.fecha+'T12:00:00');d.setDate(d.getDate()+7-d.getDay());fixture.fechaDomingo=d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');document.getElementById('calDia').value=fixture.fechaDomingo;document.getElementById('calDia').dispatchEvent(new Event('change'));document.getElementById('calCobro').checked=true;document.getElementById('calForm').requestSubmit()");
await waitFor("fixture.actividades.length===1&&!document.getElementById('calDialogo').open&&!document.getElementById('calNueva').disabled");
assert.ok(await evaluate("document.getElementById('calAgenda').textContent.includes('Camporee — mañana')"));
await evaluate("document.getElementById('calNueva').click();document.getElementById('calNombre').value='Camporee — tarde';document.getElementById('calHora').value='16:00';document.getElementById('calCobro').checked=true;document.getElementById('calForm').requestSubmit()");
await waitFor("fixture.actividades.length===2&&!document.getElementById('calDialogo').open&&!document.getElementById('calNueva').disabled");
assert.ok(await evaluate("document.querySelector('#calAgenda .cal-actividad-titulo time').textContent.includes('09:00')"));await shot('calendario-desktop');
// El enlace abre exactamente el pase futuro seleccionado.
await evaluate("document.querySelector('#calAgenda a[href^=\"#asistencias/\"]').click()");
await waitFor("!document.getElementById('vistaAsistencias').hidden&&document.getElementById('asReunion').value===fixture.actividades[0].id&&!document.getElementById('asCampos').disabled");
assert.ok(await evaluate("document.getElementById('asFechaTitulo').textContent.includes(fixture.fechaDomingo)"));
// El pase futuro puede cerrarse después de revisar todas sus unidades.
for(let i=0;i<3;i++){
 await evaluate(`document.querySelectorAll('#asGrupos button')[${i}].click();document.getElementById('asGuardar').click()`);
 await waitFor(`!document.getElementById('asCampos').disabled&&fixture.meetings.find(m=>m.id===fixture.actividades[0].id).grupos[${i}].revisada`);
}
assert.equal(await evaluate("document.getElementById('asCerrar').disabled"),false);
await evaluate("document.getElementById('asCerrar').click()");
await waitFor("fixture.meetings.find(m=>m.id===fixture.actividades[0].id).estado==='cerrada'&&!document.getElementById('asCampos').disabled");
await evaluate("location.hash='calendario'");await waitFor("!document.getElementById('vistaCalendario').hidden&&!document.getElementById('calNueva').disabled");
// La agenda vuelve a hoy: navega al mes/fecha programado a través del formulario para editar.
await evaluate("document.getElementById('calTodo').click()");
// Si el próximo domingo cae en otro mes, avanza una vez.
if(await evaluate("fixture.fechaDomingo.slice(0,7)!==fixture.meeting.fecha.slice(0,7)")){await evaluate("document.getElementById('calSiguiente').click()");await waitFor("document.getElementById('calAgenda').textContent.includes('Camporee')");}
await evaluate("[...document.querySelectorAll('#calAgenda button')].find(b=>b.textContent==='Editar').click();document.getElementById('calHora').value='10:00';document.getElementById('calForm').requestSubmit()");
await waitFor("fixture.actividades[0].hora==='10:00'&&!document.getElementById('calDialogo').open&&!document.getElementById('calNueva').disabled");
await evaluate("[...document.querySelectorAll('#calAgenda button')].find(b=>b.textContent==='Cancelar actividad').click()");
await waitFor("fixture.actividades[0].estado==='anulada'&&!document.getElementById('calNueva').disabled");
// Eliminar está disponible incluso para la actividad cancelada.
await evaluate("[...document.querySelectorAll('#calAgenda button')].find(b=>b.textContent==='Eliminar').click()");
await waitFor("fixture.actividades[0].eliminado&&!document.getElementById('calNueva').disabled");
assert.ok(!await evaluate("document.getElementById('calAgenda').textContent.includes('Camporee — mañana')"));
// Avisos: campos propios, sin enlaces de asistencia ni cuota.
for(const tipo of ['practica','parcial','evento']) {
 await evaluate(`document.getElementById('calNueva').click();document.getElementById('calNombre').value='Aviso ${tipo}';document.getElementById('calTipo').value='${tipo}';document.getElementById('calTipo').dispatchEvent(new Event('change'))`);
 assert.equal(await evaluate("document.getElementById('calCobro').disabled"),true);
 if(tipo==='parcial') {
  assert.equal(await evaluate("document.getElementById('calDestino').value"),'u');
  await evaluate("document.getElementById('calDestinoTipo').value='clase';document.getElementById('calDestinoTipo').dispatchEvent(new Event('change'))");
  assert.equal(await evaluate("document.getElementById('calDestino').value"),'c');
 }
 if(tipo==='evento') await evaluate("const fin=new Date(document.getElementById('calDia').value+'T12:00:00');fin.setMonth(fin.getMonth()+1,3);fixture.finEvento=fin.getFullYear()+'-'+String(fin.getMonth()+1).padStart(2,'0')+'-03';document.getElementById('calFin').value=fixture.finEvento");
 await evaluate("document.getElementById('calForm').requestSubmit()");
 await waitFor(`fixture.actividades.some(a=>a.nombre==='Aviso ${tipo}')&&!document.getElementById('calDialogo').open&&!document.getElementById('calNueva').disabled`);
 assert.equal(await evaluate(`fixture.actividades.find(a=>a.nombre==='Aviso ${tipo}').cobra_cuota`),false);
 assert.equal(await evaluate(`[...document.querySelectorAll('#calAgenda article')].find(e=>e.textContent.includes('Aviso ${tipo}')).querySelectorAll('a').length`),0);
}
await evaluate("document.getElementById('calSiguiente').click()");
await waitFor("document.getElementById('calAgenda').textContent.includes('Aviso evento')&&!document.getElementById('calNueva').disabled");
assert.ok(await evaluate("document.querySelector('#calDias button').textContent.includes('actividad')"));
// Cobro habilitado en lunes (y no solo domingo).
await evaluate("document.getElementById('calNueva').click();document.getElementById('calNombre').value='Reunión lunes';const lunesPrueba=new Date(document.getElementById('calDia').value+'T12:00:00');lunesPrueba.setDate(lunesPrueba.getDate()+(8-lunesPrueba.getDay())%7);document.getElementById('calDia').value=lunesPrueba.getFullYear()+'-'+String(lunesPrueba.getMonth()+1).padStart(2,'0')+'-'+String(lunesPrueba.getDate()).padStart(2,'0');document.getElementById('calDia').dispatchEvent(new Event('change'))");
assert.equal(await evaluate("document.getElementById('calCobro').disabled"),false);
await evaluate("document.getElementById('calCobro').checked=true;document.getElementById('calForm').requestSubmit()");
await waitFor("fixture.actividades.some(a=>a.nombre==='Reunión lunes'&&a.cobra_cuota)&&!document.getElementById('calDialogo').open&&!document.getElementById('calNueva').disabled");
await shot('calendario-tipos-desktop');
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('calendario-mobile');
assert.ok(await evaluate('document.documentElement.scrollWidth<=innerWidth'));
await evaluate('fixture.emit(1)');await waitFor("!document.getElementById('vistaCalendario').hidden&&document.getElementById('calNueva').hidden");
assert.equal(await evaluate("document.querySelectorAll('#calAgenda button').length"),0);
console.log('Calendario UI OK: domingo–sábado, tipos, rangos, destinos, cobro entre semana, cierre futuro, eliminar, permisos y móvil. Capturas: '+output);
} catch(e) {console.error(await evaluate('document.body.innerText'));throw e;} finally { ws.close();chrome.kill();server.close(); }
