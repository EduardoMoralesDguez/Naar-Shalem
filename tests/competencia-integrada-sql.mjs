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
const legacyId=crypto.randomUUID();await db.query("INSERT INTO privado.competencia_cortes(id,id_ciclo,nombre,desde,hasta,resultados,auth_id) VALUES($1,$2,'Legado',make_date(extract(year FROM now())::int,1,1),make_date(extract(year FROM now())::int,1,1),$3,$4)",[legacyId,ciclo,JSON.stringify([{fecha:fechas.hoy.slice(0,4)+'-01-01',id_usuario:uid(1),id_unidad:null,nombre:'Consejero original',unidad:'Sin unidad',puntos:9}]),'f0000000-0000-4000-8000-000000000004']);
await db.exec(file('migrations/019_competencia_resultados.sql'));
await db.exec(file('migrations/019_competencia_resultados.sql'));
await db.exec("UPDATE usuarios SET rol='conquistador' WHERE id_usuario='d0000000-0000-4000-8000-000000000001'");
assert.equal((await db.query("SELECT rol,puntos FROM privado.competencia_detalle($1,$2::date,$2::date)",[ciclo,fechas.hoy.slice(0,4)+'-01-01'])).rows[0].rol,'consejero');
await db.exec("UPDATE usuarios SET rol='consejero' WHERE id_usuario='d0000000-0000-4000-8000-000000000001'");
await db.exec(file('migrations/020_competencia_integrada.sql'));
await db.exec(file('migrations/020_competencia_integrada.sql'));
await actor(4);
const cp=async(id=null,desde=null,hasta=null)=>(await db.query('SELECT competencia_panel($1,$2,$3) p',[id,desde,hasta])).rows[0].p;

const op=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT competencia_guardar($1,$2,$3)',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})]);


await db.exec('RESET ROLE');
// Empate que cruza el puesto 15: todos los empatados entran, aunque superen 15.
for(let i=0;i<18;i++)await db.query("INSERT INTO usuarios(id_ciclo,nombres,apellido,rol,id_unidad) VALUES($1,$2,'Empate','conquistador',$3)",[ciclo,'Participante '+i,deAna.id_unidad]);
await actor(4);
const r1=crypto.randomUUID(),r2=crypto.randomUUID(),r3=crypto.randomUUID();
await guardar(r1,'Primera','regular',true,fechas.hoy,{hora:'08:00'});await guardar(r2,'Segunda','regular',true,fechas.hoy,{hora:'10:00'});await guardar(r3,'Tercera','regular',false,fechas.hoy,{hora:'12:00'});
const datos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion,version_config:p.version_config,integrantes:p.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:[p.criterios.find(k=>k.nombre==='Biblia').id]})),extras:[]});
await op('captura',datos((await cp(r1)).captura));
await actor(3);let p=await cp(r1);assert.equal(p.admin,false);assert.ok(p.captura.solo_lectura);assert.ok(p.captura.integrantes.every(u=>u.id_unidad===deAna.id_unidad));assert.ok(p.resultados.destacados.length>15);assert.ok(p.resultados.destacados.every(u=>!('puntos' in u)));assert.equal(p.reuniones.length,3);assert.equal((await cp(r3)).captura.integrantes[0].cumplidos.length,0);
await assert.rejects(op('captura',datos(p.captura)),e=>e.code==='42501');
const q=await panel();assert.equal(q.cargos.length,0);assert.equal(q.ingresos.length,0);assert.equal(q.integrantes.length,0);assert.equal(typeof q.cumplimiento,'number');
assert.deepEqual(Object.keys((await db.query('SELECT cuotas_resumen($1) p',[uid(3)])).rows[0].p),['porcentaje']);
await assert.rejects(db.query('SELECT * FROM cuotas'),e=>e.code==='42501');
await actor(4);await op('captura',datos((await cp(r2)).captura));
await actor(3);await assert.rejects(cp(r1),e=>e.code==='42501');p=await cp(r2);assert.ok(!p.reuniones.some(r=>r.id===r1));assert.ok(p.reuniones.some(r=>r.id===r3));
await actor(2);p=await cp(r2);assert.ok(p.captura.integrantes.every(u=>u.id_unidad===miembros.find(u=>u.id_usuario===uid(2)).id_unidad));const cap=await panel();assert.equal(cap.ingresos.length,0);assert.equal(cap.aplicaciones.length,0);assert.ok(cap.integrantes.every(u=>!('saldo' in u)));assert.ok(cap.cargos.length>0);
await actor(1);assert.ok((await cp(r2)).captura.integrantes.length);assert.equal((await panel()).cargos.length,0);
await actor(4);await op('periodo',{nombre:'Publicación',desde:fechas.hoy,hasta:fechas.hoy});let admin=await cp();const per=admin.periodos[0].id;
await op('finalizar',{periodo:per});admin=await cp();const corte=admin.cortes[0].id;
await actor(3);p=await cp();assert.ok(p.publicacion);assert.ok(p.publicados.top_ordenado.length>15);assert.ok(p.publicados.top_ordenado.every(u=>'puntos' in u));assert.equal(p.publicados.consejeros.length,1);
assert.ok((await db.query('SELECT competencia_perfil($1) p',[uid(2)])).rows[0].p);
assert.ok((await db.query('SELECT competencia_unidad($1) p',[deAna.id_unidad])).rows[0].p.puntos>0);
await db.exec('RESET ROLE');await db.exec("UPDATE privado.competencia_cortes SET publicado_hasta=now()-interval '1 second'");await actor(3);p=await cp();assert.equal(p.publicacion,null);assert.ok(p.resultados.destacados.length>15);assert.ok(!p.publicados);assert.equal((await db.query('SELECT competencia_perfil($1) p',[uid(2)])).rows[0].p,null);
await actor(4);const reabrir=crypto.randomUUID();await op('reabrir_corte',{corte},reabrir);await op('reabrir_corte',{corte},reabrir);admin=await cp(r2);assert.equal(admin.captura.cerrada,false);assert.equal(admin.periodos[0].corte,null);await op('captura',datos(admin.captura));
await op('finalizar_ciclo',{});admin=await cp(r2);assert.equal(admin.ciclo_finalizado,true);assert.equal(admin.captura.cerrada,true);await assert.rejects(op('captura',datos(admin.captura)),e=>e.code==='22023');
await actor(3);p=await cp();assert.equal(p.publicacion.anual,true);assert.equal(p.publicacion.publicado_hasta,null);assert.ok(p.publicados.top_ordenado.length>15);
await actor(4);await op('reabrir_ciclo',{});admin=await cp(r2);assert.equal(admin.ciclo_finalizado,false);assert.equal(admin.captura.cerrada,false);await op('captura',datos(admin.captura));
await actor(3);p=await cp();assert.equal(p.publicacion,null);assert.ok(p.resultados.destacados.length>15);await assert.rejects(db.query('SELECT privado.competencia_panel_019(NULL,NULL,NULL)'),e=>e.code==='42501');
await actor(null);await assert.rejects(cp(),e=>e.code==='42501');await db.close();console.log('Competencia integrada SQL OK: empates, lectura por unidad, privacidad financiera, publicaciones y reaperturas.');
