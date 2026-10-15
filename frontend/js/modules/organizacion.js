import { obtenerOrganizacion,guardarOrganizacion,subirFotoUnidad } from '../services/organizacion.js';
const $=id=>document.getElementById(id);
const css=document.createElement('link');css.rel='stylesheet';css.href=new URL('../../css/organizacion.css',import.meta.url).href;document.head.append(css);
const entrada=document.createElement('a');entrada.href='#organizacion';entrada.className='modulo';
entrada.innerHTML='<span class="modulo-icono" aria-hidden="true">◇</span><span class="sobre-titulo">EL CLUB</span><h2>Organización</h2><p>Unidades, clases y ciclos.</p><strong>Entrar al módulo →</strong>';
document.querySelector('#inicio .menu-grid').append(entrada);
const vista=document.createElement('section');vista.id='vistaOrganizacion';vista.className='vista';vista.hidden=true;
vista.innerHTML=`<span class="sobre-titulo">EL CLUB</span><h1>Organización</h1>
<div class="org-toolbar"><label>Ciclo<select id="orgCiclo"></select></label><button id="orgActualizar" class="boton-volver">Actualizar</button></div>
<p id="orgMensaje" role="status"></p><nav class="org-tabs" aria-label="Organización"><button data-tab="unidades">Unidades</button><button data-tab="clases">Clases</button><button data-tab="asignaciones">Asignaciones</button><button data-tab="ciclos">Ciclos</button></nav>
<section id="orgUnidades"><div class="org-toolbar"><h2>Unidades</h2><button id="orgNuevaUnidad" class="boton-principal">Nueva unidad</button></div><div id="orgUnidadLista" class="org-grid"></div></section>
<section id="orgClases" hidden><div class="org-toolbar"><h2>Clases</h2><button id="orgNuevaClase" class="boton-principal">Nueva clase</button></div><div id="orgClaseLista" class="org-grid"></div></section>
<section id="orgAsignaciones" hidden><h2>Asignaciones</h2><label>Buscar integrante<input id="orgBuscar" type="search" placeholder="Nombre"></label><div class="org-scroll"><table><thead><tr><th>Integrante</th><th>Cargo</th><th>Unidad</th><th>Clase</th><th></th></tr></thead><tbody id="orgMiembros"></tbody></table></div></section>
<section id="orgCiclos" class="org-panel" hidden><h2>Iniciar ciclo</h2><p>Conserva el historial. El nuevo ciclo comienza sin unidades, clases ni capitanes asignados.</p><form id="orgNuevoCiclo"><label>Año<input id="orgAnio" type="number" min="2000" max="2200" required></label><button class="boton-principal">Iniciar nuevo ciclo</button></form><p>Para consultar asignaciones anteriores, selecciona su ciclo arriba.</p></section>
<dialog id="orgDialogo"><form id="orgForm"><h2 id="orgTitulo"></h2><fieldset id="orgCampos"></fieldset><p id="orgError" role="alert"></p><div class="org-toolbar"><button type="button" id="orgCancelar" class="boton-volver">Cancelar</button><button class="boton-principal">Guardar</button></div></form></dialog>`;
$('aplicacion').append(vista);
let panel,perfil,revision=0,ocupado=false,editando=null,sucio=false,tab='unidades',alCambiar,antesDeCiclo;
const admin=()=>panel?.rol==='directiva';
const puedeAdministrar=()=>admin()&&panel?.vigente;
const crear=(tag,texto)=>{const e=document.createElement(tag);e.textContent=texto??'';return e;};
const btn=(texto,fn)=>{const e=crear('button',texto);e.type='button';e.className='boton-volver';e.onclick=fn;return e;};
function mensaje(t){$('orgMensaje').textContent=t;}
function bloquear(v){ocupado=v;vista.querySelectorAll('button,select,input,textarea').forEach(e=>e.disabled=v);}
export function puedeSalirOrganizacion(){return !ocupado&&(!sucio||confirm('Hay cambios sin guardar. ¿Salir?'));}
export function reiniciarOrganizacion(){revision++;panel=null;perfil=null;editando=null;sucio=false;ocupado=false;tab='unidades';$('orgDialogo').close();for(const id of ['orgUnidadLista','orgClaseLista','orgMiembros','orgCampos','orgMensaje','orgCiclo'])$(id).replaceChildren();}
async function cargar(ciclo=null){const rev=++revision;bloquear(true);try{const p=await obtenerOrganizacion(ciclo);if(rev!==revision)return;panel=p;pintar();mensaje(panel.vigente?'':'Archivo · Solo lectura');}catch(e){if(rev===revision)mensaje(e.message||'No se pudo cargar Organización.');}finally{if(rev===revision)bloquear(false);}}
export async function abrirOrganizacion(p,callback,comprobarCiclo){perfil=p;alCambiar=callback;antesDeCiclo=comprobarCiclo;await cargar();}
function pestañas(){for(const t of ['unidades','clases','asignaciones','ciclos']){const b=vista.querySelector(`[data-tab="${t}"]`);b.hidden=['asignaciones','ciclos'].includes(t)&&!admin();b.setAttribute('aria-pressed',String(tab===t));$(`org${t[0].toUpperCase()+t.slice(1)}`).hidden=tab!==t;} $('orgNuevoCiclo').hidden=!puedeAdministrar();}
function pintar(){
 $('orgCiclo').replaceChildren(...panel.ciclos.map(c=>{const o=crear('option',`${c.anio}${c.es_activo?' · Actual':''}`);o.value=c.id_ciclo;return o;}));$('orgCiclo').value=panel.id_ciclo;
 $('orgNuevaUnidad').hidden=$('orgNuevaClase').hidden=!puedeAdministrar();
 $('orgAnio').value=Math.max(...panel.ciclos.map(c=>c.anio))+1;
 for(const tipo of ['unidad','clase']){
 const lista=tipo==='unidad'?panel.unidades:panel.clases,contenedor=$(tipo==='unidad'?'orgUnidadLista':'orgClaseLista');contenedor.replaceChildren();
 for(const grupo of lista){
 const id=grupo[tipo==='unidad'?'id_unidad':'id_clase'];const miembros=panel.integrantes.filter(u=>u[tipo==='unidad'?'id_unidad':'id_clase']===id&&u.activo);
 const card=crear('article');card.className='org-panel';
 if(tipo==='unidad'&&grupo.foto){const img=document.createElement('img');img.src=grupo.foto;img.alt=`Unidad ${grupo.nombre}`;img.className='org-foto';card.append(img);}
 card.append(crear('h3',grupo.nombre),crear('small',grupo.es_activa?'':'Inactiva'));
 if(tipo==='unidad'){card.append(crear('p',grupo.lema));if(grupo.porra){const d=crear('details');d.append(crear('summary','Porra'),crear('p',grupo.porra));card.append(d);}}
 else if(grupo.color_distintivo)card.append(crear('p',grupo.color_distintivo));
 const miembrosLista=crear('ul');for(const u of miembros){const li=crear('li',`${u.nombre} · ${etiquetaRol(u.rol)}`);miembrosLista.append(li);}card.append(miembrosLista);
 if(!miembros.length)card.append(crear('p','Sin integrantes'));
 if(puedeAdministrar()||(tipo==='unidad'&&panel.vigente&&grupo.editable))card.append(btn('Editar',()=>editar(tipo,grupo)));
 if(puedeAdministrar())card.append(btn(grupo.es_activa?'Desactivar':'Reactivar',()=>cambiarEstado(tipo,grupo)));
 contenedor.append(card);
 }
 if(!lista.length)contenedor.append(crear('p',tipo==='unidad'?'Aún no hay unidades en este ciclo.':'Aún no hay clases.'));
 }
 pintarMiembros();pestañas();
}
function etiquetaRol(r){return {directiva:'Directiva',consejero:'Consejero',capitan:'Capitán',subcapitan:'Subcapitán',conquistador:'Conquistador'}[r]||r;}
function pintarMiembros(){if(!panel)return;$('orgMiembros').replaceChildren();const q=$('orgBuscar').value.toLocaleLowerCase('es');
 for(const u of panel.integrantes.filter(u=>u.nombre.toLocaleLowerCase('es').includes(q))){const tr=crear('tr');tr.append(crear('th',u.nombre+(u.activo?'':' · Inactivo')),crear('td',etiquetaRol(u.rol)),crear('td',panel.vigente?panel.unidades.find(x=>x.id_unidad===u.id_unidad)?.nombre||'—':u.unidad||'—'),crear('td',panel.vigente?panel.clases.find(x=>x.id_clase===u.id_clase)?.nombre||'—':u.clase||'—'));
 const td=crear('td');if(puedeAdministrar()&&u.rol!=='directiva')td.append(btn('Asignar',()=>editar('asignar',u)));tr.append(td);$('orgMiembros').append(tr);}}
function campo(nombre,titulo,valor='',tipo='text',opciones=null){const label=crear('label',titulo),e=document.createElement(opciones?'select':tipo==='textarea'?'textarea':'input');e.name=nombre;
 if(opciones){for(const [id,t] of opciones){const o=crear('option',t);o.value=id;e.append(o);}}else if(tipo!=='textarea')e.type=tipo;
 e.value=valor??'';label.append(e);$('orgCampos').append(label);return e;}
function editar(tipo,g={}){
 if(ocupado)return;editando={tipo,g};sucio=false;$('orgCampos').replaceChildren();$('orgError').textContent='';$('orgTitulo').textContent=tipo==='asignar'?g.nombre:tipo==='unidad'?'Unidad':'Clase';
 if(tipo==='asignar'){
 campo('rol','Cargo',g.rol,'text',['conquistador','consejero','capitan','subcapitan'].map(r=>[r,etiquetaRol(r)]));
 campo('unidad','Unidad',g.id_unidad,'text',[['','Sin unidad'],...panel.unidades.filter(u=>u.es_activa).map(u=>[u.id_unidad,u.nombre])]);
 campo('clase','Clase',g.id_clase,'text',[['','Sin clase'],...panel.clases.filter(c=>c.es_activa).map(c=>[c.id_clase,c.nombre])]);
 }else{
 if(admin()){const n=campo('nombre','Nombre',g.nombre);n.required=true;n.maxLength=100;}
 if(tipo==='unidad'){
 campo('lema','Lema',g.lema).maxLength=255;campo('porra','Porra',g.porra,'textarea').maxLength=5000;
 if(g.id_unidad){const f=campo('foto','Foto grupal','','file');f.accept='image/jpeg,image/png,image/webp';if(g.foto_path){const quitar=campo('quitar','Quitar foto','','checkbox');quitar.value='si';}}
 }else campo('color','Color distintivo',g.color_distintivo).maxLength=50;
 }
 $('orgDialogo').showModal();$('orgCampos').querySelector('input,select,textarea')?.focus();
}
async function ejecutar(accion,datos){await guardarOrganizacion(accion,{id_ciclo:panel.id_ciclo,...datos});await alCambiar?.();}
async function cambiarEstado(tipo,g){if(!confirm(`¿${g.es_activa?'Desactivar':'Reactivar'} ${g.nombre}?`))return;bloquear(true);try{await ejecutar(`estado_${tipo}`,{id:g[tipo==='unidad'?'id_unidad':'id_clase'],version:g.version,activo:!g.es_activa});await cargar(panel.id_ciclo);}catch(e){mensaje(e.message);}finally{bloquear(false);}}
$('orgForm').oninput=()=>{sucio=true;};
$('orgForm').onsubmit=async e=>{e.preventDefault();if(ocupado||!editando)return;const rev=revision,{tipo,g}=editando,fd=new FormData(e.target);bloquear(true);
 try{
 const datos=Object.fromEntries([...fd].filter(([k])=>!['foto','quitar'].includes(k)));datos.id=(tipo==='asignar'?g.id_usuario:tipo==='unidad'?g.id_unidad:g.id_clase)||crypto.randomUUID();datos.version=g.version??null;
 if(tipo==='unidad'){datos.foto_path=fd.get('quitar')?null:g.foto_path||null;const f=fd.get('foto');if(f?.size)datos.foto_path=await subirFotoUnidad(datos.id,f);}
 await ejecutar(tipo==='unidad'&&!admin()?'identidad':tipo,datos);
 if(rev!==revision)return;editando=null;sucio=false;$('orgDialogo').close();await cargar(panel.id_ciclo);
 }catch(err){if(rev===revision)$('orgError').textContent=err.message;}finally{if(rev===revision)bloquear(false);}
};
$('orgCancelar').onclick=()=>{if(sucio&&!confirm('¿Descartar los cambios?'))return;editando=null;sucio=false;$('orgDialogo').close();};
$('orgDialogo').addEventListener('cancel',e=>{if(ocupado||(sucio&&!confirm('¿Descartar los cambios?')))e.preventDefault();else{editando=null;sucio=false;}});
$('orgNuevaUnidad').onclick=()=>editar('unidad');$('orgNuevaClase').onclick=()=>editar('clase');$('orgBuscar').oninput=pintarMiembros;
$('orgActualizar').onclick=()=>cargar(panel?.id_ciclo);$('orgCiclo').onchange=()=>cargar($('orgCiclo').value);
for(const b of vista.querySelectorAll('[data-tab]'))b.onclick=()=>{tab=b.dataset.tab;pestañas();};
$('orgNuevoCiclo').onsubmit=async e=>{e.preventDefault();if(ocupado)return;const anio=Number($('orgAnio').value);
 if(!confirm(`¿Iniciar el ciclo ${anio}? Se conservará el historial y se retirarán las asignaciones actuales de unidad, clase y capitanía. Sincroniza antes los pagos de todos los dispositivos.`))return;
 bloquear(true);try{await antesDeCiclo?.();await ejecutar('ciclo',{anio});tab='unidades';await cargar();}catch(err){mensaje(err.message);}finally{bloquear(false);}
};
window.addEventListener('beforeunload',e=>{if(sucio){e.preventDefault();e.returnValue='';}});
