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
window.fixture.actor=JSON.parse(localStorage.getItem('test-actor')||'null');
const emitOriginal=window.fixture.emit;window.fixture.emit=function(n){localStorage.setItem('test-actor',JSON.stringify(n));emitOriginal.call(this,n)};
`;
const lib=`export function obtenerSupabase(){return {auth:{onAuthStateChange(cb){window.fixture.listener=cb;cb('INITIAL_SESSION',window.fixture.actor===null?null:{access_token:'token-'+window.fixture.actor,user:{id:'auth-'+window.fixture.actor}})},async getSession(){return {data:{session:{access_token:'token-'+window.fixture.actor,user:{id:'auth-'+window.fixture.actor}}}}}},storage:{from(){return {
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

const cuotasMock=`
const f=window.fixture;
function leer(){let d=JSON.parse(localStorage.getItem('test-cuotas')||'null');if(d)return d;
const partes=new Intl.DateTimeFormat('en',{timeZone:'America/Mexico_City',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());const hoy=['year','month','day'].map(t=>partes.find(p=>p.type===t).value).join('-');
d={id_ciclo:'ciclo',hoy,periodos:[{id:'domingo',fecha:hoy,legado:false}],integrantes:f.users.filter(u=>['conquistador','capitan'].includes(u.rol)).map(u=>({id_usuario:u.id_usuario,nombre:u.nombres+' '+u.apellido,id_unidad:u.unidad||null,unidad:u.unidad||'Sin unidad',version:1,saldo:0})),cargos:[],ingresos:[],aplicaciones:[],operaciones:[]};
d.cargos=d.integrantes.map(u=>({id_usuario:u.id_usuario,periodo:'domingo',id_unidad:u.id_unidad,cerrado:false,importe:1000,pagado:0}));localStorage.setItem('test-cuotas',JSON.stringify(d));return d;}
export async function obtenerCuotas(){if(!navigator.onLine)throw new Error('Offline');const d=leer(),a=f.users[f.actor];if(a.rol!=='directiva'){d.integrantes=d.integrantes.filter(u=>['capitan','subcapitan'].includes(a.rol)?u.unidad===a.unidad:u.id_usuario===a.id_usuario);const ids=d.integrantes.map(u=>u.id_usuario);d.cargos=d.cargos.filter(u=>ids.includes(u.id_usuario));d.ingresos=d.ingresos.filter(u=>ids.includes(u.id_usuario));d.aplicaciones=d.aplicaciones.filter(u=>ids.includes(u.id_usuario));}return d;}
export async function verificarCuenta(id){if(!navigator.onLine)throw new Error('Offline');if(id!=='auth-'+f.actor)throw new Error('Otra cuenta');}
export async function enviarCuota(o){if(!navigator.onLine)throw new Error('Offline');const d=leer();if(d.operaciones.includes(o.id))return {};
if(o.accion==='cerrar'){for(const c of d.cargos.filter(c=>c.periodo===o.datos.periodo&&(c.id_unidad||'sin-unidad')===o.datos.unidad)){const u=d.integrantes.find(u=>u.id_usuario===c.id_usuario);if(o.datos.versiones[u.id_usuario]!==u.version)throw {code:'40001',message:'El cobro cambió'};const aplicado=Math.min(u.saldo,c.importe-c.pagado);u.saldo-=aplicado;c.pagado+=aplicado;c.cerrado=true;u.version++;}d.operaciones.push(o.id);localStorage.setItem('test-cuotas',JSON.stringify(d));return {};}
const u=d.integrantes.find(u=>u.id_usuario===o.datos.id_usuario);
if(o.datos.version!==u.version)throw {code:'40001',message:'El registro cambió en otro dispositivo. Revisa antes de guardar.'};
u.version++;d.operaciones.push(o.id);d.ingresos.push({id:o.id,id_usuario:u.id_usuario,importe:o.datos.importe,fecha:o.datos.fecha,registrado_por:'Cuenta de prueba'});
let resto=o.datos.importe;for(const periodo of o.datos.periodos){const c=d.cargos.find(c=>c.id_usuario===u.id_usuario&&c.periodo===periodo);const monto=Math.min(resto,c.importe-c.pagado);if(monto>0){c.pagado+=monto;resto-=monto;d.aplicaciones.push({ingreso:o.id,id_usuario:u.id_usuario,periodo,importe:monto});}}u.saldo+=resto;localStorage.setItem('test-cuotas',JSON.stringify(d));
if(f.perderRespuesta){f.perderRespuesta=false;throw new Error('Respuesta perdida');}return {};}
`;
mocks['/js/services/cuotas.js']=cuotasMock;

let servidorDesconectado=false;
const server=http.createServer((req,res)=>{
 if(servidorDesconectado){req.socket.destroy();return;}
 let url=new URL(req.url,'http://localhost').pathname;

 if(mocks[url]){res.setHeader('Content-Type','text/javascript');return res.end(mocks[url]);}
 const p=path.join(root,url==='/'?'index.html':url);
 if(!p.startsWith(root)||!fs.existsSync(p)){res.statusCode=404;return res.end('missing');}
 let data=fs.readFileSync(p);if(p.endsWith('.html'))data=data.toString().replace(/<script src="[^"]*supabase[^>]+><\/script>/,'<script>'+setup+'</script>');
 res.setHeader('Content-Type',p.endsWith('.html')?'text/html':p.endsWith('.css')?'text/css':p.endsWith('.js')?'text/javascript':'image/png');res.end(data);
});
await new Promise(r=>server.listen(8097,'127.0.0.1',r));
const chrome=spawn(process.env.CHROMIUM_PATH||'/usr/bin/chromium',['--headless','--no-sandbox','--disable-dev-shm-usage','--remote-debugging-port=9237','--user-data-dir='+output+'/chrome','about:blank'],{stdio:'ignore'});
let pages;
for(let i=0;i<100;i++){try{pages=await (await fetch('http://127.0.0.1:9237/json')).json();break;}catch{await new Promise(r=>setTimeout(r,100));}}
const ws=new WebSocket(pages[0].webSocketDebuggerUrl);await new Promise(r=>ws.on('open',r));let seq=0;const jobs=new Map();
ws.on('message',raw=>{const m=JSON.parse(raw);if(m.id){const j=jobs.get(m.id);jobs.delete(m.id);m.error?j.reject(m.error):j.resolve(m.result)}else if(m.method==='Runtime.exceptionThrown')console.error(JSON.stringify(m.params.exceptionDetails));else if(m.method==='Page.javascriptDialogOpening')void send('Page.handleJavaScriptDialog',{accept:true,promptText:'Motivo de prueba'})});
function send(method,params={}){return new Promise((resolve,reject)=>{const id=++seq;const timer=setTimeout(()=>reject(new Error('CDP timeout: '+method)),15000);jobs.set(id,{resolve:r=>{clearTimeout(timer);resolve(r)},reject:e=>{clearTimeout(timer);reject(e)}});ws.send(JSON.stringify({id,method,params}))})}
async function evaluate(expression){const r=await send('Runtime.evaluate',{expression,awaitPromise:true,returnByValue:true,userGesture:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;}
async function waitFor(expr){for(let i=0;i<100;i++){if(await evaluate(expr))return;await new Promise(r=>setTimeout(r,40));}throw new Error('Timeout: '+expr)}
async function shot(name){const r=await send('Page.captureScreenshot',{format:'png'});fs.writeFileSync(output+'/'+name+'.png',Buffer.from(r.data,'base64'))}
try {
await send('Page.enable');await send('Runtime.enable');await send('Network.enable');
await send('Page.addScriptToEvaluateOnNewDocument',{source: "Object.defineProperty(navigator,'onLine',{get:()=>localStorage.getItem('test-offline')!=='true'})"});
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:950,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:'http://127.0.0.1:8097/'});
await waitFor("window.fixture&&fixture.listener");await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('inicio').hidden");
await evaluate("location.hash='cuotas'");await waitFor("document.querySelectorAll('#cuLista tr').length>0&&!document.getElementById('cuSync').disabled");
await evaluate("document.getElementById('cuSync').click()");await waitFor("document.getElementById('cuEstado').textContent.includes('Disponible sin conexión')");
await shot('cuotas-desktop');
// Historial separado: tabla de unidad, directorio e ingreso individual.
await evaluate("document.getElementById('cuTabHistorial').click()");
assert.ok(await evaluate("document.getElementById('cuVistaCobro').hidden&&!document.getElementById('cuVistaHistorial').hidden"));
assert.ok(await evaluate("document.querySelectorAll('#cuMatriz tbody tr').length>0"));
await shot('cuotas-historial-unidad');
await evaluate("document.getElementById('cuPorIntegrante').click()");
assert.ok(await evaluate("document.querySelectorAll('#cuIntegrantes button').length>0"));
await evaluate("document.querySelector('#cuIntegrantes button').click()");
assert.ok(await evaluate("!document.getElementById('cuHistDetalle').hidden&&document.getElementById('cuHistDirectorio').hidden"));
await evaluate("document.getElementById('cuHistVolver').click();document.getElementById('cuTabBitacora').click()");
assert.ok(await evaluate("!document.getElementById('cuAuditoria').hidden&&document.getElementById('cuVistaHistorial').hidden"));
await evaluate("document.getElementById('cuTabCobro').click()");

await evaluate("localStorage.setItem('test-offline','true');window.dispatchEvent(new Event('offline'))");
servidorDesconectado=true;
await send('Network.emulateNetworkConditions',{offline:true,latency:0,downloadThroughput:0,uploadThroughput:0});
await evaluate("document.querySelector('#cuLista input[type=checkbox]').click();document.getElementById('cuGuardar').click()");
await waitFor("document.getElementById('cuCola').children.length===1");
assert.equal(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).ingresos.length"),0);
// Recarga real sin red: service worker + IndexedDB + identidad local preparada.
await evaluate('window.recargaPendiente=true');
await send('Page.reload');await waitFor("!window.recargaPendiente&&document.getElementById('cuCola')&&document.getElementById('cuCola').children.length===1&&!document.getElementById('vistaCuotas').hidden");
// El DOM y el servidor desconectado verifican la recarga offline; no dependemos del compositor de Chromium en ese estado.
assert.ok(await evaluate("document.getElementById('cuEstado').textContent.includes('Sin conexión')"));
servidorDesconectado=false;
await evaluate("localStorage.removeItem('test-offline');window.dispatchEvent(new Event('online'))");
await send('Network.emulateNetworkConditions',{offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1});
await waitFor("document.getElementById('cuEstado').textContent.includes('Todos los movimientos están sincronizados')");
assert.equal(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).ingresos.length"),1);
// Respuesta perdida después de guardar: retry con UUID estable no duplica dinero.
await evaluate("fixture.perderRespuesta=true;document.querySelector('#cuLista input[type=checkbox]').click();document.getElementById('cuGuardar').click()");
await waitFor("document.getElementById('cuCola').textContent.includes('Respuesta perdida')");
const cantidad=await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).ingresos.length");
await evaluate("document.getElementById('cuSync').click()");await waitFor("document.getElementById('cuCola').children.length===0");
assert.equal(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).ingresos.length"),cantidad);
// Conflicto de otro capturista se conserva para revisión, sin sobrescribir.
await evaluate("localStorage.setItem('test-offline','true');window.dispatchEvent(new Event('offline'))");
servidorDesconectado=true;
await send('Network.emulateNetworkConditions',{offline:true,latency:0,downloadThroughput:0,uploadThroughput:0});
await evaluate("document.querySelector('#cuLista input[type=checkbox]').click();document.getElementById('cuGuardar').click()");await waitFor("document.getElementById('cuCola').children.length===1");
await evaluate("const d=JSON.parse(localStorage.getItem('test-cuotas'));d.integrantes.forEach(u=>u.version++);localStorage.setItem('test-cuotas',JSON.stringify(d));");
servidorDesconectado=false;
await evaluate("localStorage.removeItem('test-offline');window.dispatchEvent(new Event('online'))");
await send('Network.emulateNetworkConditions',{offline:false,latency:0,downloadThroughput:-1,uploadThroughput:-1});
await waitFor("document.getElementById('cuCola').textContent.includes('El registro cambió')");
assert.equal(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).ingresos.length"),cantidad);
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await shot('cuotas-mobile');
assert.ok(await evaluate('document.documentElement.scrollWidth<=innerWidth'));
// Otra cuenta no ve la cola del directivo y no puede registrar como conquistador.
await evaluate('fixture.emit(1)');await waitFor("!document.getElementById('vistaCuotas').hidden&&document.getElementById('cuGuardar').hidden&&document.getElementById('cuCola').children.length===0");
assert.equal(await evaluate("document.querySelectorAll('#cuLista input[type=checkbox]').length"),0);
await evaluate("fixture.users[2].rol='subcapitan';fixture.emit(2)");
await waitFor("!document.getElementById('cuGuardar').hidden&&document.getElementById('cuCalendario').hidden");
assert.ok(await evaluate("[...document.querySelectorAll('#cuLista th')].every(t=>t.textContent.includes('Daniel'))"));
assert.equal(await evaluate("document.getElementById('cuTabBitacora').hidden"),true);
await evaluate("document.getElementById('cuTabHistorial').click();document.getElementById('cuPorIntegrante').click()");
assert.ok(await evaluate("document.getElementById('cuHistUnidadCampo').hidden&&[...document.querySelectorAll('#cuIntegrantes strong')].every(e=>e.textContent.includes('Daniel'))"));
await evaluate("document.getElementById('cuTabCobro').click()");

await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('cuCalendario').hidden&&!document.getElementById('cuSync').disabled");
await evaluate("[...document.querySelectorAll('#cuLista button')].find(b=>b.textContent==='Abono / anticipo').click()");
await waitFor("document.getElementById('cuDialogo').open");await shot('cuotas-anticipo');
await evaluate("document.getElementById('cuMonto').value='50';document.getElementById('cuFormulario').requestSubmit()");
await waitFor("!document.getElementById('cuDialogo').open&&JSON.parse(localStorage.getItem('test-cuotas')).integrantes.some(u=>u.saldo===5000)");
// Dos cobros del mismo día para la misma persona se guardan offline por separado.
await evaluate(`{
 const datos=JSON.parse(localStorage.getItem('test-cuotas'));
 for(const [id,nombre,hora] of [['manana','Mañana','09:00'],['tarde','Tarde','16:00']]) {
  datos.periodos.unshift({id,fecha:datos.hoy,nombre,hora,legado:false});
  datos.cargos.push({id_usuario:fixture.users[2].id_usuario,periodo:id,importe:1000,pagado:0});
 }
 localStorage.setItem('test-cuotas',JSON.stringify(datos));fixture.emit(2);
}`);
await waitFor("!document.getElementById('cuCalendario').hidden===false&&document.getElementById('cuPeriodo').options.length===3&&!document.getElementById('cuSync').disabled");
assert.ok(await evaluate("document.getElementById('cuPeriodo').textContent.includes('Tarde')&&document.getElementById('cuPeriodo').textContent.includes('Mañana')"));
await evaluate("localStorage.setItem('test-offline','true');window.dispatchEvent(new Event('offline'))");
for(const periodo of ['manana','tarde']) {
 await evaluate(`document.getElementById('cuPeriodo').value='${periodo}';document.getElementById('cuPeriodo').dispatchEvent(new Event('change'));document.querySelector('#cuLista input[type=checkbox]').click();document.getElementById('cuGuardar').click()`);
 await waitFor(`document.getElementById('cuCola').children.length===${periodo==='manana'?1:2}`);
}
await evaluate("document.getElementById('cuPeriodo').value='manana';document.getElementById('cuPeriodo').dispatchEvent(new Event('change'))");
assert.equal(await evaluate("document.querySelectorAll('#cuLista input[type=checkbox]').length"),0);
// Respuesta perdida del primero: el segundo espera y ambos terminan una sola vez.
await evaluate("fixture.perderRespuesta=true;localStorage.removeItem('test-offline');window.dispatchEvent(new Event('online'))");
await waitFor("document.getElementById('cuCola').textContent.includes('Respuesta perdida')&&!document.getElementById('cuSync').disabled");
await evaluate("document.getElementById('cuSync').click()");await waitFor("document.getElementById('cuCola').children.length===0&&!document.getElementById('cuSync').disabled");
assert.deepEqual(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).cargos.filter(c=>['manana','tarde'].includes(c.periodo)).map(c=>c.pagado)"),[1000,1000]);
// Si un tercero cambia el saldo, bloquea también los pagos que dependían del primero.
await evaluate(`{
 const datos=JSON.parse(localStorage.getItem('test-cuotas'));
 for(const id of ['conflicto-a','conflicto-b']) {
  datos.periodos.unshift({id,fecha:datos.hoy,nombre:id,hora:'18:00',legado:false});
  datos.cargos.push({id_usuario:fixture.users[2].id_usuario,periodo:id,importe:1000,pagado:0});
 }
 localStorage.setItem('test-cuotas',JSON.stringify(datos));document.getElementById('cuSync').click();
}`);
await waitFor("document.getElementById('cuPeriodo').options.length===5&&!document.getElementById('cuSync').disabled");
await evaluate("localStorage.setItem('test-offline','true');window.dispatchEvent(new Event('offline'))");
for(const [index,periodo] of ['conflicto-a','conflicto-b'].entries()) {
 await evaluate(`document.getElementById('cuPeriodo').value='${periodo}';document.getElementById('cuPeriodo').dispatchEvent(new Event('change'));document.querySelector('#cuLista input[type=checkbox]').click();document.getElementById('cuGuardar').click()`);
 await waitFor(`document.getElementById('cuCola').children.length===${index+1}`);
}
await evaluate(`{const datos=JSON.parse(localStorage.getItem('test-cuotas'));datos.integrantes.find(u=>u.id_usuario===fixture.users[2].id_usuario).version++;localStorage.setItem('test-cuotas',JSON.stringify(datos));localStorage.removeItem('test-offline');window.dispatchEvent(new Event('online'));}`);
await waitFor("document.getElementById('cuCola').textContent.includes('Un pago anterior')&&!document.getElementById('cuSync').disabled");
assert.deepEqual(await evaluate("JSON.parse(localStorage.getItem('test-cuotas')).cargos.filter(c=>c.periodo.startsWith('conflicto-')).map(c=>c.pagado)"),[0,0]);
await evaluate('fixture.emit(0)');await waitFor("!document.getElementById('cuCalendario').hidden&&!document.getElementById('cuSync').disabled");
await evaluate("document.getElementById('cuPeriodo').value='domingo';document.getElementById('cuUnidad').selectedIndex=1;document.getElementById('cuUnidad').dispatchEvent(new Event('change'))");
assert.equal(await evaluate("document.getElementById('cuCerrar').disabled"),true);
await evaluate("document.querySelector('#cuCola button').click()");await waitFor("document.getElementById('cuCola').children.length===0");
await waitFor("!document.getElementById('cuCerrar').hidden&&!document.getElementById('cuCerrar').disabled");
await evaluate("document.getElementById('cuCerrar').click()");await waitFor("document.getElementById('cuCierreEstado').textContent==='Cobro de unidad cerrado'");
assert.equal(await evaluate("document.getElementById('cuCerrar').hidden"),true);
await shot('cuotas-cierre');
console.log('Cuotas UI OK: preparación, recarga sin red, sincronización, respuesta perdida, conflicto, aislamiento entre cuentas, móvil y varios cobros offline con conflictos encadenados. Capturas: '+output);
} catch (e) { console.error(await evaluate('document.body.innerText')); await shot('error'); console.error(output); throw e; } finally { ws.close();chrome.kill();server.close(); }
