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

await db.exec(file('migrations/021_cierre_puntajes.sql'));
await db.exec(file('migrations/021_cierre_puntajes.sql'));
await actor(4);
const cp=async(id=null)=>(await db.query('SELECT reunion_integrada_panel($1) p',[id])).rows[0].p;
const op=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT reunion_integrada_guardar($1,$2,$3)',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})]);
const capturaDatos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion,version_config:p.version_config,integrantes:p.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:[p.criterios.find(k=>k.nombre==='Biblia').id]})),extras:[]});
const cierreDatos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion});
async function cerrarPase(id){let p=await reunion(id);for(const g of p.grupos){await db.query("SELECT reunion_accion($1,$2,'unidad',$3)",[id,p.version,JSON.stringify({clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:'asistencia'}))})]);p=await reunion(id);}await db.query("SELECT reunion_accion($1,$2,'cerrar','{}')",[id,p.version]);}
await db.exec('RESET ROLE');await db.query("INSERT INTO usuarios(id_ciclo,nombres,apellido,rol,id_unidad) VALUES($1,'Otra','Conquistadora','conquistador',$2)",[ciclo,deAna.id_unidad]);await actor(4);

await db.exec('RESET ROLE');await db.exec(file('migrations/022_reunion_unificada.sql'));await db.exec(file('migrations/022_reunion_unificada.sql'));await actor(4);
assert.equal((await db.query('SELECT competencia_panel() p')).rows[0].p.api_version,21);
const id=crypto.randomUUID();await guardar(id,'Unificada','regular',true);
let p=await cp(id);const clave=p.captura.integrantes[0].id_unidad||'sin-unidad';
function datos(p,clave){const us=p.captura.integrantes.filter(u=>(u.id_unidad||'sin-unidad')===clave);return {...capturaDatos(p.captura),unidad:clave,epoca:p.epoca,asistencias:us.map(u=>({id_usuario:u.id_usuario,estado:'asistencia'})),integrantes:us.map(u=>({id_usuario:u.id_usuario,cumplidos:[]})),pagos:[],extras:[]};}
const d=datos(p,clave);const pagador=p.finanzas.integrantes.find(u=>(u.id_unidad||'sin-unidad')===clave);const antes=p.finanzas.ingresos.length;await assert.rejects(op('unidad_integrada',{...d,version_config:-1,pagos:pagador?[{id_usuario:pagador.id_usuario,version:pagador.version,importe:1000}]:[]}),e=>e.code==='40001');assert.equal((await reunion(id)).version,p.captura.version_reunion);assert.equal((await cp(id)).finanzas.ingresos.length,antes);const operacion=crypto.randomUUID();await op('unidad_integrada',d,operacion);await op('unidad_integrada',d,operacion);
p=await cp(id);assert.equal(p.captura.version,1);assert.ok(p.captura.integrantes.filter(u=>(u.id_unidad||'sin-unidad')===clave).every(u=>u.asistencia==='asistencia'));
const grupos=[...new Set(p.captura.integrantes.map(u=>u.id_unidad||'sin-unidad'))];
for(const g of grupos){p=await cp(id);const d=datos(p,g);const u=p.finanzas.integrantes.find(u=>(u.id_unidad||'sin-unidad')===g);if(u)d.pagos=[{id_usuario:u.id_usuario,version:u.version,importe:1000}];const operacion=crypto.randomUUID();await op('unidad_integrada',d,operacion);const ingresos=(await cp(id)).finanzas.ingresos.length;await op('unidad_integrada',d,operacion);assert.equal((await cp(id)).finanzas.ingresos.length,ingresos);if(u)assert.equal(ingresos,p.finanzas.ingresos.length+1);}
p=await cp(id);await op('cerrar_integrada',{...cierreDatos(p.captura),epoca:p.epoca});assert.equal((await reunion(id)).estado,'cerrada');assert.equal((await cp(id)).captura.puntaje_cerrado,true);
await actor(3);const lector=await cp(id);assert.equal(lector.finanzas,undefined);await assert.rejects(op('unidad_integrada',d),e=>e.code==='42501');await db.close();console.log('Reunión unificada SQL OK');
