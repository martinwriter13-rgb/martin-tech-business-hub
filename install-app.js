(function(){
  if (window.__martinPwaInstallerLoaded) return;
  window.__martinPwaInstallerLoaded = true;
  var deferredPrompt = null;
  var standalone = window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true;
  if (standalone) return;
  var ua = navigator.userAgent || '';
  var isAndroid = /Android/i.test(ua);
  var isIOS = /iPhone|iPad|iPod/i.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isWindows = /Windows/i.test(ua);
  var deviceLabel = isAndroid ? 'Android phone' : isIOS ? 'iPhone or iPad' : isWindows ? 'Windows computer' : 'computer';
  var installLabel = isAndroid ? 'Install for Android' : isIOS ? 'Add to Home Screen' : isWindows ? 'Install for Windows' : 'Install app';
  var style = document.createElement('style');
  style.textContent = '#martin-install-card{position:fixed;z-index:99999;left:16px;right:16px;bottom:16px;max-width:480px;margin:auto;padding:15px 16px;border:1px solid rgba(125,165,255,.4);border-radius:17px;background:#101b31;color:#f5f7ff;box-shadow:0 14px 42px #0009;font:14px/1.45 system-ui,-apple-system,Segoe UI,sans-serif;display:none}#martin-install-card .mi-row{display:flex;align-items:center;gap:12px}#martin-install-card .mi-icon{width:42px;height:42px;border-radius:12px;background:#243c6d;display:grid;place-items:center;font-size:22px;flex:none}#martin-install-card .mi-copy{flex:1;min-width:0}#martin-install-card strong{display:block;font-size:15px}#martin-install-card small{display:block;color:#bac9e6;margin-top:2px}#martin-install-card button{border:0;border-radius:10px;padding:10px 13px;background:linear-gradient(110deg,#3478ff,#8158e8);color:#fff;font-weight:800;cursor:pointer;white-space:nowrap}#martin-install-card .mi-close{background:transparent;color:#b9c8e4;padding:5px 8px;font-size:19px}#martin-install-card .mi-help{display:none;color:#cbd7ee;margin:10px 0 0;font-size:12px}#martin-install-card .mi-help.show{display:block}@media(min-width:800px){#martin-install-card{left:auto;right:22px;bottom:22px}}';
  document.head.appendChild(style);
  var card = document.createElement('aside');
  card.id = 'martin-install-card';
  card.setAttribute('role','region');
  card.setAttribute('aria-label','Install app');
  card.innerHTML = '<div class="mi-row"><div class="mi-icon" aria-hidden="true">↗</div><div class="mi-copy"><strong>Get the app on your '+deviceLabel+'</strong><small>Install for quicker access from your home screen or desktop.</small></div><button type="button" id="martin-install-action">'+installLabel+'</button><button type="button" class="mi-close" aria-label="Dismiss">×</button></div><p class="mi-help" id="martin-install-help"></p>';
  document.body.appendChild(card);
  var help = card.querySelector('#martin-install-help');
  var action = card.querySelector('#martin-install-action');
  var close = card.querySelector('.mi-close');
  var dismissed = false;
  function show(){ if(!dismissed) card.style.display='block'; }
  function instructions(){
    if (isIOS) return 'In Safari, tap Share, then choose “Add to Home Screen”.';
    if (isAndroid) return 'Open your browser menu (⋮) and choose “Install app” or “Add to Home screen”.';
    return 'In Chrome or Edge, open the browser menu and choose “Install Martin app” or “Install this site as an app”.';
  }
  window.addEventListener('beforeinstallprompt', function(e){
    e.preventDefault(); deferredPrompt = e; show();
  });
  window.addEventListener('appinstalled', function(){
    card.style.display='none'; deferredPrompt = null;
  });
  action.addEventListener('click', async function(){
    if (deferredPrompt) {
      deferredPrompt.prompt();
      try { await deferredPrompt.userChoice; } catch(e) {}
      deferredPrompt = null;
      card.style.display='none';
    } else {
      help.textContent = instructions();
      help.classList.add('show');
    }
  });
  close.addEventListener('click', function(){ dismissed=true; card.style.display='none'; });
  if (isIOS || isAndroid || isWindows || /Macintosh|Linux/i.test(ua)) {
    window.setTimeout(show, 1400);
  }
  if ('serviceWorker' in navigator && location.protocol === 'https:') {
    window.addEventListener('load', function(){ navigator.serviceWorker.register('/service-worker.js').catch(function(){}); });
  }
})();