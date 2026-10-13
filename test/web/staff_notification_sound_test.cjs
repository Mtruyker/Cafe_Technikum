const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const code = readFileSync('web/staff_notification_sound.js', 'utf8');
async function run() {
  let tones = 0;
  let resumes = 0;
  class AudioContext {
    state = 'suspended';
    currentTime = 10;
    destination = {};
    async resume() { resumes++; this.state = 'running'; }
    createOscillator() { return { frequency: {}, connect() {}, disconnect() {}, start() { tones++; }, stop() {} }; }
    createGain() { return { gain: { setValueAtTime() {}, linearRampToValueAtTime() {}, exponentialRampToValueAtTime() {} }, connect() {}, disconnect() {} }; }
  }
  const window = { AudioContext };
  vm.runInNewContext(code, { window });
  assert.equal(await window.techCafeStaffSound(), true);
  assert.equal(await window.techCafeStaffSound(), true);
  assert.equal(resumes, 1, 'the resumed audio context is reused');
  assert.equal(tones, 4, 'two tones per notification');
  const unavailable = {};
  vm.runInNewContext(code, { window: unavailable });
  assert.equal(await unavailable.techCafeStaffSound(), false);
  class BlockedAudio extends AudioContext { async resume() { throw new Error('blocked'); } }
  const blocked = { AudioContext: BlockedAudio };
  vm.runInNewContext(code, { window: blocked });
  assert.equal(await blocked.techCafeStaffSound(), false, 'denied audio is reported to the UI');
  console.log('PASS: notification tone, context reuse, unsupported and blocked audio');
}
run().catch(error => { console.error(error); process.exitCode = 1; });
