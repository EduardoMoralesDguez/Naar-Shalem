import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {database,historical} from '../scripts/lib/database.mjs';
const master=await database(),old=await historical();
await master.exec(readFileSync(new URL('../supabase/schema.sql',import.meta.url),'utf8'));
const catalog=[
 `SELECT n.nspname,role,has_schema_privilege(role,n.oid,'USAGE') usage,has_schema_privilege(role,n.oid,'CREATE') create_allowed FROM pg_namespace n CROSS JOIN unnest(ARRAY['anon','authenticated']) role WHERE n.nspname IN ('public','privado') ORDER BY 1,2`,
 `SELECT n.nspname,c.relname,a.attname,role,privilege,has_column_privilege(role,c.oid,a.attnum,privilege) allowed FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace JOIN pg_attribute a ON a.attrelid=c.oid CROSS JOIN unnest(ARRAY['anon','authenticated']) role CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE']) privilege WHERE n.nspname IN ('public','privado') AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped ORDER BY 1,2,3,4,5`,
 `SELECT table_schema,table_name,column_name,data_type,udt_name,is_nullable,column_default FROM information_schema.columns WHERE table_schema IN ('public','privado') ORDER BY 1,2,ordinal_position`,
 `SELECT n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity,c.reloptions FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','privado') AND c.relkind IN ('r','v') ORDER BY 1,2`,
 `SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args,pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','privado') ORDER BY 1,2,3`,
 `SELECT n.nspname,c.relname,k.conname,pg_get_constraintdef(k.oid,true) def FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','privado') AND k.contype<>'n' ORDER BY 1,2,3`,
 `SELECT * FROM pg_policies WHERE schemaname IN ('public','privado','storage') ORDER BY schemaname,tablename,policyname`,
 `SELECT schemaname,tablename,indexname,indexdef FROM pg_indexes WHERE schemaname IN ('public','privado') ORDER BY 1,2,3`,
 `SELECT n.nspname,c.relname,t.tgname,pg_get_triggerdef(t.oid,true) def FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('public','privado') AND NOT t.tgisinternal ORDER BY 1,2,3`,
 `SELECT n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args,role,has_function_privilege(role,p.oid,'EXECUTE') allowed FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace CROSS JOIN unnest(ARRAY['anon','authenticated']) role WHERE n.nspname IN ('public','privado') ORDER BY 1,2,3,4`,
 `SELECT n.nspname,c.relname,role,privilege,has_table_privilege(role,c.oid,privilege) allowed FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace CROSS JOIN unnest(ARRAY['anon','authenticated']) role CROSS JOIN unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE']) privilege WHERE n.nspname IN ('public','privado') AND c.relkind IN ('r','v') ORDER BY 1,2,3,4`
];
// PostgreSQL redistribuye el cast de arrays varchar al restaurar CHECK: misma coerción a text.
const normalize=rows=>rows.map(r=>({...r,...(r.def?{def:r.def.replaceAll('::character varying::text','::character varying').replaceAll(']::text[]',']')}: {})}));
for(const [i,q] of catalog.entries())assert.deepEqual(normalize((await master.query(q)).rows),normalize((await old.query(q)).rows),'Catálogo '+i);
// Cada RPC literal utilizada por el frontend existe en el estado consolidado.
const serviceRoot=new URL('../frontend/js/services/',import.meta.url);
const functionNames=new Set((await master.query("SELECT proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'")).rows.map(r=>r.proname));
for(const file of readdirSync(serviceRoot).filter(f=>f.endsWith('.js'))){const source=readFileSync(new URL(file,serviceRoot),'utf8');for(const m of source.matchAll(/(?:\.rpc|\brpc)\(\s*['"](\w+)['"]/g))assert.ok(functionNames.has(m[1]),file+': RPC ausente '+m[1]);}
assert.equal((await master.query('select count(*)::int n from usuarios')).rows[0].n,0);
assert.equal((await master.query('select count(*)::int n from privado.cuentas_miembros')).rows[0].n,0);
await assert.rejects(master.exec(readFileSync(new URL('../supabase/schema.sql',import.meta.url),'utf8')),/base ya contiene/);
await master.exec('ROLLBACK');
// Flujo real sobre el SQL maestro: cuenta, alta, reunión, cobro, captura y cierre.
const ciclo=(await master.query('select id_ciclo from ciclos where es_activo')).rows[0].id_ciclo;
const admin='d0000000-0000-4000-8000-000000000004',conqui='d0000000-0000-4000-8000-000000000005',auth='f0000000-0000-4000-8000-000000000004';
await master.query("INSERT INTO usuarios(id_usuario,id_ciclo,nombres,apellido,rol) VALUES($1,$3,'Prueba','Directiva','directiva'),($2,$3,'Prueba','Conquistador','conquistador')",[admin,conqui,ciclo]);
await master.query('INSERT INTO auth.users(id) VALUES($1)',[auth]);
await master.query('SELECT privado.vincular_cuenta($1,$2)',[admin,auth]);
await master.query("SELECT set_config('request.jwt.claim.sub',$1,false)",[auth]);await master.exec('SET ROLE authenticated');
assert.equal((await master.query('select * from mi_perfil()')).rows[0].rol,'directiva');
const id=crypto.randomUUID();const hoy=(await master.query("select (now() AT TIME ZONE 'America/Mexico_City')::date::text hoy")).rows[0].hoy;
await master.query("SELECT calendario_guardar($1,null,$2,'09:00','Validación maestro',true,'regular',$2,null,null)",[id,hoy]);
let panel=(await master.query('SELECT reunion_integrada_panel($1) p',[id])).rows[0].p;
let c=panel.captura;
const datos={id_ciclo:ciclo,reunion:id,unidad:'sin-unidad',epoca:panel.epoca,version:c.version,version_reunion:c.version_reunion,version_config:c.version_config,asistencias:c.integrantes.map(u=>({id_usuario:u.id_usuario,estado:'asistencia'})),integrantes:c.integrantes.map(u=>({id_usuario:u.id_usuario,cumplidos:c.criterios.filter(k=>k.fuente==='manual').map(k=>k.id)})),extras:[],pagos:[{id_usuario:conqui,importe:1000,version:panel.finanzas.integrantes.find(u=>u.id_usuario===conqui).version}]};
const op=crypto.randomUUID();for(let i=0;i<2;i++)await master.query("SELECT reunion_integrada_guardar($1,'unidad_integrada',$2)",[op,JSON.stringify(datos)]);
panel=(await master.query('SELECT reunion_integrada_panel($1) p',[id])).rows[0].p;c=panel.captura;
assert.equal(panel.finanzas.ingresos.length,1);
await master.query("SELECT reunion_integrada_guardar($1,'cerrar_integrada',$2)",[crypto.randomUUID(),JSON.stringify({id_ciclo:ciclo,reunion:id,epoca:panel.epoca,version:c.version,version_reunion:c.version_reunion})]);
assert.equal((await master.query('SELECT reunion_integrada_panel($1) p',[id])).rows[0].p.captura.puntaje_cerrado,true);
await master.exec('RESET ROLE;SET ROLE anon');await assert.rejects(master.query('select * from usuarios'),e=>e.code==='42501');await assert.rejects(master.query('select * from privado.usuarios_salud'),e=>e.code==='42501');
console.log('SQL maestro OK: restauración limpia; equivalencia de columnas, funciones, FK, índices, triggers, RLS y permisos; sin personas ficticias; reinstalación bloqueada.');
await master.close();await old.close();
