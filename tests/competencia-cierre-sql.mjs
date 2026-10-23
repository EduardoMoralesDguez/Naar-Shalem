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
const cp=async(id=null)=>(await db.query('SELECT competencia_panel($1) p',[id])).rows[0].p;
const op=async(accion,datos,id=crypto.randomUUID())=>db.query('SELECT competencia_guardar($1,$2,$3)',[id,accion,JSON.stringify({id_ciclo:ciclo,...datos})]);
const capturaDatos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion,version_config:p.version_config,integrantes:p.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:[p.criterios.find(k=>k.nombre==='Biblia').id]})),extras:[]});
const cierreDatos=p=>({reunion:p.id,version:p.version,version_reunion:p.version_reunion});
async function cerrarPase(id){let p=await reunion(id);for(const g of p.grupos){await db.query("SELECT reunion_accion($1,$2,'unidad',$3)",[id,p.version,JSON.stringify({clave:g.clave,integrantes:p.integrantes.filter(u=>u.clave===g.clave).map(u=>({id_usuario:u.id_usuario,estado:'asistencia'}))})]);p=await reunion(id);}await db.query("SELECT reunion_accion($1,$2,'cerrar','{}')",[id,p.version]);}
await db.exec('RESET ROLE');await db.query("INSERT INTO usuarios(id_ciclo,nombres,apellido,rol,id_unidad) VALUES($1,'Otra','Conquistadora','conquistador',$2)",[ciclo,deAna.id_unidad]);await actor(4);
const ids=Array.from({length:4},()=>crypto.randomUUID());
for(let i=0;i<4;i++)await guardar(ids[i],'Reunión '+i,'regular',true,i===3?fechas.futuro:fechas.hoy,{hora:('0'+(8+i)).slice(-2)+':00'});
// Todos los roles consultan a su unidad completa, incluso quien es conquistador.
await cerrarPase(ids[0]);await cerrarPase(ids[1]);
for(const n of [1,2,3]){
 await actor(n);const listado=(await db.query('SELECT * FROM reuniones_listar_turnos()')).rows;
 assert.ok(!listado.some(r=>r.id===ids[0]));assert.ok([ids[1],ids[2],ids[3]].every(id=>listado.some(r=>r.id===id)));
 await assert.rejects(reunion(ids[0]),e=>e.code==='42501');
 const rp=await reunion(ids[1]);const propia=miembros.find(u=>u.id_usuario===uid(n)).id_unidad;
 assert.ok(rp.integrantes.length);if(n===3)assert.ok(rp.integrantes.length>=2);assert.ok(rp.integrantes.every(u=>u.clave===propia));
 const resumen=(await db.query('SELECT asistencia_resumen($1) p',[uid(n)])).rows[0].p;assert.equal(resumen.total_registros,2);await assert.rejects(db.query('SELECT asistencia_resumen($1)',[uid(4)]),e=>e.code==='42501');
 const historial=(await db.query('SELECT * FROM historial_matriz_turnos()')).rows;assert.ok(historial.every(f=>f.reunion===ids[1]&&f.unidad_clave===propia));
}
await actor(4);await op('captura',capturaDatos((await cp(ids[0])).captura));
// Guardar ya alimenta el Top aleatorio, sin corte ni cierre de puntaje obligatorio.
for(const n of [1,2,3]){await actor(n);const p=await cp(ids[0]);assert.equal(p.api_version,21);assert.ok(p.resultados.destacados.length);assert.ok(p.resultados.destacados.every(x=>!('puntos' in x)));assert.equal(p.publicacion,null);assert.ok(p.captura.solo_lectura);assert.ok(p.reuniones.some(r=>r.id===ids[3]));}
await actor(4);const p=(await cp(ids[0])).captura;assert.equal(p.guardada,true);assert.equal(p.puntaje_cerrado,false);
const cierreId=crypto.randomUUID();await op('cerrar_puntajes',cierreDatos(p),cierreId);await op('cerrar_puntajes',cierreDatos(p),cierreId);
let cerrado=(await cp(ids[0])).captura;assert.equal(cerrado.cerrada,true);assert.equal(cerrado.puede_reabrir,true);assert.equal(cerrado.version,p.version+1);
await assert.rejects(op('captura',capturaDatos(cerrado)),e=>e.code==='22023');
await assert.rejects(op('reabrir_puntajes',cierreDatos(p)),e=>e.code==='40001');
await actor(3);await assert.rejects(op('reabrir_puntajes',cierreDatos(cerrado)),e=>e.code==='42501');
await actor(4);await op('captura',capturaDatos((await cp(ids[2])).captura));await op('cerrar_puntajes',cierreDatos((await cp(ids[2])).captura));
await actor(3);let publico=await cp(ids[2]);assert.ok(!publico.reuniones.some(r=>r.id===ids[0]));assert.ok(publico.reuniones.some(r=>r.id===ids[1]));assert.ok(publico.reuniones.some(r=>r.id===ids[3]));await assert.rejects(cp(ids[0]),e=>e.code==='42501');
// Asistencias sigue cerrada en otra reunión: los dos cierres son independientes.
assert.equal((await reunion(ids[2])).estado,'borrador');
await actor(4);await op('reabrir_puntajes',cierreDatos((await cp(ids[2])).captura));assert.equal((await cp(ids[2])).captura.puntaje_cerrado,false);
await actor(3);assert.ok((await cp(ids[0])).captura.puntaje_cerrado);assert.ok((await cp(ids[2])).captura);
// El corte mantiene el bloqueo y los cierres sobreviven a reinstalar la migración.
await actor(4);await op('periodo',{nombre:'Prueba',desde:fechas.hoy,hasta:fechas.hoy});const periodo=(await cp()).periodos[0].id;await op('finalizar',{periodo});
assert.equal((await cp(ids[0])).captura.puede_reabrir,false);await assert.rejects(op('reabrir_puntajes',cierreDatos((await cp(ids[0])).captura)),e=>e.code==='22023');
await db.exec('RESET ROLE');await db.exec(file('migrations/021_cierre_puntajes.sql'));assert.equal((await db.query('SELECT cerrado FROM privado.competencia_hojas WHERE reunion=$1',[ids[0]])).rows[0].cerrado,true);
await actor(3);await assert.rejects(db.query('SELECT privado.competencia_panel_020(NULL,NULL,NULL)'),e=>e.code==='42501');
await actor(null);await assert.rejects(cp(),e=>e.code==='42501');await db.close();console.log('Cierre puntajes SQL OK: consulta por unidad, última cerrada, abiertos futuros, Top sin corte, cierre independiente, reintentos y permisos.');
