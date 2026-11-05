const menu=document.getElementById('panelMenu');
const lateral=document.getElementById('panelLateral');
function abrir(valor){document.body.classList.toggle('panel-abierto',valor);menu.setAttribute('aria-expanded',String(valor));menu.setAttribute('aria-label',valor?'Cerrar menú':'Abrir menú');if(valor)document.getElementById('panelBuscar').focus();}
menu.onclick=()=>abrir(menu.getAttribute('aria-expanded')!=='true');
document.getElementById('panelSombra').onclick=()=>abrir(false);
lateral.addEventListener('click',e=>{if(e.target.closest('a'))abrir(false);});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&menu.getAttribute('aria-expanded')==='true'){abrir(false);menu.focus();}});
document.getElementById('panelBuscar').oninput=e=>{const q=e.target.value.toLocaleLowerCase('es');lateral.querySelectorAll('nav a').forEach(a=>{a.hidden=!a.textContent.toLocaleLowerCase('es').includes(q);});};
export function actualizarPanel(ruta){const actual=/^(perfil|editar|registrar|integrantes|consultar)/.test(ruta)?'comunidad':ruta.split('/')[0];lateral.querySelectorAll('[data-panel-ruta]').forEach(a=>{if(a.dataset.panelRuta===actual)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});abrir(false);}
