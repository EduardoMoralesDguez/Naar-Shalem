// Controles de captura por reunión. Los importes siempre se envían en centavos.
export function controlesReunion(panel,captura,alCambiar){
 const pagos=new Map(),estados=new Map(captura.integrantes.map(u=>[u.id_usuario,u.asistencia]));
 const periodo=panel.finanzas?.periodos.find(p=>p.id===panel.periodo_cuota);
 return {
 estados,pagos,periodo,
 asistencia(u){const select=document.createElement('select');select.setAttribute('aria-label','Asistencia: '+u.nombre);for(const [valor,texto] of [['','Pendiente'],['asistencia','A'],['justificado','J'],['falta','F']])select.add(new Option(texto,valor));select.value=u.asistencia||'';select.disabled=captura.cerrada;select.onchange=()=>{estados.set(u.id_usuario,select.value);u.asistencia=select.value||null;alCambiar(u);};return select;},
 cuota(u){const span=document.createElement('div');const cargo=panel.finanzas?.cargos.find(c=>c.id_usuario===u.id_usuario&&c.periodo===periodo?.id);if(!cargo){span.textContent='—';return span;}const label=document.createElement('label'),input=document.createElement('input');input.type='number';input.min='0';input.max='100000';input.step='0.01';input.value='0';input.disabled=captura.cerrada;input.setAttribute('aria-label','Dinero recibido: '+u.nombre);input.oninput=()=>{pagos.set(u.id_usuario,Math.round(Number(input.value)*100));alCambiar();};label.append('Recibí $',input);const detalle=document.createElement('small');detalle.textContent=`Aplicado: $${(cargo.pagado/100).toFixed(2)}`;span.append(label,detalle);return span;}
 };
}
