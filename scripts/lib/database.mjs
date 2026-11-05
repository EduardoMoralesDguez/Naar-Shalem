import {PGlite} from '@electric-sql/pglite';
import {readFileSync, readdirSync} from 'node:fs';

export const sql = path => readFileSync(new URL('../../database/' + path, import.meta.url), 'utf8');

// Contrato mínimo para pruebas locales: NO reemplaza servicios alojados de Supabase.
export async function database() {
  const db = new PGlite();
  await db.exec(`
    CREATE ROLE anon;
    CREATE ROLE authenticated;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, email text);
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS
      $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    CREATE SCHEMA storage;
    CREATE TABLE storage.buckets(
      id text PRIMARY KEY, name text, public bool,
      file_size_limit bigint, allowed_mime_types text[]
    );
    CREATE TABLE storage.objects(
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      bucket_id text REFERENCES storage.buckets, name text, UNIQUE(bucket_id,name)
    );
    ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
    GRANT USAGE ON SCHEMA storage TO anon, authenticated;
    GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO anon, authenticated;
  `);
  return db;
}

export async function historical(hasta = Infinity) {
  const db = await database();
  await db.exec(sql('schema.sql'));
  // 002 exige una directiva vinculada. Estos fixtures NO se exportan al maestro.
  await db.exec(`
    INSERT INTO usuarios(id_usuario,id_ciclo,nombres,apellido,rol)
    VALUES('d0000000-0000-4000-8000-000000000004',
      'c0000000-0000-4000-8000-000000000001','Fixture','Directiva','directiva');
    INSERT INTO auth.users(id) VALUES('f0000000-0000-4000-8000-000000000004');
  `);
  const migrations = readdirSync(new URL('../../database/migrations/', import.meta.url))
    .filter(file => file.endsWith('.sql') && parseInt(file, 10) <= hasta).sort();
  for (const file of migrations) {
    try {
      await db.exec(sql('migrations/' + file));
      if (file.startsWith('001_')) {
        await db.exec(`SELECT privado.vincular_cuenta(
          'd0000000-0000-4000-8000-000000000004',
          'f0000000-0000-4000-8000-000000000004'
        )`);
      }
    } catch (error) {
      await db.close();
      throw new Error(file + ': ' + error.message, {cause: error});
    }
  }
  return db;
}
