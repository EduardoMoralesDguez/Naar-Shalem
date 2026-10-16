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
const colores=(await db.query('SELECT * FROM colores_integrantes()')).rows;
assert.ok(colores.every(c=>!c.color_clase||/^#[0-9a-f]{6}$/i.test(c.color_clase)));
await db.exec('RESET ROLE');await assert.rejects(db.query("UPDATE clases SET color_distintivo='rojo'"),e=>e.code==='23514');
await actor(4);const actividad=crypto.randomUUID();await guardar(actividad,'Offline','regular',false);
let p=await reunion(actividad);const g=p.grupos[0];
const datos={clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:'asistencia'}))};
const ctx=(await db.query('SELECT asistencias_contexto() c')).rows[0].c;
const enviar=(id,version,accion,d)=>db.query('SELECT asistencia_operar($1,$2,$3,$4,$5,$6)',[id,ctx.epoca,actividad,version,accion,JSON.stringify(d)]);
const opid=crypto.randomUUID();await enviar(opid,p.version,'unidad',datos);await enviar(opid,p.version,'unidad',datos);
assert.equal((await reunion(actividad)).version,p.version+1);
assert.equal((await db.query('SELECT * FROM asistencias_bitacora()')).rows.filter(e=>e.accion==='unidad').length,1);
await assert.rejects(enviar(crypto.randomUUID(),p.version,'unidad',datos),e=>e.code==='40001');
await actor(3);await assert.rejects(db.query('SELECT * FROM asistencias_bitacora()'),e=>e.code==='42501');
await assert.rejects(enviar(opid,p.version,'unidad',datos),e=>e.code==='22023');
await assert.rejects(db.query('SELECT * FROM privado.asistencia_operaciones'),e=>e.code==='42501');
await actor(2);p=await reunion(actividad);await assert.rejects(enviar(crypto.randomUUID(),p.version,'unidad',datos),e=>e.code==='42501');
// Justificaciones offline conservan el límite del día: no confían en fecha del cliente.
await db.exec('RESET ROLE');await db.query("UPDATE privado.reuniones SET fecha=fecha-1,fecha_fin=fecha_fin-1 WHERE id=$1",[actividad]);
await actor(2);p=await reunion(actividad);await assert.rejects(enviar(crypto.randomUUID(),p.version,'justificar',{id_usuario:uid(2),motivo:'Aviso'}),e=>['42501','22023'].includes(e.code));
await db.exec('RESET ROLE');await db.exec(file('admin/limpiar_cuotas_asistencias.sql'));await actor(4);
await assert.rejects(enviar(opid,1,'unidad',datos),e=>e.code==='40001');
await actor(0);await assert.rejects(db.query('SELECT asistencias_contexto()'));await assert.rejects(db.query('SELECT * FROM colores_integrantes()'));
console.log('Offline SQL OK: colores hex, idempotencia, conflictos, bitácora privada, límite diario y limpieza.');await db.close();
