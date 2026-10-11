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
const panel=async id=>(await db.query('SELECT reunion_panel($1) AS p',[id])).rows[0].p;
const act=(p,a,d={})=>db.query('SELECT reunion_accion($1,$2,$3,$4)',[p.id,p.version,a,JSON.stringify(d)]);
await db.exec("UPDATE ciclos SET anio=extract(year from now() AT TIME ZONE 'America/Mexico_City')::int WHERE es_activo");
const dates=(await db.query("SELECT (now() AT TIME ZONE 'America/Mexico_City')::date::text today,((now() AT TIME ZONE 'America/Mexico_City')::date+1)::text tomorrow")).rows[0];
await actor(4);
await assert.rejects(db.query('SELECT reunion_crear($1)',[dates.tomorrow]),e=>e.code==='22023');
const id=(await db.query('SELECT reunion_crear($1) id',[dates.today])).rows[0].id;
assert.equal((await db.query('SELECT reunion_crear($1) id',[dates.today])).rows[0].id,id);
let p=await panel(id);
await assert.rejects(act(p,'cerrar'),e=>e.code==='22023');
for(const g of p.grupos){p=await panel(id);await act(p,'unidad',{clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:u.id_usuario===uid(1)?'asistencia':'falta'}))});}
await act(await panel(id),'cerrar');
await actor(2);
await assert.rejects(act(await panel(id),'justificar',{id_usuario:uid(1),motivo:'No reemplazar asistencia'}),e=>e.code==='22023');
await assert.rejects(act(await panel(id),'justificar',{id_usuario:uid(3),motivo:'Otra unidad'}),e=>e.code==='42501');
await assert.rejects(act(await panel(id),'celda',{id_usuario:uid(1),estado:'falta'}),e=>e.code==='42501');
await act(await panel(id),'justificar',{id_usuario:uid(2),motivo:'Cita familiar'});
for(const [rol,cantidad] of [[1,2],[2,2],[3,1],[4,4]]){
 await actor(rol);
 assert.equal((await db.query('SELECT * FROM historial_matriz()')).rows.length,cantidad);
 assert.equal((await db.query('SELECT * FROM cuotas')).rows.length,rol===4?12:4);
}
await actor(4);p=await panel(id);
await act(p,'celda',{id_usuario:uid(2),estado:'asistencia'});
await assert.rejects(act(p,'celda',{id_usuario:uid(2),estado:'falta'}),e=>e.code==='40001');
assert.equal((await db.query('SELECT * FROM historial_matriz()')).rows.length,4);
assert.equal((await db.query('SELECT estado FROM asistencias WHERE id_usuario=$1 AND fecha=$2',[uid(2),dates.today])).rows[0].estado,'asistencia');
const presentacion=(await db.query('SELECT * FROM presentacion_integrantes()')).rows;
assert.equal(presentacion.find(u=>u.id_usuario===uid(4)).es_directiva,true);
assert.equal(presentacion.find(u=>u.id_usuario===uid(1)).cobra_cuotas,false);
assert.equal(presentacion.find(u=>u.id_usuario===uid(2)).cobra_cuotas,true);
assert.equal(presentacion.find(u=>u.id_usuario===uid(3)).cobra_cuotas,true);
await actor(0);await assert.rejects(db.query('SELECT * FROM historial_matriz()'),e=>e.code==='42501');
await assert.rejects(db.query('SELECT * FROM presentacion_integrantes()'),e=>e.code==='42501');
await db.exec('RESET ROLE');
await db.exec(m8);

// 009: migrar registros existentes y separar pases de un mismo día.
const m9=file('migrations/009_pases_por_reunion.sql');
const originales=(await db.query('SELECT id_asistencia FROM asistencias ORDER BY id_asistencia')).rows;
await db.exec(m9);await db.exec(m9);
assert.deepEqual((await db.query('SELECT id_asistencia FROM asistencias ORDER BY id_asistencia')).rows,originales);
await actor(4);
assert.equal((await panel(id)).integrantes.length,3);
assert.ok(!(await panel(id)).grupos.some(g=>g.nombre==='Sin unidad'));
assert.equal((await db.query('SELECT * FROM asistencias WHERE id_usuario=$1',[uid(4)])).rows.length,0);
assert.ok(!(await db.query('SELECT * FROM historial_matriz_turnos()')).rows.some(x=>x.id_usuario===uid(4)));
await assert.rejects(act(await panel(id),'celda',{id_usuario:uid(4),estado:'asistencia'}),e=>e.code==='22023');
await db.exec('RESET ROLE');
await db.query("INSERT INTO usuarios(id_usuario,id_ciclo,nombres,apellido,rol) VALUES($1,'c0000000-0000-4000-8000-000000000001','Sin','Unidad','conquistador')",[uid(5)]);
await actor(4);
const crear=async nombre=>(await db.query('SELECT reunion_crear_turno($1,$2) id',[dates.today,nombre])).rows[0].id;
const manana=await crear('Mañana'),tarde=await crear('Tarde');
assert.notEqual(manana,tarde);
assert.equal(await crear('  TARDE  '),tarde);
assert.equal((await panel(tarde)).integrantes.length,4);
assert.ok((await panel(tarde)).grupos.some(g=>g.nombre==='Sin unidad'));
assert.ok(!(await panel(tarde)).integrantes.some(x=>x.id_usuario===uid(4)));
await assert.rejects(crear('  '),e=>e.code==='22023');
async function cerrarPase(reunion,estado) {
  let p=await panel(reunion);
  for(const g of p.grupos){p=await panel(reunion);await act(p,'unidad',{clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado}))});}
  await act(await panel(reunion),'cerrar');
}
await cerrarPase(manana,'falta');await cerrarPase(tarde,'asistencia');
const registros=async()=>(await db.query('SELECT id_reunion,estado FROM asistencias WHERE id_usuario=$1 AND id_reunion IN ($2,$3) ORDER BY id_reunion',[uid(3),manana,tarde])).rows;
assert.equal((await registros()).length,2);
await act(await panel(manana),'celda',{id_usuario:uid(3),estado:'justificado'});
assert.equal((await registros()).find(x=>x.id_reunion===tarde).estado,'asistencia');
assert.equal((await registros()).find(x=>x.id_reunion===manana).estado,'justificado');
await act(await panel(manana),'anular',{motivo:'Prueba de independencia'});
assert.deepEqual(await registros(),[{id_reunion:tarde,estado:'asistencia'}]);
await actor(2);
await assert.rejects(act(await panel(tarde),'justificar',{id_usuario:uid(1),motivo:'Ya asistió'}),e=>e.code==='22023');
await actor(4);await act(await panel(id),'celda',{id_usuario:uid(2),estado:'falta'});
await actor(2);await act(await panel(id),'justificar',{id_usuario:uid(2),motivo:'Solo el pase General'});
await actor(4);
assert.equal((await db.query('SELECT estado FROM asistencias WHERE id_usuario=$1 AND id_reunion=$2',[uid(2),tarde])).rows[0].estado,'asistencia');
await db.exec('RESET ROLE');await db.exec(m9);
assert.equal((await db.query('SELECT * FROM asistencias WHERE id_usuario=$1',[uid(4)])).rows.length,1);
await actor(0);await assert.rejects(db.query('SELECT * FROM historial_matriz_turnos()'),e=>e.code==='42501');
await assert.rejects(db.query('SELECT reunion_crear_turno($1,$2)',[dates.today,'No permitido']),e=>e.code==='42501');
console.log('SQL OK: migraciones 008/009 repetibles, roles, dos pases por día, reintentos sin duplicar, correcciones/anulaciones aisladas y directiva exenta sin borrar registros.');
await db.close();
