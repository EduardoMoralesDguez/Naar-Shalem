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
const a=crypto.randomUUID(),b=crypto.randomUUID(),futura=crypto.randomUUID();
await actor(3);await assert.rejects(guardar(a,'Sin permiso'),e=>e.code==='42501');
await actor(4);
await guardar(a,'Mañana','regular',true);await guardar(a,'Mañana','regular',true);
await guardar(b,'Tarde','regular',true,fechas.hoy,{hora:'16:00'});
let p=await panel();
const pa=p.periodos.find(x=>x.actividad===a),pb=p.periodos.find(x=>x.actividad===b);
assert.ok(pa&&pb);assert.notEqual(pa.id,pb.id);assert.equal(pa.fecha,pb.fecha);
assert.equal(p.cargos.filter(x=>[pa.id,pb.id].includes(x.periodo)).length,4);
const ingreso=crypto.randomUUID(),u=p.integrantes.find(x=>x.id_usuario===uid(3));
const datosPago={id_ciclo:ciclo,epoca:p.epoca,id_usuario:u.id_usuario,version:u.version,importe:2000,fecha:fechas.hoy,periodos:[pa.id,pb.id]};
await operar('pago',datosPago,ingreso);await operar('pago',datosPago,ingreso);
p=await panel();assert.equal(p.aplicaciones.filter(x=>x.ingreso===ingreso).length,2);
// Cancelar y restaurar solo afectan al cobro de esta reunión.
await db.query('SELECT calendario_cancelar($1,$2,$3)',[a,await version(a),'Prueba de cancelación']);
p=await panel();assert.ok(!p.periodos.some(x=>x.id===pa.id));assert.ok(p.periodos.some(x=>x.id===pb.id));
assert.equal(p.integrantes.find(x=>x.id_usuario===uid(3)).saldo,1000);
await db.query("SELECT reunion_accion($1,$2,'restaurar')",[a,await version(a)]);
p=await panel();assert.equal(p.integrantes.find(x=>x.id_usuario===uid(3)).saldo,0);assert.equal(p.ingresos.filter(x=>x.id===ingreso).length,1);
// Cierre anticipado: sigue requiriendo revisar todas las unidades.
await guardar(futura,'Pase futuro','regular',false,fechas.futuro);
let r=await reunion(futura);
await assert.rejects(db.query("SELECT reunion_accion($1,$2,'cerrar')",[futura,r.version]),e=>e.code==='22023');
for(const grupo of r.grupos){r=await reunion(futura);await db.query("SELECT reunion_accion($1,$2,'unidad',$3)",[futura,r.version,JSON.stringify({clave:grupo.clave,integrantes:r.integrantes.filter(i=>i.clave===grupo.clave).map(i=>({id_usuario:i.id_usuario,estado:'asistencia'}))})]);}
r=await reunion(futura);await db.query("SELECT reunion_accion($1,$2,'cerrar')",[futura,r.version]);
assert.equal((await reunion(futura)).estado,'cerrada');
assert.ok((await db.query('SELECT * FROM historial_matriz_turnos()')).rows.some(x=>x.reunion===futura));
// Eliminar también quita reuniones cerradas de historial, sin borrar dinero.
const versionF=await version(futura);await borrar(futura);await db.query('SELECT calendario_eliminar($1,$2)',[futura,versionF]);
assert.ok(!(await listar()).some(x=>x.id===futura));
assert.ok(!(await db.query('SELECT * FROM historial_matriz_turnos()')).rows.some(x=>x.reunion===futura));
await assert.rejects(reunion(futura),e=>e.code==='42501');
await assert.rejects(db.query("SELECT reunion_accion($1,$2,'restaurar')",[futura,versionF+1]),e=>e.code==='42501');
await assert.rejects(guardar(futura,'Pase futuro','regular',false,fechas.futuro),e=>e.code==='40001');
await guardar(crypto.randomUUID(),'Pase futuro','regular',false,fechas.futuro); // Nombre reutilizable con UUID nuevo.
const previa=await version(b);await guardar(b,'Tarde editada','regular',true,fechas.hoy,{version:previa,hora:'17:00'});
await assert.rejects(db.query('SELECT calendario_eliminar($1,$2)',[b,previa]),e=>e.code==='40001');
await borrar(b);p=await panel();assert.equal(p.integrantes.find(x=>x.id_usuario===uid(3)).saldo,1000);assert.ok(p.ingresos.some(x=>x.id===ingreso));
// Todo día de la semana admite cobro independiente.
for(let i=0;i<7;i++){
 const fecha=(await db.query('SELECT ($1::date+$2::int)::text f',[fechas.hoy,i])).rows[0].f;
 await guardar(crypto.randomUUID(),'Día '+i,'regular',true,fecha);
}
const practica=crypto.randomUUID(),parcial=crypto.randomUUID(),porClase=crypto.randomUUID(),evento=crypto.randomUUID();
await guardar(practica,'Práctica de marchas','practica');
await guardar(parcial,'Aviso de unidad','parcial',false,fechas.hoy,{unidad:deAna.id_unidad});
const otraClase=clases.find(c=>c.id_clase!==deAna.id_clase).id_clase;
await guardar(porClase,'Aviso de clase','parcial',false,fechas.hoy,{clase:otraClase});
const fin=(await db.query("SELECT (date_trunc('month',$1::date)+interval '1 month 3 days')::date::text f",[fechas.hoy])).rows[0].f;
await guardar(evento,'Camporee','evento',false,fechas.hoy,{fin});
assert.ok((await listar(fin,fin)).some(x=>x.id===evento));
const listaPases=(await db.query('SELECT * FROM reuniones_listar_turnos()')).rows;
for(const id of [practica,parcial,porClase,evento]){
 assert.ok(!listaPases.some(x=>x.id===id));await assert.rejects(reunion(id),e=>e.code==='42501');
 await assert.rejects(db.query("SELECT reunion_accion($1,$2,'cerrar')",[id,await version(id)]),e=>e.code==='22023');
}
assert.ok(!(await panel()).periodos.some(p=>[practica,parcial,porClase,evento].includes(p.actividad)));
await assert.rejects(guardar(crypto.randomUUID(),'Cobro inválido','practica',true),e=>e.code==='22023');
await assert.rejects(guardar(crypto.randomUUID(),'Falta destinatario','parcial'),e=>e.code==='22023');
await assert.rejects(guardar(crypto.randomUUID(),'Dos destinatarios','parcial',false,fechas.hoy,{unidad:deAna.id_unidad,clase:otraClase}),e=>e.code==='22023');
// Los cambios de tipo antes del pase no dejan convocatorias residuales.
const convertir=crypto.randomUUID();await guardar(convertir,'Convertible','regular',true);
await guardar(convertir,'Convertible','practica',false,fechas.hoy,{version:await version(convertir)});
assert.ok(!(await panel()).periodos.some(p=>p.actividad===convertir));
await guardar(convertir,'Convertible','regular',true,fechas.hoy,{version:await version(convertir)});
assert.equal((await reunion(convertir)).integrantes.length,3);
await actor(3);let l=await listar();assert.ok(l.some(x=>x.id===parcial));assert.ok(!l.some(x=>x.id===porClase));assert.ok(l.some(x=>x.id===evento));
await assert.rejects(borrar(a),e=>e.code==='42501');
await actor(2);await assert.rejects(guardar(crypto.randomUUID(),'Capitán'),e=>e.code==='42501');
await assert.rejects(db.query('SELECT calendario_eliminar($1,$2)',[a,1]),e=>e.code==='42501');
await actor(0);await assert.rejects(listar(),e=>e.code==='42501');
// Limpieza explícita: conserva miembros y cuentas, no regenera semillas al repetir migración.
await db.exec('RESET ROLE');
const conteo=async()=>(await db.query('SELECT (SELECT count(*) FROM usuarios) miembros,(SELECT count(*) FROM privado.cuentas_miembros) cuentas,(SELECT count(*) FROM conquistador_especialidades) insignias')).rows[0];
const antes=await conteo();
await db.exec(migration12);
const limpiar=file('admin/limpiar_actividad.sql');await db.exec(limpiar);
assert.deepEqual(await conteo(),antes);
assert.equal((await db.query('SELECT count(*) n FROM privado.reuniones')).rows[0].n,0);
await db.exec(migration12);await actor(4);
assert.equal((await listar()).length,0);assert.equal((await panel()).ingresos.length,0);
assert.equal((await panel()).periodos.length,0);assert.equal((await db.query('SELECT * FROM historial_matriz_turnos()')).rows.length,0);
await assert.rejects(operar('pago',datosPago,ingreso),e=>e.code==='40001');
const sinEpoca={...datosPago};delete sinEpoca.epoca;
await assert.rejects(operar('pago',sinEpoca),e=>e.code==='40001');
const nueva=crypto.randomUUID();await guardar(nueva,'Nueva después de limpieza','regular',true);
p=await panel();const cuota=p.periodos.find(x=>x.actividad===nueva),usuario=p.integrantes.find(x=>x.id_usuario===uid(3));
await operar('pago',{...datosPago,epoca:p.epoca,version:usuario.version,importe:1000,periodos:[cuota.id]});
assert.equal((await panel()).ingresos.length,1);
await db.exec('RESET ROLE');await db.exec(limpiar);await db.exec(limpiar);
assert.deepEqual(await conteo(),antes);
console.log('Tipos SQL OK: cobros independientes cualquier día, cierre anticipado, avisos segmentados/rangos, eliminación, permisos y limpieza con bloqueo de pagos offline antiguos.');
await db.close();
