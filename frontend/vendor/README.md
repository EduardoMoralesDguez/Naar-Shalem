# Supabase para uso sin conexión

`supabase-2.49.8.js` es la distribución UMD sin modificar de `@supabase/supabase-js@2.49.8`.

Origen: https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.8/dist/umd/supabase.js
Licencia MIT en `SUPABASE-LICENSE`.

Se sirve desde el mismo origen para que el service worker pueda preparar la aplicación sin depender del CDN. No contiene configuración ni credenciales del proyecto. Para actualizar: descargar una versión explícita, revisar su compatibilidad, cambiar la referencia en index.html y ejecutar `npm run build`.
