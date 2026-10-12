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
const fechas=(await db.query("SELECT (now() AT TIME ZONE 'America/Mexico_City')::date::text hoy, ((now() AT TIME ZONE 'America/Mexico_City')::date+(7-extract(dow FROM now() AT TIME ZONE 'America/Mexico_City')::int))::text domingo")).rows[0];
const ciclo='c0000000-0000-4000-8000-000000000001';
const crear=(id,nombre,cobra,fecha=fechas.domingo,version=null,hora='09:00')=>db.query('SELECT calendario_guardar($1,$2,$3,$4,$5,$6) id',[id,version,fecha,hora,nombre,cobra]);
const panel=async()=>(await db.query('SELECT cuotas_panel() p')).rows[0].p;
const lista=async()=>(await db.query('SELECT * FROM calendario_listar($1,$2)',[fechas.hoy,fechas.domingo])).rows;
const cancelar=async id=>{const r=(await lista()).find(r=>r.id===id);return db.query('SELECT calendario_cancelar($1,$2,$3)',[id,r.version,'Actividad cancelada']);};
const a=crypto.randomUUID(),b=crypto.randomUUID(),c=crypto.randomUUID();
await actor(3);await assert.rejects(crear(a,'Intento',false),e=>e.code==='42501');
await actor(4);
await crear(a,'Mañana',true);await crear(a,'Mañana',true);
await crear(b,'Tarde',true,fechas.domingo,null,'16:00');await crear(c,'Sin cobro',false);
assert.equal((await lista()).length,3);
const pp=(await panel()).periodos.filter(p=>p.fecha===fechas.domingo);assert.equal(pp.length,1);
assert.equal((await panel()).cargos.filter(c=>c.periodo===pp[0].id).length,2);
const p=await panel(),u=p.integrantes.find(u=>u.id_usuario===uid(3)),ingreso=crypto.randomUUID();
await db.query('SELECT cuotas_operar($1,$2,$3)',[ingreso,'pago',JSON.stringify({id_ciclo:ciclo,id_usuario:u.id_usuario,version:u.version,importe:1000,fecha:fechas.hoy,periodos:[pp[0].id]})]);
await cancelar(a);assert.ok((await panel()).periodos.some(p=>p.id===pp[0].id));
await cancelar(b);let q=await panel();assert.ok(!q.periodos.some(p=>p.id===pp[0].id));assert.equal(q.integrantes.find(u=>u.id_usuario===uid(3)).saldo,1000);assert.ok(q.ingresos.some(i=>i.id===ingreso&&!i.anulado));
// Cobrar nuevamente reactiva el mismo domingo y aplica el saldo, sin duplicar ingreso.
const rc=(await lista()).find(r=>r.id===c);await crear(c,'Sin cobro',true,fechas.domingo,rc.version);
q=await panel();assert.ok(q.periodos.some(p=>p.id===pp[0].id));assert.equal(q.integrantes.find(u=>u.id_usuario===uid(3)).saldo,0);assert.equal(q.ingresos.filter(i=>i.id===ingreso).length,1);
await assert.rejects(crear(c,'Editar antiguo',true,fechas.domingo,rc.version),e=>e.code==='40001');
await assert.rejects(crear(crypto.randomUUID(),'Mañana',false),e=>e.code==='23505');
const d=crypto.randomUUID();await crear(d,'Hoy',false,fechas.hoy);
let rp=(await db.query('SELECT reunion_panel($1) p',[d])).rows[0].p;
await db.query('SELECT reunion_accion($1,$2,$3,$4)',[d,rp.version,'unidad',JSON.stringify({clave:rp.grupos[0].clave,integrantes:rp.integrantes.filter(i=>i.clave===rp.grupos[0].clave).map(i=>({id_usuario:i.id_usuario,estado:'asistencia'}))})]);
rp=(await db.query('SELECT reunion_panel($1) p',[d])).rows[0].p;
await assert.rejects(crear(d,'Hoy',false,fechas.domingo,rp.version),e=>e.code==='22023');
// Mover el último cobro a otro domingo conserva y reaplica el dinero.
const siguiente=(await db.query('SELECT ($1::date+7)::text fecha',[fechas.domingo])).rows[0].fecha;
const vigente=(await lista()).find(r=>r.id===c);
await crear(c,'Reprogramada',true,siguiente,vigente.version);
q=await panel();const nuevoPeriodo=q.periodos.find(p=>p.fecha===siguiente);
assert.ok(nuevoPeriodo);assert.equal(q.integrantes.find(u=>u.id_usuario===uid(3)).saldo,0);
assert.ok(q.aplicaciones.some(a=>a.ingreso===ingreso&&a.periodo===nuevoPeriodo.id));
await db.query('SELECT calendario_guardar($1,$2,$3,$4,$5,$6)',[c,vigente.version+1,fechas.domingo,'09:00','Sin cobro',true]);
const lunes=(await db.query('SELECT ($1::date+1)::text fecha',[fechas.domingo])).rows[0].fecha;
await assert.rejects(crear(crypto.randomUUID(),'Cobro lunes',true,lunes),e=>e.code==='22023');
await actor(2);assert.equal((await lista()).length,4);await assert.rejects(cancelar(c),e=>e.code==='42501');
await actor(0);await assert.rejects(lista(),e=>e.code==='42501');
await db.exec('RESET ROLE');await db.exec(migration11);
assert.equal((await db.query('SELECT count(*) n FROM privado.reuniones WHERE id=ANY($1::uuid[])',[[a,b,c,d]])).rows[0].n,4);
console.log('Calendario SQL OK: futuro, cobro compartido, cancelación/saldo, reactivación, versiones, permisos y migración repetible.');await db.close();
