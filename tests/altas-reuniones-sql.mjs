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

await actor(4);
const crear=async(nombre,tipo='regular',cobra=true,fecha=fechas.futuro)=>{const id=crypto.randomUUID();await guardar(id,nombre,tipo,cobra,fecha);return id;};
const manana=await crear('Mañana');const tarde=await crear('Tarde');
const sinCuota=await crear('Sin cuota','regular',false);
const practica=await crear('Práctica','practica',false);
const cerrada=await crear('Pase cerrado');const cobroCerrado=await crear('Cobro cerrado');
const anulada=await crear('Anulada');const eliminada=await crear('Eliminada');
const pasado=(await db.query("SELECT ((now() AT TIME ZONE 'America/Mexico_City')::date-1)::text d")).rows[0].d;
const antigua=await crear('Anterior','regular',true,pasado);
const alta=async(id,rol='conquistador',unidad=deAna.id_unidad)=>db.query('SELECT admin_guardar_integrante($1,NULL,$2,$3,$4,$5,NULL,NULL)',[id,'Nuevo','Integrante',rol,unidad]);
// Usuario afectado por el error antes de instalar la reparación.
const previo=crypto.randomUUID();await alta(previo);
await db.exec('RESET ROLE');
await db.query("UPDATE privado.reuniones SET estado='cerrada' WHERE id=$1",[cerrada]);
await db.query("UPDATE privado.reuniones SET estado='anulada' WHERE id=$1",[anulada]);
await db.query("UPDATE privado.reuniones SET eliminado=true WHERE id=$1",[eliminada]);
await db.query("UPDATE privado.cuota_cargos SET cerrado=true WHERE periodo=(SELECT periodo_cuota FROM privado.reuniones WHERE id=$1) AND id_unidad=$2",[cobroCerrado,deAna.id_unidad]);
await db.query("UPDATE privado.unidades_revisadas SET revisada=true WHERE reunion=$1",[manana]);
const m17=file('migrations/017_altas_reuniones_pendientes.sql');await db.exec(m17);
const filas=async(id)=>(await db.query('SELECT reunion FROM privado.convocados WHERE id_usuario=$1',[id])).rows.map(r=>r.reunion);
const cargos=async(id)=>(await db.query('SELECT r.id FROM privado.cuota_cargos c JOIN privado.reuniones r ON r.periodo_cuota=c.periodo WHERE c.id_usuario=$1',[id])).rows.map(r=>r.id);
assert.deepEqual(new Set(await filas(previo)),new Set([manana,tarde,sinCuota,cobroCerrado]));
assert.deepEqual(new Set(await cargos(previo)),new Set([manana,tarde,cerrada]));
const versionAntes=(await db.query('SELECT version FROM privado.reuniones WHERE id=$1',[manana])).rows[0].version;
await db.exec(m17);assert.equal((await db.query('SELECT version FROM privado.reuniones WHERE id=$1',[manana])).rows[0].version,versionAntes);
// El alta normal, con rol authenticated y RPC real, incluye ambos pases del día.
await actor(4);const cobroAntes=await panel();const nuevo=crypto.randomUUID();await alta(nuevo);
const p=await reunion(manana);assert.ok(p.integrantes.some(u=>u.id_usuario===nuevo));
const q=await panel();assert.ok(q.cargos.some(c=>c.id_usuario===nuevo&&c.importe===1000&&!c.cerrado));
assert.equal(p.grupos.find(g=>g.clave===deAna.id_unidad).revisada,false);
assert.equal(p.version,versionAntes+1);
// Un cierre de cuotas preparado antes del alta debe actualizar la unidad completa.
const periodo=q.periodos.find(p=>p.actividad===manana).id;
await assert.rejects(operar('cerrar',{id_ciclo:ciclo,periodo,unidad:deAna.id_unidad,versiones:Object.fromEntries(cobroAntes.integrantes.map(u=>[u.id_usuario,u.version]))}),e=>e.code==='40001');
// Una captura offline anterior no puede cerrar una lista que ya cambió.
await assert.rejects(db.query("SELECT reunion_accion($1,$2,'cerrar','{}')",[manana,versionAntes]),e=>e.code==='40001');
await db.exec('RESET ROLE');
assert.deepEqual(new Set(await filas(nuevo)),new Set([manana,tarde,sinCuota,cobroCerrado]));
assert.deepEqual(new Set(await cargos(nuevo)),new Set([manana,tarde,cerrada]));
await actor(4);const directivo=crypto.randomUUID();await alta(directivo,'directiva',null);
const consejero=crypto.randomUUID();await alta(consejero,'consejero');
const sinUnidad=crypto.randomUUID();await alta(sinUnidad,'conquistador',null);
await db.exec('RESET ROLE');
assert.equal((await filas(directivo)).length,0);assert.equal((await cargos(directivo)).length,0);
assert.equal((await filas(consejero)).length,4);assert.equal((await cargos(consejero)).length,0);
assert.ok((await filas(sinUnidad)).includes(manana));assert.ok((await cargos(sinUnidad)).includes(cobroCerrado));
assert.ok((await db.query("SELECT 1 FROM privado.unidades_revisadas WHERE reunion=$1 AND clave='sin-unidad' AND NOT revisada",[manana])).rows.length);
// Invocar de nuevo la reparación no duplica cargos ni incrementa versiones.
const antes=(await db.query('SELECT version FROM privado.reuniones WHERE id=$1',[manana])).rows[0].version;
await db.query('SELECT privado.incorporar_integrante_pendientes($1,$2)',[nuevo,fechas.hoy]);
assert.equal((await db.query('SELECT version FROM privado.reuniones WHERE id=$1',[manana])).rows[0].version,antes);
assert.equal((await cargos(nuevo)).length,3);
await actor(3);await assert.rejects(alta(crypto.randomUUID()),e=>e.code==='42501');
await assert.rejects(db.query('SELECT privado.incorporar_integrante_pendientes($1,$2)',[nuevo,fechas.hoy]),e=>e.code==='42501');
console.log('Altas SQL OK: RPC real, reparación repetible, varios pases, cuotas opcionales, cierres independientes, exenciones, sin unidad y versiones offline.');
await db.close();
