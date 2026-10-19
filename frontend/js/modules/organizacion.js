import {obtenerPuntajeUnidad} from '../services/competencia.js';
import {colorearNombre,colorHex,colorearAvatar,ordenarIntegrantes} from '../lib/colores.js';
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
<section id="orgUnidades"><div id="orgUnidadCabecera" class="org-toolbar"><h2>Unidades</h2><button id="orgNuevaUnidad" class="boton-principal">Nueva unidad</button></div><div id="orgUnidadLista" class="org-grid"></div><section id="orgUnidadPerfil" hidden></section></section>
<section id="orgClases" hidden><div id="orgClaseCabecera" class="org-toolbar"><h2>Clases</h2><button id="orgNuevaClase" class="boton-principal">Nueva clase</button></div><div id="orgClaseLista" class="org-grid"></div><section id="orgClasePerfil" hidden></section></section>
<section id="orgAsignaciones" hidden><h2>Asignaciones</h2><label>Buscar integrante<input id="orgBuscar" type="search" placeholder="Nombre"></label><div class="org-scroll"><table><thead><tr><th>Integrante</th><th>Cargo</th><th>Unidad</th><th>Clase</th><th></th></tr></thead><tbody id="orgMiembros"></tbody></table></div></section>
<section id="orgCiclos" class="org-panel" hidden><h2>Iniciar ciclo</h2><p>Conserva el historial. El nuevo ciclo comienza sin unidades, clases ni capitanes asignados.</p><form id="orgNuevoCiclo"><label>Año<input id="orgAnio" type="number" min="2000" max="2200" required></label><button class="boton-principal">Iniciar nuevo ciclo</button></form><p>Para consultar asignaciones anteriores, selecciona su ciclo arriba.</p></section>
<dialog id="orgDialogo"><form id="orgForm"><h2 id="orgTitulo"></h2><fieldset id="orgCampos"></fieldset><p id="orgError" role="alert"></p><div class="org-toolbar"><button type="button" id="orgCancelar" class="boton-volver">Cancelar</button><button class="boton-principal">Guardar</button></div></form></dialog>`;
$('aplicacion').append(vista);
let panel,perfil,revision=0,ocupado=false,editando=null,sucio=false,tab='unidades',unidadSeleccionada=null,claseSeleccionada=null,alCambiar,antesDeCiclo;
const admin=()=>panel?.rol==='directiva';
const puedeAdministrar=()=>admin()&&panel?.vigente;
const crear=(tag,texto)=>{const e=document.createElement(tag);e.textContent=texto??'';return e;};
const btn=(texto,fn)=>{const e=crear('button',texto);e.type='button';e.className='boton-volver';e.onclick=fn;return e;};
function mensaje(t){$('orgMensaje').textContent=t;}
function bloquear(v){ocupado=v;vista.querySelectorAll('button,select,input,textarea').forEach(e=>e.disabled=v);}
export function puedeSalirOrganizacion(){return !ocupado&&(!sucio||confirm('Hay cambios sin guardar. ¿Salir?'));}
export function reiniciarOrganizacion(){revision++;panel=null;perfil=null;editando=null;sucio=false;ocupado=false;tab='unidades';unidadSeleccionada=null;claseSeleccionada=null;$('orgClasePerfil').replaceChildren();$('orgUnidadPerfil').replaceChildren();$('orgDialogo').close();for(const id of ['orgUnidadLista','orgClaseLista','orgMiembros','orgCampos','orgMensaje','orgCiclo'])$(id).replaceChildren();}
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
 const id=grupo[tipo==='unidad'?'id_unidad':'id_clase'];const miembros=panel.integrantes.filter(u=>u[tipo==='unidad'?'id_unidad':'id_clase']===id&&u.activo&&u.rol!=='directiva');
 if(tipo==='unidad'){
 const card=crear('article');card.className='org-unidad-card';
 const abrir=btn('',()=>{unidadSeleccionada=id;pintarPerfilUnidad();$('orgPerfilNombre').focus();});abrir.className='org-unidad-enlace';
 abrir.append(avatarUnidad(grupo));const texto=crear('span');texto.className='org-unidad-texto';texto.append(crear('strong',grupo.nombre),crear('small',grupo.es_activa?`${miembros.length} integrantes`:'Inactiva'));abrir.append(texto,crear('span','→'));abrir.setAttribute('aria-label',`Ver perfil de ${grupo.nombre}`);card.append(abrir);contenedor.append(card);continue;
 }
 const card=crear('article');card.className='org-unidad-card';const abrir=btn('',()=>{claseSeleccionada=id;pintarPerfilClase();$('orgClaseNombre').focus();});abrir.className='org-unidad-enlace';
 const avatar=avatarUnidad(grupo);avatar.style.background=colorHex(grupo.color_distintivo)||'';const texto=crear('span');texto.className='org-unidad-texto';texto.append(crear('strong',grupo.nombre),crear('small',grupo.es_activa?`${miembros.length} integrantes`:'Inactiva'));abrir.append(avatar,texto,crear('span','→'));abrir.setAttribute('aria-label',`Ver clase ${grupo.nombre}`);card.append(abrir);contenedor.append(card);

 }
 if(!lista.length)contenedor.append(crear('p',tipo==='unidad'?'Aún no hay unidades en este ciclo.':'Aún no hay clases.'));
 }
 pintarMiembros();pintarPerfilUnidad();pintarPerfilClase();pestañas();
}
function avatarUnidad(grupo){
 const avatar=crear('span');avatar.className='org-unidad-avatar';
 if(grupo.foto){const img=document.createElement('img');img.src=grupo.foto;img.alt='';img.onerror=()=>{avatar.replaceChildren(crear('span',grupo.nombre.slice(0,2).toUpperCase()));};avatar.append(img);}
 else avatar.textContent=grupo.nombre.slice(0,2).toUpperCase();
 avatar.setAttribute('aria-hidden','true');return avatar;
}
function pintarPerfilUnidad(){
 const grupo=panel?.unidades.find(u=>u.id_unidad===unidadSeleccionada);
 if(!grupo)unidadSeleccionada=null;
 $('orgUnidadLista').hidden=$('orgUnidadCabecera').hidden=Boolean(grupo);$('orgUnidadPerfil').hidden=!grupo;$('orgUnidadPerfil').replaceChildren();
 if(!grupo)return;
 const perfilUnidad=$('orgUnidadPerfil');
 perfilUnidad.append(btn('← Unidades',()=>{unidadSeleccionada=null;pintarPerfilUnidad();document.querySelector('#orgUnidadLista button')?.focus();}));
 const encabezado=crear('div');encabezado.className='org-perfil-cabecera org-panel';encabezado.append(avatarUnidad(grupo));
 const identidad=crear('div');identidad.className='org-perfil-identidad';const nombre=crear('h2',grupo.nombre);nombre.id='orgPerfilNombre';nombre.tabIndex=-1;identidad.append(nombre);
 if(!grupo.es_activa)identidad.append(crear('small','Inactiva'));
 if(grupo.lema)identidad.append(crear('p',grupo.lema));encabezado.append(identidad);
 const acciones=crear('div');acciones.className='org-perfil-acciones';
 if(puedeAdministrar()||(panel.vigente&&grupo.editable)){const editarUnidad=btn('Editar unidad',()=>editar('unidad',grupo));editarUnidad.id='orgEditarUnidad';acciones.append(editarUnidad);}
 if(puedeAdministrar())acciones.append(btn(grupo.es_activa?'Desactivar':'Reactivar',()=>cambiarEstado('unidad',grupo)));
 encabezado.append(acciones);perfilUnidad.append(encabezado);
 const columnas=crear('div');columnas.className='org-perfil-columnas';
 const asistencia=crear('section');asistencia.className='org-panel org-unidad-asistencia';asistencia.append(crear('h3','Asistencia de la unidad'));
 const datos=grupo.asistencia;const porcentaje=crear('strong',datos?.total?`${datos.porcentaje}%`:'—');porcentaje.id='orgPorcentajeUnidad';asistencia.append(porcentaje);
 if(datos?.total){const barra=document.createElement('progress');barra.max=100;barra.value=datos.porcentaje;barra.setAttribute('aria-label','Porcentaje de asistencia de la unidad');asistencia.append(barra);
 const cifras=crear('div');cifras.className='org-asistencia-cifras';for(const [clave,nombre] of [['asistencias','Asistencias'],['justificados','Justificados'],['faltas','Faltas']]){const item=crear('div');item.append(crear('strong',datos[clave]),crear('span',nombre));cifras.append(item);}asistencia.append(cifras);
 asistencia.title='Asistencias y justificados / registros de reuniones cerradas del ciclo. Se conserva la unidad de cada pase.';
 }else asistencia.append(crear('p',datos?'Sin reuniones cerradas':'Asistencia no disponible'));
 columnas.append(asistencia);const puntos=crear('section');puntos.className='org-panel';const rev=revision;void obtenerPuntajeUnidad(grupo.id_unidad).then(p=>{if(!p||rev!==revision||unidadSeleccionada!==grupo.id_unidad)return;puntos.append(crear('h3',p.nombre),crear('strong',`${p.puntos} puntos`));columnas.append(puntos);}).catch(()=>{});
 const porra=crear('section');porra.className='org-panel org-porra';porra.append(crear('h3','Porra'),crear('p',grupo.porra||'Sin porra'));columnas.append(porra);perfilUnidad.append(columnas);
 const integrantes=crear('section');integrantes.className='org-panel';integrantes.append(crear('h3','Integrantes'));
 const lista=crear('div');lista.className='org-miembros-perfil';
 for(const u of panel.integrantes.filter(u=>u.id_unidad===grupo.id_unidad&&u.activo&&u.rol!=='directiva').sort(ordenarIntegrantes)){
 const a=crear('a');a.href=`#perfil/${u.id_usuario}`;a.className='org-miembro';const avatar=crear('span',u.nombre.split(/\s+/).slice(0,2).map(n=>n[0]).join(''));avatar.className='org-miembro-avatar';colorearAvatar(avatar,u.id_usuario,u);avatar.setAttribute('aria-hidden','true');const texto=crear('span');texto.append(colorearNombre(crear('strong',u.nombre),u.id_usuario),crear('small',etiquetaRol(u.rol)));a.append(avatar,texto);lista.append(a);
 }
 if(!lista.children.length)lista.append(crear('p','Sin integrantes'));integrantes.append(lista);perfilUnidad.append(integrantes);
}
function etiquetaRol(r){return {directiva:'Directiva',consejero:'Consejero',capitan:'Capitán',subcapitan:'Subcapitán',conquistador:'Conquistador'}[r]||r;}
function pintarMiembros(){if(!panel)return;$('orgMiembros').replaceChildren();const q=$('orgBuscar').value.toLocaleLowerCase('es');
 for(const u of panel.integrantes.filter(u=>u.nombre.toLocaleLowerCase('es').includes(q)).sort(ordenarIntegrantes)){const tr=crear('tr');tr.append(colorearNombre(crear('th',u.nombre+(u.activo?'':' · Inactivo')),u.id_usuario),crear('td',etiquetaRol(u.rol)),crear('td',panel.vigente?panel.unidades.find(x=>x.id_unidad===u.id_unidad)?.nombre||'—':u.unidad||'—'),crear('td',panel.vigente?panel.clases.find(x=>x.id_clase===u.id_clase)?.nombre||'—':u.clase||'—'));
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
 }else {
 const valor=colorHex(g.color_distintivo)||'#302ca0';const hex=campo('color','Color hexadecimal',valor);hex.pattern='#[0-9A-Fa-f]{6}';hex.maxLength=7;hex.required=true;
 const selector=campo('selector','Elegir color',valor,'color');selector.oninput=()=>{hex.value=selector.value;};hex.oninput=()=>{if(colorHex(hex.value))selector.value=hex.value;};
 }
 }
 $('orgDialogo').showModal();$('orgCampos').querySelector('input,select,textarea')?.focus();
}
async function ejecutar(accion,datos){await guardarOrganizacion(accion,{id_ciclo:panel.id_ciclo,...datos});await alCambiar?.();}
async function cambiarEstado(tipo,g){if(!confirm(`¿${g.es_activa?'Desactivar':'Reactivar'} ${g.nombre}?`))return;bloquear(true);try{await ejecutar(`estado_${tipo}`,{id:g[tipo==='unidad'?'id_unidad':'id_clase'],version:g.version,activo:!g.es_activa});await cargar(panel.id_ciclo);}catch(e){mensaje(e.message);}finally{bloquear(false);}}
$('orgForm').oninput=()=>{sucio=true;};
$('orgForm').onsubmit=async e=>{e.preventDefault();if(ocupado||!editando)return;const rev=revision,{tipo,g}=editando,fd=new FormData(e.target);bloquear(true);
 try{
 const datos=Object.fromEntries([...fd].filter(([k])=>!['foto','quitar','selector'].includes(k)));datos.id=(tipo==='asignar'?g.id_usuario:tipo==='unidad'?g.id_unidad:g.id_clase)||crypto.randomUUID();datos.version=g.version??null;
 if(tipo==='unidad'){datos.foto_path=fd.get('quitar')?null:g.foto_path||null;const f=fd.get('foto');if(f?.size)datos.foto_path=await subirFotoUnidad(datos.id,f);}
 await ejecutar(tipo==='unidad'&&!admin()?'identidad':tipo,datos);
 if(rev!==revision)return;editando=null;sucio=false;$('orgDialogo').close();await cargar(panel.id_ciclo);
 }catch(err){if(rev===revision)$('orgError').textContent=err.message;}finally{if(rev===revision)bloquear(false);}
};
$('orgCancelar').onclick=()=>{if(sucio&&!confirm('¿Descartar los cambios?'))return;editando=null;sucio=false;$('orgDialogo').close();};
$('orgDialogo').addEventListener('cancel',e=>{if(ocupado||(sucio&&!confirm('¿Descartar los cambios?')))e.preventDefault();else{editando=null;sucio=false;}});
$('orgNuevaUnidad').onclick=()=>editar('unidad');$('orgNuevaClase').onclick=()=>editar('clase');$('orgBuscar').oninput=pintarMiembros;
$('orgActualizar').onclick=()=>cargar(panel?.id_ciclo);$('orgCiclo').onchange=()=>{unidadSeleccionada=null;claseSeleccionada=null;cargar($('orgCiclo').value);};
for(const b of vista.querySelectorAll('[data-tab]'))b.onclick=()=>{tab=b.dataset.tab;pestañas();};
$('orgNuevoCiclo').onsubmit=async e=>{e.preventDefault();if(ocupado)return;const anio=Number($('orgAnio').value);
 if(!confirm(`¿Iniciar el ciclo ${anio}? Se conservará el historial y se retirarán las asignaciones actuales de unidad, clase y capitanía. Sincroniza antes las cuotas y asistencias de todos los dispositivos.`))return;
 bloquear(true);try{await antesDeCiclo?.();await ejecutar('ciclo',{anio});tab='unidades';await cargar();}catch(err){mensaje(err.message);}finally{bloquear(false);}
};
window.addEventListener('beforeunload',e=>{if(sucio){e.preventDefault();e.returnValue='';}});

function pintarPerfilClase(){
 const clase=panel?.clases.find(c=>c.id_clase===claseSeleccionada);if(!clase)claseSeleccionada=null;
 $('orgClaseLista').hidden=$('orgClaseCabecera').hidden=Boolean(clase);const destino=$('orgClasePerfil');destino.hidden=!clase;destino.replaceChildren();if(!clase)return;
 destino.append(btn('← Clases',()=>{claseSeleccionada=null;pintarPerfilClase();document.querySelector('#orgClaseLista button')?.focus();}));
 const cabecera=crear('div');cabecera.className='org-perfil-cabecera org-panel';const avatar=avatarUnidad(clase);avatar.style.background=colorHex(clase.color_distintivo)||'';cabecera.append(avatar);const nombre=crear('h2',clase.nombre);nombre.id='orgClaseNombre';nombre.tabIndex=-1;cabecera.append(nombre);
 if(puedeAdministrar()){const editarClase=btn('Editar clase',()=>editar('clase',clase));editarClase.id='orgEditarClase';cabecera.append(editarClase,btn(clase.es_activa?'Desactivar':'Reactivar',()=>cambiarEstado('clase',clase)));}destino.append(cabecera);
 const miembros=crear('section');miembros.className='org-panel';miembros.append(crear('h3','Integrantes'));const lista=crear('div');lista.className='org-miembros-perfil';
 for(const u of panel.integrantes.filter(u=>u.id_clase===clase.id_clase&&u.activo&&u.rol!=='directiva').sort(ordenarIntegrantes)){const a=crear('a');a.className='org-miembro';a.href=`#perfil/${u.id_usuario}`;const texto=crear('span');texto.append(colorearNombre(crear('strong',u.nombre),u.id_usuario),crear('small',etiquetaRol(u.rol)));a.append(texto);lista.append(a);}
 if(!lista.children.length)lista.append(crear('p','Sin integrantes'));miembros.append(lista);destino.append(miembros);
}
