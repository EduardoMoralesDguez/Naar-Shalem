// Rutas locales del sitio; no acepta HTML, traversal, tokens ni páginas github.com/blob.
export function rutaFoto(valor, carpeta = 'perfiles') {
  const texto = valor.trim();
  if (!texto) return null;
  const ruta = texto.includes('/') ? texto : `img/${carpeta}/${texto}`;
  if (!new RegExp(`^img/${carpeta}/[A-Za-z0-9_-]+\\.(webp|png|jpg|jpeg)$`).test(ruta)) {
    throw new Error(`Usa img/${carpeta}/archivo.webp, png o jpg; sin espacios ni acentos.`);
  }
  return ruta;
}
