// Service worker mínimo do SICAPDA.
//
// Existe só para o navegador reconhecer o site como aplicativo instalável (aviso "Instalar aplicativo"
// do Chrome/Edge no celular e no PC). Não guarda NADA em cache: o app sempre carrega a versão publicada
// mais recente e os dados vêm sempre do servidor. Por isso uma versão nova do app nunca "fica presa".
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (evento) => evento.waitUntil(self.clients.claim()));
self.addEventListener('fetch', () => {
  // Sem respondWith: o navegador faz a requisição normalmente.
});
