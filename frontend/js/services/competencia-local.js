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
 if(p.api_version!==22)throw new Error('Actualiza Competencia con internet para renovar los datos preparados.');return d.competencia?.cola.some(o=>o.accion==='unidad_integrada'&&o.datos.reunion===reunion)?p:d.asistencias?.cola.some(o=>o.reunion===reunion)?aplicarAsistencia(p,d):p;
}
export async function guardarCompetenciaLocal(id,accion,datos){
 if(!['captura','unidad_integrada'].includes(accion)){if(!navigator.onLine)throw new Error('Conecta para cerrar puntajes o administrar Competencia.');const d=cuenta?await localCuotas(cuenta):null;if((d?.competencia?.cola.length||0)+(d?.cola.length||0)+(d?.asistencias?.cola.length||0))throw new Error('Actualiza y resuelve los pendientes antes de cerrar o administrar Competencia.');return remoto.guardarCompetencia(id,accion,datos);}
 if(!cuenta)return remoto.guardarCompetencia(id,accion,datos);
 const cuentaGuardado=cuenta;
 await localCuotas(cuentaGuardado,d=>{d.competencia ||= vacio();const c=d.competencia;if(c.cola.some(o=>o.id===id))return;if(c.cola.some(o=>o.datos.reunion===datos.reunion&&(accion!=='unidad_integrada'||o.accion!=='unidad_integrada'||o.datos.unidad===datos.unidad||o.error||o.revisar)))throw new Error('Esta unidad tiene una captura pendiente. Actualiza antes de volver a guardarla.');c.cola.push({id,accion,datos,guardado:Date.now()});const p=c.capturas[datos.reunion];if(p?.captura){p.captura.version++;if(accion==='unidad_integrada'){p.captura.version_reunion++;p.captura.guardada=true;p.captura.unidades_guardadas=[...new Set([...(p.captura.unidades_guardadas||[]),datos.unidad])];for(const pago of datos.pagos){const u=p.finanzas?.integrantes.find(u=>u.id_usuario===pago.id_usuario);if(u)u.version++;}for(const u of p.captura.integrantes){const a=datos.asistencias.find(x=>x.id_usuario===u.id_usuario);if(a)u.asistencia=a.estado;}}for(const u of p.captura.integrantes)u.cumplidos=datos.integrantes.find(x=>x.id_usuario===u.id_usuario)?.cumplidos||u.cumplidos;p.captura.extras=accion==='unidad_integrada'?[...p.captura.extras.filter(e=>e.id_usuario?!datos.integrantes.some(u=>u.id_usuario===e.id_usuario):(e.id_unidad||'sin-unidad')!==datos.unidad),...datos.extras]:datos.extras;if(c.panel?.captura?.id===datos.reunion)c.panel=structuredClone(p);} });
 if(navigator.onLine)try{await actualizarCompetenciaCompleta();}catch{/* La captura ya está guardada localmente. */}
}
async function sincronizarCuotas(id,p){
 await verificarCuenta(id);const d=await localCuotas(id),bloqueados=new Set();for(const o of d.cola){if(cuenta!==id)throw new Error('Cambió la cuenta.');if(o.revisar){if(o.accion==='cerrar')break;bloqueados.add(o.datos.id_usuario);continue;}if(bloqueados.has(o.datos.id_usuario)){await localCuotas(id,d=>{const x=d.cola.find(x=>x.id===o.id);if(x){x.revisar=true;x.error='Un pago anterior de este integrante requiere revisión.';}});continue;}try{await enviarCuota(o);await localCuotas(id,d=>{d.cola=d.cola.filter(x=>x.id!==o.id);});}catch(e){const revisar=['40001','42501','22023','23505','22P02'].includes(e.code);await localCuotas(id,d=>{const x=d.cola.find(x=>x.id===o.id);if(x){x.revisar=revisar;x.error=e.message||'Pendiente de confirmar';}});bloqueados.add(o.datos.id_usuario);if(!revisar)throw e;if(o.accion==='cerrar')break;}}
 const panel=await obtenerCuotas();if(cuenta!==id)throw new Error('Cambió la cuenta.');await localCuotas(id,d=>{d.panel=panel;d.perfil=p;d.actualizado=Date.now();});
}
export async function actualizarCompetenciaCompleta(){
 if(trabajando)return trabajando;if(!cuenta||!navigator.onLine)throw new Error('Conecta para actualizar Competencia.');const id=cuenta,p=perfil;
 trabajando=(async()=>{await verificarCuenta(id);iniciarAsistenciasLocal(id);await sincronizarAsistencias();if(cuenta!==id)throw new Error('Cambió la cuenta.');await prepararAsistencias();if(cuenta!==id)throw new Error('Cambió la cuenta.');await sincronizarCuotas(id,p);
 const d=await localCuotas(id);let huboCaptura=false;for(const o of d.competencia?.cola||[]){if(cuenta!==id)throw new Error('Cambió la cuenta.');if(o.revisar)continue;if(d.asistencias?.cola.some(x=>x.reunion===o.datos.reunion)){continue;}
 try{await remoto.guardarCompetencia(o.id,o.accion,o.datos);huboCaptura ||= o.accion==='unidad_integrada';await localCuotas(id,d=>{d.competencia.cola=d.competencia.cola.filter(x=>x.id!==o.id);});}catch(e){await localCuotas(id,d=>{const x=d.competencia.cola.find(x=>x.id===o.id);if(x){x.revisar=['40001','42501','22023','23505','22P02'].includes(e.code);x.error=e.message||'Sin confirmación';}});if(!['40001','42501','22023','23505','22P02'].includes(e.code))throw e;}}
 if(huboCaptura){if(cuenta!==id)throw new Error('Cambió la cuenta.');await prepararAsistencias();await sincronizarCuotas(id,p);}
 const panel=await remoto.obtenerCompetencia(),capturas={};for(const r of panel.reuniones){if(cuenta!==id)throw new Error('Cambió la cuenta.');capturas[r.id]=await remoto.obtenerCompetencia(r.id);}
 if(cuenta!==id)throw new Error('Cambió la cuenta.');await localCuotas(id,d=>{d.competencia ||= vacio();const c=d.competencia;for(const o of c.cola)if(c.capturas[o.datos.reunion])capturas[o.datos.reunion]=c.capturas[o.datos.reunion];c.panel=panel;c.capturas=capturas;c.actualizado=Date.now();});if(navigator.storage?.persist)await navigator.storage.persist();return localCuotas(id);
 })();try{return await trabajando;}finally{trabajando=null;}
}
export async function descartarPuntaje(idOp){await localCuotas(cuenta,d=>{d.competencia.cola=d.competencia.cola.filter(x=>x.id!==idOp);});}
