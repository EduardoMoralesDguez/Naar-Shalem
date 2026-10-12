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
const ciclo='c0000000-0000-4000-8000-000000000001';
const panel=async()=>(await db.query('SELECT cuotas_panel() p')).rows[0].p;
const op=async(accion,datos,id=crypto.randomUUID())=>(await db.query('SELECT cuotas_operar($1,$2,$3) r',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})])).rows[0].r;
const ver=async(n)=>(await panel()).integrantes.find(u=>u.id_usuario===uid(n)).version;
await db.exec("UPDATE ciclos SET anio=extract(year FROM now() AT TIME ZONE 'America/Mexico_City') WHERE es_activo");
const sunday=(await db.query("SELECT ((now() AT TIME ZONE 'America/Mexico_City')::date-extract(dow FROM now() AT TIME ZONE 'America/Mexico_City')::int)::text fecha")).rows[0].fecha;
await actor(4);
const p=(await op('periodo',{fecha:sunday})).periodo;
assert.equal((await op('periodo',{fecha:sunday})).periodo,p);
assert.equal((await panel()).cargos.filter(c=>c.periodo===p).length,2);
assert.ok(!(await panel()).integrantes.some(u=>[uid(1),uid(4)].includes(u.id_usuario)));
const v=await ver(2), id=crypto.randomUUID();
await actor(2);
const pago={id_usuario:uid(2),version:v,importe:1000,fecha:sunday,periodos:[p]};
await op('pago',pago,id);await op('pago',pago,id);
await assert.rejects(op('pago',{...pago,version:await ver(2)}),e=>e.code==='40001');
await assert.rejects(op('pago',{...pago,id_usuario:uid(3)}),e=>e.code==='42501');
assert.ok((await panel()).integrantes.every(u=>u.id_usuario===uid(2)));
await actor(3);await assert.rejects(op('pago',pago),e=>e.code==='42501');
await actor(1);assert.equal((await panel()).integrantes.length,0);
await actor(4);
const anticipo=crypto.randomUUID();
await op('pago',{id_usuario:uid(3),version:await ver(3),importe:5000,fecha:sunday,periodos:[p]},anticipo);
assert.equal((await panel()).integrantes.find(u=>u.id_usuario===uid(3)).saldo,4000);
// Cuatro domingos futuros consumen saldo, sin generar ingresos adicionales.
for(let n=1;n<=4;n++) {const fecha=(await db.query('SELECT ($1::date+$2::int)::text fecha',[sunday,n*7])).rows[0].fecha;await op('periodo',{fecha});}
let d=await panel();assert.equal(d.integrantes.find(u=>u.id_usuario===uid(3)).saldo,0);
assert.equal(d.aplicaciones.filter(a=>a.ingreso===anticipo).length,5);
assert.equal(d.ingresos.filter(i=>i.id===anticipo).length,1);
assert.equal((await db.query('SELECT cuotas_resumen($1) r',[uid(3)])).rows[0].r.total_pagado,70);
await op('corregir',{id_usuario:uid(3),version:await ver(3),ingreso:anticipo,importe:500,motivo:'Importe equivocado'});
d=await panel();assert.equal(d.aplicaciones.filter(a=>a.ingreso===anticipo).reduce((s,a)=>s+a.importe,0),500);
await op('anular',{id_usuario:uid(3),version:await ver(3),ingreso:anticipo,motivo:'No se recibió efectivo'});
assert.ok(!(await panel()).aplicaciones.some(a=>a.ingreso===anticipo));
await db.exec('RESET ROLE');
await db.query("UPDATE usuarios SET rol='subcapitan',id_unidad='a0000000-0000-4000-8000-000000000001' WHERE id_usuario=$1",[uid(3)]);
await db.exec(m10);
await actor(3);
assert.equal((await panel()).integrantes.length,2);
const subid=crypto.randomUUID();
await op('pago',{id_usuario:uid(3),version:await ver(3),importe:1000,fecha:sunday,periodos:[p]},subid);
await assert.rejects(op('anular',{id_usuario:uid(3),version:await ver(3),ingreso:subid,motivo:'Intento'}),e=>e.code==='42501');
await assert.rejects(db.query('SELECT * FROM privado.cuota_ingresos'),e=>e.code==='42501');
await actor(4);
const hoy=(await db.query("SELECT (now() AT TIME ZONE 'America/Mexico_City')::date::text fecha")).rows[0].fecha;
const reunion=(await db.query("SELECT reunion_crear_turno($1,'Prueba subcapitán') id",[hoy])).rows[0].id;
await actor(3);
const rp=(await db.query('SELECT reunion_panel($1) p',[reunion])).rows[0].p;
assert.ok(rp.puede_justificar);
await db.query('SELECT reunion_accion($1,$2,$3,$4)',[reunion,rp.version,'justificar',JSON.stringify({id_usuario:uid(3),motivo:'Prueba de permiso'})]);
await assert.rejects(db.query('SELECT cuotas_resumen($1)',[uid(2)]),e=>e.code==='42501');
await db.exec('RESET ROLE');
await db.query('UPDATE usuarios SET es_activo=false WHERE id_usuario=$1',[uid(3)]);
await actor(3);await assert.rejects(panel(),e=>e.code==='42501');
await actor(0);await assert.rejects(panel(),e=>e.code==='42501');
await assert.rejects(op('periodo',{fecha:sunday}),e=>e.code==='42501');
console.log('Cuotas SQL OK: importación repetible, $10, anticipos, correcciones, idempotencia, conflictos y permisos.');
await db.close();
