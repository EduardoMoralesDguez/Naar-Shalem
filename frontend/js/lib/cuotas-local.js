// Datos separados por cuenta y proyecto. Ningún expediente médico se guarda aquí.
import { SUPABASE_URL } from '../config.js';
const name = 'naar-cuotas-v1';
const key = id => `${SUPABASE_URL}/${id}`;
let database;
async function db() {
  if (!database) database = new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore('cuentas');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return database;
}
export async function localCuotas(id, modificar) {
  const database = await db();
  return new Promise((resolve, reject) => {
    const tx = database.transaction('cuentas', modificar ? 'readwrite' : 'readonly');
    const store = tx.objectStore('cuentas');
    const req = store.get(key(id)); let value;
    req.onsuccess = () => {
      value = req.result || { cola: [], panel: null, perfil: null };
      if (modificar) {
        try { modificar(value); store.put(value, key(id)); }
        catch (error) { tx.abort(); reject(error); }
      }
    };
    tx.oncomplete = () => resolve(value);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error || new Error('No se guardó en el dispositivo.'));
  });
}
const accesoKey = `${SUPABASE_URL}/cuotas-acceso`;
export function recordarCuenta(id) { localStorage.setItem(accesoKey, id); }
export function olvidarCuenta() { localStorage.removeItem(accesoKey); }
export function cuentaRecordada() { return localStorage.getItem(accesoKey); }
export async function guardarOperacion(id, operacion) {
  return localCuotas(id, d => {
    const anteriores = d.cola.filter(o => o.datos.id_usuario && o.datos.id_usuario === operacion.datos.id_usuario);
    if (anteriores.length) {
      const pagoCompleto = o => o.accion === 'pago' && o.datos.importe === 1000 && o.datos.periodos?.length === 1;
      const independientes = pagoCompleto(operacion) && anteriores.every(o => pagoCompleto(o) && !o.error && !o.revisar
        && o.datos.id_ciclo === operacion.datos.id_ciclo && o.datos.epoca === operacion.datos.epoca
        && o.datos.periodos[0] !== operacion.datos.periodos[0]);
      if (!independientes) throw new Error('Hay un movimiento pendiente para este integrante. Sincronízalo o revísalo antes de registrar un abono o repetir el cobro.');
      // La RPC incrementa la versión por cada pago confirmado, en este mismo orden.
      operacion.datos.version = anteriores.at(-1).datos.version + 1;
    }
    d.cola.push(operacion);
  });
}
