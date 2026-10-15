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
const org=async(c=null)=>(await db.query('SELECT organizacion_panel($1) p',[c])).rows[0].p;
const action=async(a,d)=>db.query('SELECT organizacion_guardar($1,$2)',[a,JSON.stringify({id_ciclo:ciclo,...d})]);
await actor(0);await assert.rejects(org());
await actor(4);
let p=await org();assert.equal(p.integrantes.length,4);
const un=crypto.randomUUID(),cl=crypto.randomUUID();
await action('unidad',{id:un,nombre:'Jade',lema:'Siempre',porra:'Jade',version:null});
await action('clase',{id:cl,nombre:'Explorador',color:'Verde',version:null});
p=await org();const ana=()=>p.integrantes.find(u=>u.id_usuario===uid(3));
await action('asignar',{id:uid(3),version:ana().version,rol:'subcapitan',unidad:un,clase:cl});
p=await org();assert.equal(ana().id_unidad,un);
await assert.rejects(action('asignar',{id:uid(3),version:1,rol:'conquistador',unidad:un,clase:cl}),e=>e.code==='40001');
// Resumen ponderado por convocatoria y unidad histórica: A+J / total.
assert.equal(p.unidades.find(u=>u.id_unidad===un).asistencia.porcentaje,null);
await db.exec('RESET ROLE');
const cerrada1=crypto.randomUUID(),cerrada2=crypto.randomUUID(),borrador=crypto.randomUUID(),eliminada=crypto.randomUUID(),anulada=crypto.randomUUID();
for(const [n,id,estado,eliminado] of [[80,cerrada1,'cerrada',false],[81,cerrada2,'cerrada',false],[82,borrador,'borrador',false],[83,eliminada,'cerrada',true],[84,anulada,'anulada',false]]){
 await db.query('INSERT INTO privado.reuniones(id,id_ciclo,fecha,numero,nombre,estado,eliminado) VALUES($1,$2,$3,$4,$5,$6,$7)',[id,ciclo,fechas.hoy,n,'Resumen '+n,estado,eliminado]);
}
for(const [reunion,usuario,estado,exento] of [[cerrada1,uid(3),'asistencia',false],[cerrada1,uid(2),'justificado',false],[cerrada2,uid(3),'falta',false],[cerrada1,uid(4),'falta',true],[borrador,uid(3),'falta',false],[eliminada,uid(3),'falta',false],[anulada,uid(3),'falta',false]]){
 await db.query('INSERT INTO privado.convocados(reunion,id_usuario,id_unidad,unidad,estado,exento_asistencia) VALUES($1,$2,$3,$4,$5,$6)',[reunion,usuario,un,'Jade',estado,exento]);
}
await actor(4);p=await org();
assert.deepEqual(p.unidades.find(u=>u.id_unidad===un).asistencia,{total:3,asistencias:1,justificados:1,faltas:1,porcentaje:67});
assert.ok(!JSON.stringify(p.unidades.find(u=>u.id_unidad===un).asistencia).includes(uid(3)));
await actor(3);p=await org();await action('identidad',{id:un,version:p.unidades.find(u=>u.id_unidad===un).version,lema:'Nuevo lema',porra:'Nueva porra',nombre:'No puede renombrar'});
p=await org();assert.equal(p.unidades.find(u=>u.id_unidad===un).nombre,'Jade');
await assert.rejects(action('unidad',{id:crypto.randomUUID(),nombre:'Intruso'}),e=>e.code==='42501');
await assert.rejects(action('identidad',{id:unidades[0].id_unidad,version:1,lema:'No'}),e=>e.code==='42501');
await assert.rejects(action('asignar',{id:uid(2),version:1,rol:'conquistador'}),e=>e.code==='42501');
const foto=un+'/'+crypto.randomUUID()+'.webp';
await db.query('INSERT INTO storage.objects(bucket_id,name) VALUES($1,$2)',['unidades-fotos',foto]);
await assert.rejects(db.query('INSERT INTO storage.objects(bucket_id,name) VALUES($1,$2)',['unidades-fotos',unidades[0].id_unidad+'/'+crypto.randomUUID()+'.webp']),e=>e.code==='42501');
p=await org();await action('identidad',{id:un,version:p.unidades.find(u=>u.id_unidad===un).version,lema:'Con foto',porra:'Jade',foto_path:foto});
assert.equal((await db.query('SELECT name FROM storage.objects WHERE name=$1',[foto])).rows.length,1);
await assert.rejects(db.query('SELECT * FROM privado.inscripciones'),e=>e.code==='42501');
await actor(1);p=await org();const propia=p.unidades.find(u=>u.id_unidad===miembros.find(u=>u.id_usuario===uid(1)).id_unidad);
await action('identidad',{id:propia.id_unidad,version:propia.version,lema:'Consejera',porra:'Unidad'});
await actor(4);p=await org();
await assert.rejects(action('estado_unidad',{id:un,version:p.unidades.find(u=>u.id_unidad===un).version,activo:false}),e=>e.code==='22023');
// El límite también protege el editor de integrantes existente y escrituras internas.
await db.exec('RESET ROLE');
await assert.rejects(db.query("UPDATE usuarios SET rol='subcapitan',id_unidad=$1 WHERE id_usuario=$2",[un,uid(2)]),e=>e.code==='23505');
await actor(4);p=await org();const cicloAntes=p.id_ciclo;
const ingresosAntes=(await panel()).ingresos.length;
await action('ciclo',{anio:p.ciclos.find(c=>c.es_activo).anio+1});
p=await org();assert.notEqual(p.id_ciclo,cicloAntes);assert.equal(p.unidades.length,0);assert.ok(p.integrantes.every(u=>!u.id_unidad&&!u.id_clase));
assert.equal(p.integrantes.find(u=>u.id_usuario===uid(2)).rol,'conquistador');
assert.equal(p.integrantes.find(u=>u.id_usuario===uid(4)).rol,'directiva');
const archivo=await org(cicloAntes);assert.equal(archivo.vigente,false);assert.equal(archivo.unidades.find(u=>u.id_unidad===un).asistencia.porcentaje,67);assert.equal(archivo.integrantes.find(u=>u.id_usuario===uid(3)).unidad,'Jade');
assert.equal(archivo.integrantes.find(u=>u.id_usuario===uid(3)).clase,'Explorador');
await assert.rejects(action('unidad',{id:un,nombre:'Tocar pasado',version:2}),e=>e.code==='40001');
await actor(2);await assert.rejects(org(cicloAntes),e=>e.code==='42501');
await db.exec('RESET ROLE');
assert.ok((await db.query('SELECT count(*) n FROM privado.cuota_ingresos')).rows[0].n>=ingresosAntes);
await db.exec(m14);await db.exec(m15); // No reescribe el archivo ni copia unidades al año nuevo.
assert.equal((await db.query('SELECT count(*) n FROM privado.inscripciones')).rows[0].n,8);
const reunionesAntes=(await db.query('SELECT count(*) n FROM privado.reuniones')).rows[0].n;
await db.exec(file('admin/limpiar_cuotas_asistencias.sql'));
assert.equal((await db.query('SELECT count(*) n FROM privado.reuniones')).rows[0].n,reunionesAntes);
assert.equal((await db.query('SELECT count(*) n FROM public.asistencias')).rows[0].n,0);
assert.equal((await db.query('SELECT count(*) n FROM privado.cuota_ingresos')).rows[0].n,0);
assert.equal((await db.query('SELECT count(*) n FROM public.usuarios')).rows[0].n,4);
assert.equal((await db.query('SELECT count(*) n FROM privado.inscripciones')).rows[0].n,8);
console.log('Organización SQL OK: roles, identidad, cargos únicos, asignaciones, ciclos, archivo, conservación y limpieza.');
await db.close();
