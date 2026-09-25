/* Shows GymMane notifications outside the page. */
'use strict';

const timers = new Map();

self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

function readMessage(data) {
  if (typeof data === 'string') {
    try {
      return JSON.parse(data);
    } catch (_) {
      return null;
    }
  }
  return data;
}

function show(data) {
  const vibrate = Array.isArray(data.vibrate) ? data.vibrate : undefined;
  return self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
    const visible = list.some((client) => client.visibilityState === 'visible');
    if (data.onlyWhenHidden && visible) return;
    return self.registration.showNotification(data.title || 'GymMane', {
      body: data.body || '',
      tag: data.tag ? String(data.tag) : String(data.id),
      renotify: false,
      silent: !!data.silent,
      vibrate: vibrate,
      icon: 'icons/Icon-192.png',
    });
  });
}

self.addEventListener('message', (event) => {
  const data = readMessage(event.data);
  if (!data || !data.type) return;
  const id = String(data.id);
  if (data.type === 'cancel') {
    const prev = timers.get(id);
    if (prev) clearTimeout(prev);
    timers.delete(id);
    event.waitUntil(
      self.registration.getNotifications({ tag: id }).then((list) => {
        list.forEach((note) => note.close());
      }),
    );
    return;
  }
  if (data.type === 'show') {
    event.waitUntil(show(data));
    return;
  }
  if (data.type !== 'schedule') return;
  const prev = timers.get(id);
  if (prev) clearTimeout(prev);
  const delay = Math.max(0, Number(data.at) - Date.now());
  const handle = setTimeout(() => {
    timers.delete(id);
    show(data);
  }, delay);
  timers.set(id, handle);
  if (delay <= 10 * 60 * 1000) {
    event.waitUntil(new Promise((resolve) => setTimeout(resolve, delay + 500)));
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      if (list.length > 0) return list[0].focus();
      return self.clients.openWindow('/');
    }),
  );
});
