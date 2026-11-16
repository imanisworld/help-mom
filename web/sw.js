/* App-shell offline cache. User content stays only in browser storage. */
const VERSION='creative-moments-shell-v4-notebook-20261115';
const CORE=['/','/index.html','/style.css','/app.mjs','/data.mjs','/manifest.webmanifest','/assets/icon-192.png','/assets/icon-512.png'];
const ART=Array.from({length:12},(_,i)=>`/assets/scene-${String(i+1).padStart(2,'0')}.webp`);
self.addEventListener('install',event=>event.waitUntil((async()=>{
  const cache=await caches.open(VERSION);
  await cache.addAll(CORE);
  // Artwork may be temporarily unavailable. Cache images independently.
  await Promise.allSettled(ART.map(async path=>{const response=await fetch(path,{cache:'reload'});if(response.ok)await cache.put(path,response)}));
  await self.skipWaiting();
})()));
self.addEventListener('activate',event=>event.waitUntil((async()=>{
  await Promise.all((await caches.keys()).filter(key=>key.startsWith('creative-moments-shell-')&&key!==VERSION).map(key=>caches.delete(key)));
  await self.clients.claim();
})()));
self.addEventListener('fetch',event=>{
  const req=event.request,url=new URL(req.url);
  if(req.method!=='GET'||url.origin!==self.location.origin)return;
  event.respondWith((async()=>{
    const cache=await caches.open(VERSION);
    // Offline-first for static versioned assets; navigation refreshes when online.
    if(ART.includes(url.pathname)){const cached=await cache.match(req);if(cached)return cached}
    try{const res=await fetch(req);if(res.ok&&(CORE.includes(url.pathname)||ART.includes(url.pathname)))cache.put(req,res.clone()).catch(()=>{});return res}
    catch{return (await cache.match(req))||(await cache.match('/index.html'))||new Response('Offline. Reopen Creative Moments after connecting.',{status:503})}
  })());
});
