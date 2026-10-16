let colores=new Map();
export function colorHex(valor){return /^#[0-9a-f]{6}$/i.test(valor||'')?valor:null;}
export function configurarColores(filas){colores=new Map(filas.map(u=>[u.id_usuario,colorHex(u.color_clase)]));document.querySelectorAll('[data-color-integrante]').forEach(n=>colorearNombre(n,n.dataset.colorIntegrante));}
export function colorearNombre(nodo,id){nodo.dataset.colorIntegrante=id;nodo.style.color=colores.get(id)||'';return nodo;}
