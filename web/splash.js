(() => {
  const splash = document.getElementById('cafe-splash');
  if (!splash) return;
  const retry = document.getElementById('splash-retry');
  retry.addEventListener('click', () => window.location.reload());
  // A slow or failed startup must offer a way to retry instead of spinning forever.
  const timeout = window.setTimeout(() => {
    document.getElementById('splash-message').textContent =
      'Загрузка затянулась. Проверьте подключение к интернету.';
    retry.hidden = false;
  }, 20000);
  window.addEventListener('flutter-first-frame', () => {
    window.clearTimeout(timeout);
    splash.classList.add('splash-leaving');
    window.setTimeout(() => splash.remove(), 250);
  }, { once: true });
})();
