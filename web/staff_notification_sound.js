// A user click on the sound button unlocks audio for this page session.
(() => {
  let context;
  window.techCafeStaffSound = async () => {
    try {
      const Audio = window.AudioContext || window.webkitAudioContext;
      if (!Audio) return false;
      context ??= new Audio();
      if (context.state !== 'running') await context.resume();
      if (context.state !== 'running') return false;
      const start = context.currentTime;
      for (const [offset, frequency] of [[0, 660], [0.22, 880]]) {
        const oscillator = context.createOscillator();
        const volume = context.createGain();
        oscillator.frequency.value = frequency;
        volume.gain.setValueAtTime(0, start + offset);
        volume.gain.linearRampToValueAtTime(0.16, start + offset + 0.02);
        volume.gain.exponentialRampToValueAtTime(0.001, start + offset + 0.2);
        oscillator.connect(volume);
        volume.connect(context.destination);
        oscillator.start(start + offset);
        oscillator.stop(start + offset + 0.21);
        oscillator.onended = () => { oscillator.disconnect(); volume.disconnect(); };
      }
      return true;
    } catch (_) {
      return false;
    }
  };
})();
