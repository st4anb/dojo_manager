// ═══════════════════════════════════════════════════════════════
// Service Worker — Dojo Manager PWA
// Responsável por: Cache offline + FCM Push Notifications
// ═══════════════════════════════════════════════════════════════

const CACHE_NAME = 'dojo-manager-cache-v2';
const OFFLINE_URL = '/offline.html';

// Recursos estáticos para precache (shell da aplicação)
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png',
  '/apple-touch-icon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
  OFFLINE_URL,
];

// ───────────────────────────────────────────────────────
// INSTALL: Precache dos recursos essenciais
// ───────────────────────────────────────────────────────
self.addEventListener('install', (event) => {
  console.log('[SW] Instalando Service Worker...');
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[SW] Precacheando recursos estáticos');
      return cache.addAll(PRECACHE_URLS);
    })
  );
  // Força ativação imediata do SW novo sem esperar abas fecharem
  self.skipWaiting();
});

// ───────────────────────────────────────────────────────
// ACTIVATE: Limpa caches antigos
// ───────────────────────────────────────────────────────
self.addEventListener('activate', (event) => {
  console.log('[SW] Ativando Service Worker...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => {
            console.log('[SW] Removendo cache antigo:', name);
            return caches.delete(name);
          })
      );
    })
  );
  // Garante que o SW controle todas as abas imediatamente
  self.clients.claim();
});

// ───────────────────────────────────────────────────────
// FETCH: Estratégia Network-First com Fallback Offline
// ───────────────────────────────────────────────────────
self.addEventListener('fetch', (event) => {
  // Ignora requisições não-GET (POST, PUT, etc.)
  if (event.request.method !== 'GET') return;

  // Ignora requisições para APIs/backends e extensões do Chrome
  const url = new URL(event.request.url);
  if (
    url.origin !== location.origin ||
    url.pathname.startsWith('/api/') ||
    url.pathname.startsWith('chrome-extension')
  ) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Se a resposta da rede for válida, armazena no cache
        if (response && response.status === 200 && response.type === 'basic') {
          const responseToCache = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseToCache);
          });
        }
        return response;
      })
      .catch(() => {
        // Se estiver offline, tenta servir do cache
        return caches.match(event.request).then((cachedResponse) => {
          if (cachedResponse) {
            return cachedResponse;
          }
          // Se a navegação falhou e não há cache, exibe a página offline
          if (event.request.mode === 'navigate') {
            return caches.match(OFFLINE_URL);
          }
        });
      })
  );
});

// ═══════════════════════════════════════════════════════════════
// FIREBASE CLOUD MESSAGING — Push Notifications
// ═══════════════════════════════════════════════════════════════

importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.0.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBPZmvW9K9EgBRwBTebQx9OM5X4u3b2Nf0',
  authDomain: 'dojo-manager-2bf1a.firebaseapp.com',
  projectId: 'dojo-manager-2bf1a',
  storageBucket: 'dojo-manager-2bf1a.firebasestorage.app',
  messagingSenderId: '1069283303095',
  appId: '1:1069283303095:web:147852d98c2bd3cefab732',
});

const messaging = firebase.messaging();

// Exibe a notificação quando o app está em background ou fechado
messaging.onBackgroundMessage(function (payload) {
  console.log('[SW] Mensagem em background:', payload);

  const notificationTitle = payload.notification?.title || 'Dojo Manager';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
    vibrate: [200, 100, 200],
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
