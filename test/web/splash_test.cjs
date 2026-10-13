const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('web/splash.js', 'utf8');

function boot() {
  const timers = new Map();
  const listeners = {};
  let nextId = 0;
  const splash = {
    removed: false,
    leaving: false,
    remove() { this.removed = true; },
    classList: { add(name) { splash.leaving = name === 'splash-leaving'; } },
  };
  const retry = { hidden: true, addEventListener(name, fn) { this[name] = fn; } };
  const message = { textContent: '' };
  let reloaded = false;
  vm.runInNewContext(source, {
    document: { getElementById: id => ({ 'cafe-splash': splash, 'splash-retry': retry, 'splash-message': message })[id] },
    window: {
      location: { reload() { reloaded = true; } },
      setTimeout(fn, ms) { timers.set(++nextId, { fn, ms }); return nextId; },
      clearTimeout(id) { timers.delete(id); },
      addEventListener(name, fn) { listeners[name] = fn; },
    },
  });
  return { splash, retry, message, timers, listeners, reloaded: () => reloaded };
}

const normal = boot();
normal.listeners['flutter-first-frame']();
assert.equal(normal.splash.leaving, true);
assert.equal([...normal.timers.values()].some(t => t.ms === 20000), false);
[...normal.timers.values()].find(t => t.ms === 250).fn();
assert.equal(normal.splash.removed, true);

const slow = boot();
[...slow.timers.values()].find(t => t.ms === 20000).fn();
assert.equal(slow.retry.hidden, false);
assert.match(slow.message.textContent, /Проверьте подключение/);
slow.retry.click();
assert.equal(slow.reloaded(), true);
slow.listeners['flutter-first-frame']();
assert.equal(slow.splash.leaving, true);
console.log('PASS: splash dismissal, slow startup, retry and late recovery');
