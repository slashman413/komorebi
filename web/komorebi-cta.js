/*
 * Komorebi — Ko-fi CTA + cookieless counter.
 *
 * Loaded on the landing page (/) and, via the Web export preset's
 * html/head_include, on the Godot demo shell (/play/). It:
 *   1. counts one pageview per load   -> GET  api.slashmantools.us/hit (1x1 pixel)
 *   2. counts Ko-fi CTA clicks        -> sendBeacon to the same endpoint
 *   3. on /play/, injects a floating "Support Komorebi" button over the game.
 * No cookies, no storage, no IP kept — the Worker stores daily totals only.
 * Totals: https://api.slashmantools.us/stats?s=komorebi
 */
(function () {
  var HIT = 'https://api.slashmantools.us/hit?s=komorebi&e=';
  var KOFI = 'https://ko-fi.com/ytstories0413?utm_source=komorebi-play';
  var page = /\/play(\/|\/index\.html)?$/.test(location.pathname) ? 'play' : 'landing';

  function hit(event, beacon) {
    var url = HIT + page + '_' + event + '&t=' + Date.now();
    if (beacon && navigator.sendBeacon && navigator.sendBeacon(url)) return;
    new Image().src = url;
  }

  function track(a) {
    a.addEventListener('click', function () { hit('cta_click', true); });
  }

  function injectPlayButton() {
    var a = document.createElement('a');
    a.href = KOFI;
    a.target = '_blank';
    a.rel = 'noopener';
    a.setAttribute('data-kofi', '');
    a.textContent = '☕ Support Komorebi — pay what you want';
    a.style.cssText = [
      'position:fixed', 'right:16px', 'bottom:16px', 'z-index:2147483647',
      'padding:10px 16px', 'border-radius:999px', 'font:600 14px/1.2 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif',
      'color:#0d1b2a', 'background:#7fd1b9', 'text-decoration:none',
      'box-shadow:0 4px 18px rgba(0,0,0,.35)', 'opacity:.92'
    ].join(';');
    document.body.appendChild(a);
  }

  function init() {
    if (page === 'play') injectPlayButton();
    var links = document.querySelectorAll('a[data-kofi]');
    for (var i = 0; i < links.length; i++) track(links[i]);
    hit('view', false);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
