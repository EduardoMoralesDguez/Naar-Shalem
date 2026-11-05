// Deriva definiciones finales de PostgreSQL, no concatena migraciones.
import {writeFileSync} from 'node:fs';
import {historical} from './lib/database.mjs';
const db=await historical();
const rows=async q=>(await db.query(q)).rows;
const ident=s=>'"'+s.replaceAll('"','""')+'"';
const literal=s=>s===null?'NULL':"'"+String(s).replaceAll("'","''")+"'";
const name=r=>ident(r.nspname)+'.'+ident(r.relname||r.proname);
const scope="n.nspname IN ('public','privado')";
const out=[`-- Naar-Shalem: instalación NUEVA, estado final de 001–024.
-- Generado desde catálogos PostgreSQL por scripts/consolidar-schema.mjs.
-- No ejecutar sobre una instalación existente. No incluye personas ni movimientos de prueba.
-- Supabase proporciona auth.uid(), auth.users, roles anon/authenticated y Storage.
BEGIN;
SET LOCAL check_function_bodies = false;
SET LOCAL search_path = public;
DO $$ BEGIN
 IF to_regclass('public.usuarios') IS NOT NULL OR to_regclass('privado.migraciones') IS NOT NULL THEN
 RAISE EXCEPTION 'La base ya contiene Naar-Shalem. Usa migraciones incrementales.';
 END IF;
 IF to_regclass('auth.users') IS NULL OR to_regclass('storage.objects') IS NULL THEN
 RAISE EXCEPTION 'Se requiere un proyecto Supabase con Auth y Storage.';
 END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS privado;
-- UUID utiliza gen_random_uuid(), nativo de PostgreSQL 13+. No requiere extensión.
`];
const emit=s=>out.push(s);
const tables=await rows(`SELECT c.oid,n.nspname,c.relname,c.relrowsecurity,c.relforcerowsecurity FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} AND c.relkind='r' ORDER BY 2,3`);
const views=await rows(`SELECT c.oid,n.nspname,c.relname,pg_get_viewdef(c.oid,true) def FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} AND c.relkind='v' ORDER BY 2,3`);
const unsupported=await rows(`SELECT c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE ${scope} AND c.relkind IN ('S','m','p','f') UNION ALL SELECT t.typname FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace WHERE ${scope} AND t.typtype IN ('e','d')`);
if(unsupported.length)throw new Error('Objetos nuevos necesitan exportador: '+JSON.stringify(unsupported));
emit('-- Tablas: columnas y nulabilidad finales.');
for(const t of tables){const cols=await rows(`SELECT a.attname,format_type(a.atttypid,a.atttypmod) type,a.attnotnull,a.attgenerated,a.attidentity FROM pg_attribute a WHERE a.attrelid=${t.oid} AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum`);if(cols.some(c=>c.attgenerated||c.attidentity))throw new Error('Columna generada/identity nueva');emit(`CREATE TABLE ${name(t)} (\n${cols.map(c=>'  '+ident(c.attname)+' '+c.type+(c.attnotnull?' NOT NULL':'')).join(',\n')}\n);`);}
emit('-- Funciones finales: conserva SECURITY DEFINER, search_path y firma exactos.');
const functions=await rows(`SELECT p.oid,n.nspname,p.proname,pg_get_function_identity_arguments(p.oid) args,pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE ${scope} AND p.prokind='f' ORDER BY 2,3,4`);
for(const f of functions)emit(f.def.trim()+';');
emit('-- Defaults y restricciones. Las FK se agregan después de crear todas las tablas.');
for(const t of tables){for(const d of await rows(`SELECT a.attname,pg_get_expr(d.adbin,d.adrelid) def FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid=d.adrelid AND a.attnum=d.adnum WHERE d.adrelid=${t.oid} ORDER BY a.attnum`))emit(`ALTER TABLE ${name(t)} ALTER COLUMN ${ident(d.attname)} SET DEFAULT ${d.def};`);}
for(const kind of ['primary','foreign'])for(const t of tables)for(const c of await rows(`SELECT conname,pg_get_constraintdef(oid,true) def FROM pg_constraint WHERE conrelid=${t.oid} AND contype<>'n' AND contype ${kind==='primary'?"<> 'f'":"= 'f'"} ORDER BY conname`))emit(`ALTER TABLE ${name(t)} ADD CONSTRAINT ${ident(c.conname)} ${c.def};`);
emit('-- Índices no asociados a restricciones.');
for(const t of tables)for(const i of await rows(`SELECT pg_get_indexdef(i.indexrelid) def FROM pg_index i WHERE i.indrelid=${t.oid} AND NOT EXISTS(SELECT 1 FROM pg_constraint c WHERE c.conindid=i.indexrelid) ORDER BY i.indexrelid::regclass::text`))emit(i.def+';');
// Las vistas actuales dependen solo de tablas; el validador verifica restauración completa.
for(const v of views)emit(`CREATE VIEW ${name(v)} AS ${v.def}`);
emit('-- Catálogos/configuración inicial: sin usuarios, contactos, pagos ni evaluaciones.');
for(const table of ['public.ciclos','public.clases','public.especialidades','privado.competencia_config','privado.competencia_criterios','privado.migraciones']){
 const data=await rows(`SELECT row_to_json(t) value FROM ${table} t`);
 for(const {value} of data){const cols=Object.keys(value);const values=cols.map(k=>table==='public.ciclos'&&k==='anio'?"extract(year FROM now() AT TIME ZONE 'America/Mexico_City')::integer":literal(typeof value[k]==='object'&&value[k]!==null?JSON.stringify(value[k]):value[k]));emit(`INSERT INTO ${table} (${cols.map(ident).join(',')}) VALUES (${values.join(',')});`);}
}
emit('INSERT INTO privado.cuota_epoca DEFAULT VALUES;');
emit('-- Buckets privados; Auth/Storage son administrados por Supabase.');
for(const b of await rows('SELECT id,name,public,file_size_limit,allowed_mime_types FROM storage.buckets ORDER BY id'))emit(`INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types) VALUES(${literal(b.id)},${literal(b.name)},${b.public},${b.file_size_limit},ARRAY[${b.allowed_mime_types.map(literal).join(',')}]) ON CONFLICT(id) DO UPDATE SET public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;`);
emit('-- Triggers finales (después de semillas para no producir registros ficticios).');
for(const t of tables)for(const tr of await rows(`SELECT pg_get_triggerdef(oid,true) def FROM pg_trigger WHERE tgrelid=${t.oid} AND NOT tgisinternal ORDER BY tgname`))emit(tr.def+';');
emit('-- RLS y políticas, incluidas las políticas de archivos privados.');
for(const t of tables){if(t.relrowsecurity)emit(`ALTER TABLE ${name(t)} ENABLE ROW LEVEL SECURITY;`);if(t.relforcerowsecurity)emit(`ALTER TABLE ${name(t)} FORCE ROW LEVEL SECURITY;`);}
for(const p of await rows("SELECT * FROM pg_policies WHERE schemaname IN ('public','privado','storage') ORDER BY schemaname,tablename,policyname")){emit(`CREATE POLICY ${ident(p.policyname)} ON ${ident(p.schemaname)}.${ident(p.tablename)} AS ${p.permissive} FOR ${p.cmd} TO ${p.roles.map(ident).join(',')}${p.qual?' USING ('+p.qual+')':''}${p.with_check?' WITH CHECK ('+p.with_check+')':''};`);}
emit('-- ACL efectivas: elimina grants implícitos de instalación antes de reproducir permisos.');
const who=r=>r.grantee===0?'PUBLIC':ident(r.rolname);
async function grants(kind,target,query){emit(`REVOKE ALL ON ${kind} ${target} FROM PUBLIC,anon,authenticated;`);for(const a of await rows(query))emit(`GRANT ${a.privilege_type} ON ${kind} ${target} TO ${who(a)}${a.is_grantable?' WITH GRANT OPTION':''};`);}
for(const schema of ['public','privado'])await grants('SCHEMA',ident(schema),`SELECT a.*,r.rolname FROM pg_namespace n CROSS JOIN LATERAL aclexplode(coalesce(n.nspacl,acldefault('n',n.nspowner))) a LEFT JOIN pg_roles r ON r.oid=a.grantee WHERE n.nspname='${schema}' AND (a.grantee=0 OR r.rolname IN ('anon','authenticated')) ORDER BY a.grantee,a.privilege_type`);
for(const t of [...tables,...views])await grants('TABLE',name(t),`SELECT a.*,r.rolname FROM pg_class c CROSS JOIN LATERAL aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) a LEFT JOIN pg_roles r ON r.oid=a.grantee WHERE c.oid=${t.oid} AND (a.grantee=0 OR r.rolname IN ('anon','authenticated')) ORDER BY a.grantee,a.privilege_type`);
for(const f of functions)await grants('FUNCTION',name(f)+'('+f.args+')',`SELECT a.*,r.rolname FROM pg_proc p CROSS JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a LEFT JOIN pg_roles r ON r.oid=a.grantee WHERE p.oid=${f.oid} AND (a.grantee=0 OR r.rolname IN ('anon','authenticated')) ORDER BY a.grantee,a.privilege_type`);
for(const t of tables)for(const c of await rows(`SELECT attname,a.*,r.rolname FROM pg_attribute col CROSS JOIN LATERAL aclexplode(col.attacl) a LEFT JOIN pg_roles r ON r.oid=a.grantee WHERE col.attrelid=${t.oid} AND (a.grantee=0 OR r.rolname IN ('anon','authenticated')) ORDER BY attname,a.grantee,a.privilege_type`))emit(`GRANT ${c.privilege_type} (${ident(c.attname)}) ON ${name(t)} TO ${who(c)};`);
emit("NOTIFY pgrst, 'reload schema';\nCOMMIT;\n");
writeFileSync(new URL('../supabase/schema.sql',import.meta.url),out.join('\n\n'));
console.log(`SQL maestro: ${tables.length} tablas, ${views.length} vistas, ${functions.length} funciones.`);await db.close();
