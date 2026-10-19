import * as remoto from './competencia.js';
import {localCuotas} from '../lib/cuotas-local.js';
import {obtenerCuotas,enviarCuota,verificarCuenta} from './cuotas.js';
import {iniciarAsistenciasLocal,sincronizarAsistencias,prepararAsistencias} from './asistencias-offline.js';
let cuenta=null,perfil=null,trabajando=null;
export function iniciarCompetenciaLocal(id,p){cuenta=id;perfil=p;}
export const pendientesPuntajes=async id=>id?((await localCuotas(id)).competencia?.cola||[]).length:0;
export async function estadoCompetenciaLocal(){if(!cuenta)return null;return localCuotas(cuenta);}
function vacio(){return {cola:[],panel:null,capturas:{},actualizado:null};}
function aplicarAsistencia(p,d){if(!p?.captura||p.captura.cerrada)return p;const a=d.asistencias?.paneles[p.captura.id];if(!a)return p;p.captura.version_reunion=a.version;for(const u of p.captura.integrantes){const fila=a.integrantes.find(x=>x.id_usuario===u.id_usuario);const g=a.grupos.find(g=>g.clave===(u.id_unidad||'sin-unidad'));if(fila&&(a.estado==='cerrada'||g?.revisada)){u.asistencia=fila.estado;u.cumplidos=u.asistencia==='asistencia'?u.cumplidos:[];for(const k of p.captura.criterios.filter(k=>k.fuente==='asistencia')){u.automaticos=u.automaticos.filter(id=>id!==k.id);if(u.asistencia==='asistencia'||u.asistencia==='justificado'&&p.captura.justificados)u.automaticos.push(k.id);}}}return p;}
export async function obtenerCompetenciaLocal(reunion=null,desde=null,hasta=null){
 if(!cuenta)return remoto.obtenerCompetencia(reunion,desde,hasta);
 const id=cuenta,d=await localCuotas(id);if(navigator.onLine&&!(d.competencia?.cola||[]).length){const p=await remoto.obtenerCompetencia(reunion,desde,hasta);if(cuenta!==id)throw new Error('Cambió la cuenta.');await localCuotas(id,d=>{d.competencia ||= vacio();d.competencia.panel=p;if(reunion)d.competencia.capturas[reunion]=p;d.competencia.actualizado=Date.now();});return p;}
 const p=structuredClone(reunion?d.competencia?.capturas[reunion]:d.competencia?.panel);if(!p)throw new Error('Actualiza Competencia con internet para preparar esta reunión.');
 return aplicarAsistencia(p,d);
}
export async function guardarCompetenciaLocal(id,accion,datos){
 if(accion!=='captura'){if(!navigator.onLine)throw new Error('Conecta para administrar periodos o criterios.');if(await pendientesPuntajes(cuenta))throw new Error('Sincroniza los puntajes pendientes antes de administrar.');return remoto.guardarCompetencia(id,accion,datos);}
 if(!cuenta)return remoto.guardarCompetencia(id,accion,datos);
 const cuentaGuardado=cuenta;
 await localCuotas(cuentaGuardado,d=>{d.competencia ||= vacio();const c=d.competencia;if(c.cola.some(o=>o.id===id))return;if(c.cola.some(o=>o.datos.reunion===datos.reunion))throw new Error('Esta reunión tiene un puntaje pendiente. Actualiza antes de volver a guardarlo.');c.cola.push({id,accion,datos,guardado:Date.now()});const p=c.capturas[datos.reunion];if(p?.captura){p.captura.version++;for(const u of p.captura.integrantes)u.cumplidos=datos.integrantes.find(x=>x.id_usuario===u.id_usuario).cumplidos;p.captura.extras=datos.extras;} });
 if(navigator.onLine)try{await actualizarCompetenciaCompleta();}catch{/* La captura ya está guardada localmente. */}
}
async function sincronizarCuotas(id,p){
 await verificarCuenta(id);const d=await localCuotas(id),bloqueados=new Set();for(const o of d.cola){if(cuenta!==id)throw new Error('Cambió la cuenta.');if(o.revisar){if(o.accion==='cerrar')break;bloqueados.add(o.datos.id_usuario);continue;}if(bloqueados.has(o.datos.id_usuario)){await localCuotas(id,d=>{const x=d.cola.find(x=>x.id===o.id);if(x){x.revisar=true;x.error='Un pago anterior de este integrante requiere revisión.';}});continue;}try{await enviarCuota(o);await localCuotas(id,d=>{d.cola=d.cola.filter(x=>x.id!==o.id);});}catch(e){const revisar=['40001','42501','22023','23505','22P02'].includes(e.code);await localCuotas(id,d=>{const x=d.cola.find(x=>x.id===o.id);if(x){x.revisar=revisar;x.error=e.message||'Pendiente de confirmar';}});bloqueados.add(o.datos.id_usuario);if(!revisar)throw e;if(o.accion==='cerrar')break;}}
 const panel=await obtenerCuotas();if(cuenta!==id)throw new Error('Cambió la cuenta.');await localCuotas(id,d=>{d.panel=panel;d.perfil=p;d.actualizado=Date.now();});
}
export async function actualizarCompetenciaCompleta(){
 if(trabajando)return trabajando;if(!cuenta||!navigator.onLine)throw new Error('Conecta para actualizar Competencia.');const id=cuenta,p=perfil;
 trabajando=(async()=>{await verificarCuenta(id);iniciarAsistenciasLocal(id);await sincronizarAsistencias();if(cuenta!==id)throw new Error('Cambió la cuenta.');await prepararAsistencias();if(cuenta!==id)throw new Error('Cambió la cuenta.');await sincronizarCuotas(id,p);
 const d=await localCuotas(id);for(const o of d.competencia?.cola||[]){if(cuenta!==id)throw new Error('Cambió la cuenta.');if(o.revisar)continue;if(d.asistencias?.cola.some(x=>x.reunion===o.datos.reunion)){continue;}
 try{await remoto.guardarCompetencia(o.id,o.accion,o.datos);await localCuotas(id,d=>{d.competencia.cola=d.competencia.cola.filter(x=>x.id!==o.id);});}catch(e){await localCuotas(id,d=>{const x=d.competencia.cola.find(x=>x.id===o.id);if(x){x.revisar=['40001','42501','22023','23505','22P02'].includes(e.code);x.error=e.message||'Sin confirmación';}});if(!['40001','42501','22023','23505','22P02'].includes(e.code))throw e;}}
 const panel=await remoto.obtenerCompetencia(),capturas={};for(const r of panel.reuniones){if(cuenta!==id)throw new Error('Cambió la cuenta.');capturas[r.id]=await remoto.obtenerCompetencia(r.id);}
 if(cuenta!==id)throw new Error('Cambió la cuenta.');await localCuotas(id,d=>{d.competencia ||= vacio();const c=d.competencia;for(const o of c.cola)if(c.capturas[o.datos.reunion])capturas[o.datos.reunion]=c.capturas[o.datos.reunion];c.panel=panel;c.capturas=capturas;c.actualizado=Date.now();});if(navigator.storage?.persist)await navigator.storage.persist();return localCuotas(id);
 })();try{return await trabajando;}finally{trabajando=null;}
}
export async function descartarPuntaje(idOp){await localCuotas(cuenta,d=>{d.competencia.cola=d.competencia.cola.filter(x=>x.id!==idOp);});}
