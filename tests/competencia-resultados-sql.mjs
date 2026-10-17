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
await actor(4);
const cp=async(id=null,desde=null,hasta=null)=>(await db.query('SELECT competencia_panel($1,$2,$3) p',[id,desde,hasta])).rows[0].p;

const op=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT competencia_guardar($1,$2,$3)',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})]);

let c=await cp();assert.equal(c.criterios.find(k=>k.nombre==='Puntualidad').valor,5);
const r=crypto.randomUUID();await guardar(r,'Competencia actual','regular',true);
// Un alta sin unidad queda disponible en el pase ya programado.
await db.exec('RESET ROLE');
const libre=crypto.randomUUID();await db.query("INSERT INTO usuarios(id_usuario,id_ciclo,nombres,apellido,rol) VALUES($1,$2,'Sin','Unidad','conquistador')",[libre,ciclo]);
for(let i=0;i<18;i++)await db.query("INSERT INTO usuarios(id_ciclo,nombres,apellido,rol) VALUES($1,$2,'Prueba','conquistador')",[ciclo,'Participante '+i]);
await actor(4);
let p=await reunion(r);assert.ok(p.grupos.some(g=>g.clave==='sin-unidad'));assert.ok(p.integrantes.some(u=>u.id_usuario===libre));
const datos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion,version_config:p.version_config,integrantes:p.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:p.criterios.filter(k=>k.fuente==='manual').map(k=>k.id)})),extras:[{id_usuario:uid(3),puntos:7,motivo:'Servicio'},{id_usuario:libre,puntos:3,motivo:'Participación'}]});
c=await cp(r,fechas.hoy,fechas.hoy);assert.ok(c.captura.integrantes.every(u=>u.asistencia===null));await op('captura',datos(c.captura));
c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,32);assert.equal(c.resultados.consejeros.find(u=>u.id_usuario===uid(1)).puntos,20);
assert.ok(!c.captura.integrantes.find(u=>u.id_usuario===uid(1)).cumplidos.includes(c.criterios.find(k=>k.nombre==='Cuadernillo').id));
assert.ok(!c.resultados.individual.some(u=>u.id_usuario===uid(1)));
// Pasar lista (sin cerrar toda la reunión) descarta criterios presenciales, conserva extras.
async function lista(estados){let p=await reunion(r);for(const g of p.grupos){await db.query("SELECT reunion_accion($1,$2,'unidad',$3)",[r,p.version,JSON.stringify({clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:estados[u.id_usuario]||'asistencia'}))})]);p=await reunion(r);}}
await lista({[uid(3)]:'justificado',[uid(2)]:'falta'});
c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,12);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(2)).puntos,0);assert.equal(c.resultados.consejeros[0].puntos,25);
assert.equal(c.captura.integrantes.find(u=>u.id_usuario===uid(3)).cumplidos.length,0);
// Ni una llamada manipulada vuelve a dar Biblia/Cuadernillo a ausentes/consejeros.
await op('captura',datos(c.captura));c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,12);
const q=await panel(),periodo=q.periodos.find(p=>p.actividad===r).id;
await operar('pago',{id_ciclo:ciclo,epoca:q.epoca,id_usuario:uid(3),version:q.integrantes.find(u=>u.id_usuario===uid(3)).version,importe:1000,fecha:fechas.hoy,periodos:[periodo]});
c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,17);
await lista({[uid(3)]:'falta',[uid(2)]:'falta'});
assert.equal((await cp(r,fechas.hoy,fechas.hoy)).resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,12,'Falta conserva cuota y extras, sin asistencia');
await lista({[uid(3)]:'justificado',[uid(2)]:'falta'});
// Asignar unidad después no traslada puntos anteriores, tampoco al volver a guardar.
await db.exec('RESET ROLE');await db.query('UPDATE usuarios SET id_unidad=$1 WHERE id_usuario=$2',[deAna.id_unidad,libre]);await actor(4);
await op('captura',datos((await cp(r)).captura));c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.captura.integrantes.find(u=>u.id_usuario===libre).id_unidad,null);
assert.equal(c.resultados.individual.find(u=>u.id_usuario===libre).puntos,33);
// Estadísticas independientes; cuotas visibles solo en administración.
assert.ok(c.estadisticas.some(k=>k.fuente==='cuota'));assert.ok(c.estadisticas_consejeros.some(k=>k.criterio==='Puntualidad'));assert.ok(!c.estadisticas_consejeros.some(k=>k.criterio==='Cuadernillo'));
await actor(3);let publico=await cp();assert.equal(publico.publicacion,null);assert.equal(publico.resultados.individual.length,0);assert.equal(publico.resultados.destacados.length,0);assert.equal(publico.resultados.unidades.length,0);
await assert.rejects(cp(r),e=>e.code==='42501');await assert.rejects(op('periodo',{nombre:'Intruso',desde:fechas.hoy,hasta:fechas.hoy}),e=>e.code==='42501');
await actor(4);const fin=fechas.futuro.slice(0,4)===fechas.hoy.slice(0,4)?fechas.futuro:fechas.hoy;
await op('periodo',{nombre:'Corte temprano',desde:fechas.hoy,hasta:fin});c=await cp();assert.equal(c.periodos.length,1);assert.equal(c.cortes.length,1);
// Otra reunión futura con puntos no entra al corte de hoy.
let futura;if(fin!==fechas.hoy){futura=crypto.randomUUID();await guardar(futura,'Mañana','regular',false,fin);await op('captura',datos((await cp(futura)).captura));}
const cierre=crypto.randomUUID();await op('finalizar',{periodo:c.periodos[0].id},cierre);await op('finalizar',{periodo:c.periodos[0].id},cierre);
c=await cp(r,fechas.hoy,fechas.hoy);assert.equal(c.cortes[0].hasta,fechas.hoy);assert.equal(c.captura.cerrada,true);assert.equal(c.resultados.individual.find(u=>u.id_usuario===uid(3)).puntos,17);
const congelado=JSON.stringify(c.resultados.individual);await lista({});assert.equal(JSON.stringify((await cp(r,fechas.hoy,fechas.hoy)).resultados.individual),congelado);
await assert.rejects(op('captura',datos((await cp(r)).captura)),e=>e.code==='22023');
await actor(3);publico=await cp(null,fechas.hoy,fin);assert.ok(publico.publicacion);assert.equal(publico.resultados.consejeros.length,0);assert.equal(publico.resultados.individual.length,0);assert.equal(publico.resultados.destacados.length,15);assert.ok(publico.estadisticas.find(k=>k.criterio==='Biblia').integrantes.length>15);assert.ok(publico.resultados.destacados.every(u=>!('puntos' in u)));
assert.ok(!publico.estadisticas.some(k=>['cuota','extra'].includes(k.fuente)));assert.ok(publico.estadisticas.every(k=>k.integrantes.every(u=>u.id_usuario!==uid(1))));
assert.equal(publico.mi_puntaje.puntos,17);assert.ok((await db.query('SELECT competencia_publicacion() p')).rows[0].p);
assert.equal((await db.query('SELECT competencia_perfil($1) p',[uid(3)])).rows[0].p.puntos,17);
await assert.rejects(db.query('SELECT competencia_perfil($1)',[uid(2)]),e=>e.code==='42501');
await db.exec('RESET ROLE');await db.exec("UPDATE privado.competencia_cortes SET publicado_hasta=now()-interval '1 second'");await actor(3);
publico=await cp(null,fechas.hoy,fin);assert.equal(publico.publicacion,null);assert.equal((await db.query('SELECT competencia_publicacion() p')).rows[0].p,null);assert.equal(publico.resultados.destacados.length,0);assert.equal(publico.estadisticas.length,0);assert.equal(publico.mi_puntaje.puntos,17);
await actor(4);assert.equal((await db.query('SELECT competencia_perfil($1) p',[uid(3)])).rows[0].p.puntos,17);
await actor(null);await assert.rejects(cp(),e=>e.code==='42501');await assert.rejects(db.query('SELECT competencia_perfil($1)',[uid(3)]),e=>e.code==='42501');
await db.close();console.log('Competencia resultados SQL OK: presencia, cuotas/extras, consejeros, sin unidad, cierre temprano, privacidad y caducidad.');
