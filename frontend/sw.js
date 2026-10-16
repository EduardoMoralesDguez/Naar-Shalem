// Generado por scripts/build-sw.mjs. Solo archivos estáticos; nunca respuestas de Supabase.
const CACHE='naar-static-a643d9d9a6c0922a';
const ASSETS=["css/asistencias.css","css/auth.css","css/calendario.css","css/competencia.css","css/cuotas.css","css/directorio.css","css/integrantes_admin.css","css/organizacion.css","css/perfiles.css","css/portal.css","css/style.css","js/app.js","js/config.js","js/lib/colores.js","js/lib/consultas.js","js/lib/cuotas-local.js","js/lib/supabase.js","js/modules/asistencias.js","js/modules/calendario.js","js/modules/competencia.js","js/modules/cuotas.js","js/modules/especialidades.js","js/modules/integrantes-admin.js","js/modules/organizacion.js","js/modules/progreso.js","js/modules/usuarios.js","js/services/asistencias-offline.js","js/services/asistencias.js","js/services/auth.js","js/services/calendario.js","js/services/catalogo.js","js/services/competencia.js","js/services/cuotas.js","js/services/fotos.js","js/services/integrantes-admin.js","js/services/organizacion.js","vendor/supabase-2.49.8.js","index.html","img/LogoNS.png","manifest.webmanifest"];
const urls=ASSETS.map(p=>new URL(p,self.registration.scope).href);
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(urls))));
self.addEventListener('activate',event=>event.waitUntil((async()=>{for(const key of await caches.keys())if(key.startsWith('naar-static-')&&key!==CACHE)await caches.delete(key);await self.clients.claim();})()));
self.addEventListener('fetch',event=>{
 if(event.request.method!=='GET')return;
 const url=new URL(event.request.url);
 if(url.origin!==self.location.origin)return;
 if(event.request.mode==='navigate'&&url.pathname.startsWith(new URL(self.registration.scope).pathname)){
  event.respondWith(caches.open(CACHE).then(async c=>(await c.match(new URL('index.html',self.registration.scope).href))||fetch(event.request)));return;
 }
 if(!urls.includes(url.href))return;
 event.respondWith(caches.open(CACHE).then(async cache=>(await cache.match(event.request))||fetch(event.request)));
});
