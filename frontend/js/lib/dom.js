// Usa textContent: los nombres y mensajes nunca se interpretan como HTML.
export function crearNodo(tag, texto = '') {
  const elemento = document.createElement(tag);
  elemento.textContent = texto ?? '';
  return elemento;
}
