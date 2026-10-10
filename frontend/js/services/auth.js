// frontend/js/services/auth.js
import { obtenerSupabase } from '../lib/supabase.js';

export async function iniciarSesion(email, password) {
  const { error } = await obtenerSupabase().auth.signInWithPassword({
    email,
    password,
  });

  if (error) throw error;
}

export async function cerrarSesion() {
  const { error } = await obtenerSupabase().auth.signOut({
    scope: 'local',
  });

  if (error) throw error;
}

export async function obtenerMiPerfil() {
  const { data, error } = await obtenerSupabase().rpc('mi_perfil');

  if (error) throw error;

  if (!Array.isArray(data) || data.length !== 1) {
    const errorAcceso = new Error(
      'La cuenta no tiene un expediente activo vinculado. Contacta a la directiva.'
    );

    errorAcceso.code = 'SIN_EXPEDIENTE';
    throw errorAcceso;
  }

  return data[0];
}