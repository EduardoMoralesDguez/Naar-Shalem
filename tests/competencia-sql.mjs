import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const db=new PGlite();
const file=p=>readFileSync(new URL('../database/'+p,import.meta.url),'utf8');
await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated; CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
$$ SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;`);
await db.exec(file('schema.sql'));
await db.exec(`INSERT INTO usuarios(id_usuario,id_ciclo,nombres,apellido,rol)
VALUES('d0000000-0000-4000-8000-000000000004','c0000000-0000-4000-8000-000000000001','Ezequiel','Morales','directiva');
INSERT INTO auth.users(id) SELECT ('f0000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid FROM generate_series(1,4) n;`);
await db.exec(file('migrations/001_cuentas_y_datos_privados.sql'));
await db.exec("SELECT privado.vincular_cuenta(id_usuario,replace(id_usuario::text,'d000','f000')::uuid) FROM usuarios");
await db.exec(file('migrations/002_login_rls.sql'));await db.exec(file('migrations/003_directorio_compartido.sql'));
const migration=file('migrations/004_administrar_integrantes.sql');
await db.exec(migration);await db.exec(migration);
await db.exec(`CREATE SCHEMA storage;
CREATE TABLE storage.buckets(id text PRIMARY KEY,name text,public bool,file_size_limit bigint,allowed_mime_types text[]);
CREATE TABLE storage.objects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),bucket_id text REFERENCES storage.buckets,name text,UNIQUE(bucket_id,name));
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon,authenticated;
GRANT SELECT,INSERT,UPDATE,DELETE ON storage.objects TO anon,authenticated;`);
const m5=readFileSync(new URL('../database/migrations/005_portal_y_fotos.sql',import.meta.url),'utf8');
await db.exec(m5);await db.exec(m5);

const m6=readFileSync(new URL('../database/migrations/006_asistencias.sql',import.meta.url),'utf8');
await db.exec(m6);await db.exec(m6);


await db.exec("INSERT INTO asistencias(id_usuario,id_ciclo,fecha,estado) VALUES('d0000000-0000-4000-8000-000000000001','c0000000-0000-4000-8000-000000000001','2026-10-01','asistencia')");

await db.exec(file('migrations/007_reuniones.sql'));
const m8=file('migrations/008_matriz_asistencias.sql');
await db.exec(m8);await db.exec(m8);
async function actor(n){await db.exec('RESET ROLE');await db.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[n?`f0000000-0000-4000-8000-${String(n).padStart(12,'0')}`:'']);await db.exec(n?'SET ROLE authenticated':'SET ROLE anon');}
const uid=n=>`d0000000-0000-4000-8000-${String(n).padStart(12,'0')}`;

await db.exec(file('migrations/009_pases_por_reunion.sql'));
const m10=file('migrations/010_cuotas.sql');await db.exec(m10);await db.exec(m10);
const migration11=file('migrations/011_calendario.sql');await db.exec(migration11);await db.exec(migration11);
await db.exec("UPDATE ciclos SET anio=extract(year FROM now() AT TIME ZONE 'America/Mexico_City') WHERE es_activo");

const migration12=file("migrations/012_tipos_actividades.sql");await db.exec(migration12);await db.exec(migration12);
const ciclo='c0000000-0000-4000-8000-000000000001';
const fechas=(await db.query("SELECT (now() AT TIME ZONE 'America/Mexico_City')::date::text hoy, ((now() AT TIME ZONE 'America/Mexico_City')::date+1)::text futuro")).rows[0];
const unidades=(await db.query('SELECT * FROM unidades ORDER BY nombre')).rows;
const clases=(await db.query('SELECT * FROM clases ORDER BY nombre')).rows;
const miembros=(await db.query('SELECT id_usuario,id_unidad,id_clase FROM usuarios')).rows;
const deAna=miembros.find(u=>u.id_usuario===uid(3));
const panel=async()=>(await db.query('SELECT cuotas_panel() p')).rows[0].p;
const guardar=(id,nombre,tipo='regular',cobra=false,fecha=fechas.hoy,extra={})=>db.query('SELECT calendario_guardar($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)',[id,extra.version??null,fecha,extra.hora||'09:00',nombre,cobra,tipo,extra.fin||fecha,extra.unidad||null,extra.clase||null]);
const listar=async(desde=fechas.hoy,hasta=fechas.futuro)=>(await db.query('SELECT * FROM calendario_listar($1,$2)',[desde,hasta])).rows;
const version=async id=>(await listar()).find(a=>a.id===id).version;
const borrar=async id=>db.query('SELECT calendario_eliminar($1,$2)',[id,await version(id)]);
const reunion=async id=>(await db.query('SELECT reunion_panel($1) p',[id])).rows[0].p;
const operar=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT cuotas_operar($1,$2,$3)',[id,accion,JSON.stringify(datos)]);


await db.exec(file('migrations/013_cierre_cuotas.sql'));
const m14=file('migrations/014_organizacion.sql');await db.exec(m14);await db.exec(m14);
const m15=file('migrations/015_perfiles_unidades.sql');await db.exec(m15);await db.exec(m15);

const m16=file('migrations/016_asistencias_offline_colores.sql');await db.exec(m16);await db.exec(m16);

await db.exec(file('migrations/017_altas_reuniones_pendientes.sql'));
await db.exec(file('migrations/018_competencia.sql'));
await db.exec(file('migrations/018_competencia.sql'));
await actor(4);
const cp=async(id=null,desde=null,hasta=null)=>(await db.query('SELECT competencia_panel($1,$2,$3) p',[id,desde,hasta])).rows[0].p;

const op=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT competencia_guardar($1,$2,$3)',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})]);
let c=await cp();assert.equal(c.criterios.length,7);assert.ok(c.criterios.every(k=>k.valor===5));
const reunion1=crypto.randomUUID();await guardar(reunion1,'Puntajes mañana','regular',true);
const reunion2=crypto.randomUUID();await guardar(reunion2,'Puntajes tarde','regular',false);
const datosCaptura=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion,version_config:p.version_config,integrantes:p.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:[p.criterios.find(k=>k.nombre==='Biblia').id]})),extras:[]});
let captura=(await cp(reunion1)).captura;assert.equal(captura.integrantes.length,3);assert.equal(captura.integrantes.find(u=>u.id_usuario===uid(1)).cobra,false);
let d=datosCaptura(captura);d.extras=[{id_usuario:uid(3),puntos:7,motivo:'Servicio'},{id_unidad:deAna.id_unidad,puntos:20,motivo:'Dinámica'}];
const opId=crypto.randomUUID();await op('captura',d,opId);await op('captura',d,opId);
c=await cp(reunion1,fechas.hoy,fechas.hoy);assert.equal(c.captura.version,1);
assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,12);
assert.equal(c.resultados.unidades.find(u=>u.id_unidad===deAna.id_unidad).puntos,32);
await assert.rejects(op('captura',d),e=>e.code==='40001');
// El servidor no permite marcar a mano asistencia/cuota ni inventar participantes.
d=datosCaptura(c.captura);d.integrantes[0].cumplidos=[c.captura.criterios.find(k=>k.fuente==='cuota').id];await assert.rejects(op('captura',d),e=>e.code==='22023');
d=datosCaptura(c.captura);d.integrantes[0].id_usuario=uid(4);await assert.rejects(op('captura',d),e=>e.code==='40001');
d=datosCaptura(c.captura);d.extras=[{id_usuario:uid(3),puntos:5,motivo:'   '}];await assert.rejects(op('captura',d),e=>e.code==='23514');
// Cambiar a 10 puntos no altera la reunión ya capturada; se aplica a la siguiente.
const biblia=c.criterios.find(k=>k.nombre==='Biblia');await op('criterio',{id:biblia.id,nombre:biblia.nombre,valor:10,activo:true,version_config:c.version_config});
c=await cp(reunion1,fechas.hoy,fechas.hoy);assert.equal(c.captura.criterios.find(k=>k.id===biblia.id).valor,5);
assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,12);
let segunda=(await cp(reunion2)).captura;assert.equal(segunda.criterios.find(k=>k.id===biblia.id).valor,10);
await op('captura',datosCaptura(segunda));
// Asistencia solo puntúa al cerrar el pase, y cuota cuando se cubre completa.
async function cerrarPase(id){let p=await reunion(id);for(const g of p.grupos){await db.query("SELECT reunion_accion($1,$2,'unidad',$3)",[id,p.version,JSON.stringify({clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:u.id_usuario===uid(3)?'justificado':'asistencia'}))})]);p=await reunion(id);}await db.query("SELECT reunion_accion($1,$2,'cerrar','{}')",[id,p.version]);}
await cerrarPase(reunion1);await cerrarPase(reunion2);
c=await cp(reunion1,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,32);
const periodo=(await panel()).periodos.find(p=>p.actividad===reunion1).id;
async function pagar(importe){const q=await panel();await operar('pago',{id_ciclo:ciclo,epoca:q.epoca,id_usuario:uid(3),version:q.integrantes.find(u=>u.id_usuario===uid(3)).version,importe,fecha:fechas.hoy,periodos:[periodo]});}
await pagar(400);assert.equal((await cp(reunion1,fechas.hoy,fechas.hoy)).resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,32);
await pagar(600);assert.equal((await cp(reunion1,fechas.hoy,fechas.hoy)).resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,37);
// Corte bloqueado mientras los cobros no se cierran.
const corte={nombre:'Periodo de prueba',desde:fechas.hoy,hasta:fechas.hoy};await assert.rejects(op('corte',corte),e=>e.code==='22023');
const q=await panel();for(const clave of [...new Set(q.cargos.filter(c=>c.periodo===periodo).map(c=>c.id_unidad||'sin-unidad'))]){const actual=await panel();await operar('cerrar',{id_ciclo:ciclo,epoca:actual.epoca,periodo,unidad:clave,versiones:Object.fromEntries(actual.integrantes.map(u=>[u.id_usuario,u.version]))});}
await op('corte',corte);c=await cp(reunion1,fechas.hoy,fechas.hoy);assert.equal(c.captura.cerrada,true);assert.equal(c.cortes.length,1);assert.equal(c.anual.individual.find(u=>u.id_usuario===uid(3)).puntos,37);
await assert.rejects(op('corte',corte),e=>e.code==='22023');await assert.rejects(op('captura',datosCaptura(c.captura)),e=>e.code==='22023');
// Corregir asistencia después del corte no reescribe a los ganadores.
const a=await reunion(reunion1);await db.query("SELECT reunion_accion($1,$2,'celda',$3)",[reunion1,a.version,JSON.stringify({id_usuario:uid(3),estado:'falta'})]);
c=await cp(reunion1,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,37);
assert.ok(c.captura.integrantes.find(u=>u.id_usuario===uid(3)).automaticos.includes(c.captura.criterios.find(k=>k.fuente==='asistencia').id));
assert.equal((await cp(null,fechas.futuro,fechas.futuro)).resultados.individual.length,0);
// Cancelar una actividad cerrada no altera la fotografía del corte.
await db.exec('RESET ROLE');await db.query("UPDATE privado.reuniones SET eliminado=true WHERE id=$1",[reunion1]);await actor(4);
assert.equal((await cp(null,fechas.hoy,fechas.hoy)).anual.individual.find(u=>u.id_usuario===uid(3)).puntos,37);
// Los criterios personalizados, el límite Top 15 y reuniones futuras son independientes del corte.
await actor(4);let config=await cp();await op('criterios',{version_config:config.version_config,criterios:[{nombre:'Uniforme',valor:5,activo:true}]});
for(let i=0;i<16;i++)await db.query('SELECT admin_guardar_integrante($1,NULL,$2,$3,$4,NULL,NULL,NULL)',[crypto.randomUUID(),'Participante '+i,'Prueba','conquistador']);
const futura=crypto.randomUUID();await guardar(futura,'Otro periodo','regular',false,fechas.futuro);
let futuraPanel=(await cp(futura)).captura;assert.equal(futuraPanel.criterios.find(k=>k.nombre==='Uniforme').valor,5);await op('captura',datosCaptura(futuraPanel));
const sumaAnual=(await cp(null,fechas.futuro,fechas.futuro)).anual.individual.find(u=>u.id_usuario===uid(3)).puntos;
assert.equal(sumaAnual,47);
await actor(3);const publico=await cp(null,fechas.futuro,fechas.futuro);assert.equal(publico.resultados.destacados.length,15);assert.ok(publico.resultados.destacados.every(u=>Object.keys(u).sort().join(',')==='id_usuario,nombre'));
await actor(4);await db.exec('RESET ROLE');await assert.rejects(db.query("UPDATE privado.reuniones SET fecha=fecha+1,fecha_fin=fecha_fin+1 WHERE id=$1",[futura]),e=>e.code==='22023');await actor(4);
// Permisos reales: otros roles ven destacados sin puntajes, sin captura ni acumulado privado.
for(const n of [1,2,3]){await actor(n);const p=await cp(null,fechas.hoy,fechas.hoy);assert.equal(p.admin,false);assert.equal(p.resultados.individual.length,0);assert.equal(p.anual,null);assert.equal(p.bitacora.length,0);assert.ok(p.resultados.destacados.length>0);assert.ok(p.resultados.destacados.every(u=>!('puntos' in u)&&!('posicion' in u)));await assert.rejects(cp(reunion2),e=>e.code==='42501');await assert.rejects(op('corte',corte),e=>e.code==='42501');await assert.rejects(db.query('SELECT * FROM privado.competencia_marcas'),e=>e.code==='42501');}
await actor(0);await assert.rejects(cp(),e=>e.code==='42501');
console.log('Competencia SQL OK: valores, extras, auto A/J/cuota, parciales, snapshots, cortes, anual, idempotencia, privacidad y permisos.');await db.close();
