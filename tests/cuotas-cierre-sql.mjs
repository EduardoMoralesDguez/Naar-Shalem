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

// Compatibilidad con anticipos aplicados automáticamente por 012.
await actor(4);
let anterior=await panel();
await operar('pago',{id_ciclo:ciclo,epoca:anterior.epoca,id_usuario:uid(3),version:anterior.integrantes.find(u=>u.id_usuario===uid(3)).version,importe:1000,fecha:fechas.hoy,periodos:[]});
const migrada=crypto.randomUUID();await guardar(migrada,'Antes de actualizar','regular',true);
anterior=await panel();const periodoMigrado=anterior.periodos.find(p=>p.actividad===migrada).id;
assert.equal(anterior.cargos.find(c=>c.periodo===periodoMigrado&&c.id_usuario===uid(3)).pagado,1000);
await db.exec('RESET ROLE');
await db.exec(file('migrations/013_cierre_cuotas.sql'));
await db.exec(file('migrations/013_cierre_cuotas.sql'));
await actor(4);
let convertido=await panel();
assert.equal(convertido.cargos.find(c=>c.periodo===periodoMigrado&&c.id_usuario===uid(3)).pagado,0);
assert.equal(convertido.integrantes.find(u=>u.id_usuario===uid(3)).saldo,1000);
assert.equal(convertido.ingresos.filter(i=>i.id_usuario===uid(3)).length,anterior.ingresos.filter(i=>i.id_usuario===uid(3)).length);
const pay=async(n,importe,periodos=[])=>{ const p=await panel(); return operar('pago',{id_ciclo:ciclo,epoca:p.epoca,id_usuario:uid(n),version:p.integrantes.find(u=>u.id_usuario===uid(n)).version,importe,fecha:fechas.hoy,periodos}); };
await pay(2,3000);await pay(3,1000);
const a=crypto.randomUUID();await guardar(a,'Cobro','regular',true);
let p=await panel();const periodo=p.periodos.find(x=>x.actividad===a).id;
assert.ok(p.cargos.filter(c=>c.periodo===periodo).every(c=>c.pagado===0&&!c.cerrado));
const cierre=async(n)=>{const p=await panel();const u=p.integrantes.find(u=>u.id_usuario===uid(n));return {id_ciclo:ciclo,epoca:p.epoca,periodo,unidad:u.id_unidad||'sin-unidad',versiones:Object.fromEntries(p.cargos.filter(c=>c.periodo===periodo&&c.id_unidad===u.id_unidad).map(c=>[c.id_usuario,p.integrantes.find(u=>u.id_usuario===c.id_usuario).version]))};};
const otra=await cierre(3),viejo=await cierre(2);
await actor(2);await assert.rejects(operar('cerrar',otra),e=>e.code==='42501');
await pay(2,1000,[periodo]);
await assert.rejects(operar('cerrar',viejo),e=>e.code==='40001');
const datos=await cierre(2),id=crypto.randomUUID();
await operar('cerrar',datos,id);await operar('cerrar',datos,id);
p=await panel();assert.equal(p.integrantes.find(u=>u.id_usuario===uid(2)).saldo,3000);
assert.equal(p.cargos.find(c=>c.periodo===periodo&&c.id_usuario===uid(2)).pagado,1000);
await assert.rejects(pay(2,1000,[periodo]),e=>e.code==='40001');
await actor(4);await operar('cerrar',await cierre(3));p=await panel();
assert.equal(p.integrantes.find(u=>u.id_usuario===uid(3)).saldo,1000);
assert.equal(p.cargos.find(c=>c.periodo===periodo&&c.id_usuario===uid(3)).pagado,1000);
assert.ok(p.bitacora.some(o=>o.accion==='cerrar'));
await actor(3);await assert.rejects(operar('cerrar',otra),e=>e.code==='42501');
await actor(4);
const futura=crypto.randomUUID();await guardar(futura,'Anticipo','regular',true,fechas.futuro);
p=await panel();const futuro=p.periodos.find(x=>x.actividad===futura).id;
await pay(3,1000,[futuro]);p=await panel();assert.equal(p.cargos.find(c=>c.periodo===futuro&&c.id_usuario===uid(3)).pagado,0);
await assert.rejects(operar('saldo',{id_ciclo:ciclo,epoca:p.epoca,id_usuario:uid(3),version:p.integrantes.find(u=>u.id_usuario===uid(3)).version,periodos:[futuro]}),e=>e.code==='22023');
await actor(2);assert.equal((await panel()).bitacora.length,0);
await db.exec('RESET ROLE');await db.exec(file('migrations/013_cierre_cuotas.sql'));
console.log('Cierre cuotas OK: anticipo, efectivo, cierre por unidad, versiones, permisos, reintento y futuro.');
await db.close();
