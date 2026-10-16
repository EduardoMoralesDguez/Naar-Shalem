import * as remoto from './asistencias.js';
import {localCuotas} from '../lib/cuotas-local.js';
let cuenta=null,sincronizando=false;
const vacio=()=>({lista:[],paneles:{},matriz:[],cola:[],contexto:null,actualizado:null});
async function local(id,fn){const d=await localCuotas(id,d=>{d.asistencias ||= vacio();if(fn)fn(d.asistencias);});return d.asistencias;}
export function iniciarAsistenciasLocal(id){cuenta=id;}
export const pendientesAsistencias=async id=>id?(await local(id)).cola.length:0;
export async function estadoAsistencias(){return cuenta?local(cuenta):vacio();}
export async function prepararAsistencias(){
 const id=cuenta;if(!id||!navigator.onLine)return;
 await remoto.verificarAsistenciaCuenta(id);
 const contexto=await remoto.obtenerContextoAsistencias();
 const lista=await remoto.listarReuniones();
 const paneles={};for(let i=0;i<lista.length;i+=4){const grupo=lista.slice(i,i+4);const resultados=await Promise.all(grupo.map(r=>remoto.obtenerReunion(r.id)));grupo.forEach((r,j)=>paneles[r.id]=resultados[j]);}
 const matriz=await remoto.obtenerMatriz();
 await local(id,d=>{d.contexto=contexto;d.lista=lista;d.matriz=matriz.map(f=>{const p=d.cola.some(o=>o.reunion===f.reunion)&&d.paneles[f.reunion];return p?{...f,version:p.version,estado:p.integrantes.find(u=>u.id_usuario===f.id_usuario)?.estado||f.estado}:f;});for(const [k,p] of Object.entries(paneles))if(!d.cola.some(o=>o.reunion===k))d.paneles[k]=p;
 for(const k of Object.keys(d.paneles))if(!paneles[k]&&!d.cola.some(o=>o.reunion===k))delete d.paneles[k];d.actualizado=Date.now();});
}
export async function sincronizarAsistencias(){
 const id=cuenta;if(!id||!navigator.onLine||sincronizando)return;
 sincronizando=true;
 try{await remoto.verificarAsistenciaCuenta(id);const d=await local(id),bloqueadas=new Set();
 for(const op of d.cola){if(cuenta!==id)return;
 if(op.revisar){bloqueadas.add(op.reunion);continue;}
 if(bloqueadas.has(op.reunion)){await local(id,d=>{const x=d.cola.find(o=>o.id===op.id);if(x){x.revisar=true;x.error='Un cambio anterior de esta reunión requiere revisión.';}});continue;}
 try{await remoto.enviarAsistencia(op);await local(id,d=>{d.cola=d.cola.filter(o=>o.id!==op.id);const estado={cerrar:'cerrada',anular:'anulada',restaurar:'borrador'}[op.accion];if(estado){if(d.paneles[op.reunion])d.paneles[op.reunion].estado=estado;const r=d.lista.find(r=>r.id===op.reunion);if(r)r.estado=estado;}});}
 catch(e){const revisar=['40001','42501','22023','23505','22P02'].includes(e.code);await local(id,d=>{const x=d.cola.find(o=>o.id===op.id);if(x){x.revisar=revisar;x.error=e.message||'Sin confirmación. Se reintentará sin duplicar.';}});bloqueadas.add(op.reunion);if(!revisar)break;}
 }
 }finally{sincronizando=false;}
}
export async function resolverAsistencia(idOp){const id=cuenta;await local(id,d=>{const op=d.cola.find(o=>o.id===idOp);if(!op)return;d.cola=d.cola.filter(o=>o.id!==idOp);for(const x of d.cola.filter(o=>o.reunion===op.reunion)){x.revisar=true;x.error='Se descartó un cambio anterior. Revisa esta reunión.';}delete d.paneles[op.reunion];});}
export async function listarReuniones(){const d=await local(cuenta);return d.lista;}
export async function obtenerReunion(id){const d=await local(cuenta);if(!d.paneles[id])throw new Error('Esta reunión no está preparada. Actualiza con conexión.');return d.paneles[id];}
export async function obtenerMatriz(){return (await local(cuenta)).matriz;}
export const obtenerBitacoraAsistencias=()=>remoto.obtenerBitacoraAsistencias();
export async function actuarReunion(panel,accion,datos={}){
 const id=cuenta;if(!id)throw new Error('Inicia sesión.');
 const estado=await local(id);
 if(['cerrar','anular','restaurar'].includes(accion)&&(!navigator.onLine||estado.cola.length))throw new Error('Actualiza y resuelve los pendientes antes de cerrar o cambiar la actividad.');
 if(!estado.contexto)throw new Error('Actualiza con conexión antes de registrar asistencias.');
 await local(id,d=>{
 if(d.cola.some(o=>o.reunion===panel.id&&o.error))throw new Error('Revisa los pendientes de esta reunión antes de guardar más cambios.');
 const p=d.paneles[panel.id];if(!p||p.version!==panel.version)throw new Error('La reunión cambió. Actualiza antes de guardar.');
 const op={id:crypto.randomUUID(),epoca:d.contexto.epoca,reunion:p.id,version:p.version,accion,datos,guardado:new Date().toISOString()};
 d.cola.push(op);
 if(accion==='unidad'){for(const u of datos.integrantes){const fila=p.integrantes.find(x=>x.id_usuario===u.id_usuario);if(fila)fila.estado=u.estado;}const g=p.grupos.find(g=>g.clave===datos.clave);if(g)g.revisada=true;}
 if(accion==='justificar'||accion==='celda'){const u=p.integrantes.find(u=>u.id_usuario===datos.id_usuario);if(u){u.estado=accion==='justificar'?'justificado':datos.estado;u.motivo=datos.motivo||null;}}
 // Closing/cancelling is not projected until the server confirms it.
 p.version++;for(const fila of d.matriz.filter(r=>r.reunion===p.id)){fila.version=p.version;fila.estado=p.integrantes.find(u=>u.id_usuario===fila.id_usuario)?.estado||fila.estado;}
 });
 if(navigator.onLine){
  try{await sincronizarAsistencias();await prepararAsistencias();}
  catch(e){
   // Guardar ya terminó en IndexedDB. Una caída de red no convierte ese guardado en fallo.
   await local(id,d=>{for(const op of d.cola.filter(o=>o.reunion===panel.id&&!o.error))op.error=e.message||'No se pudo conectar. Reintenta con Actualizar.';});
  }
 }
}

