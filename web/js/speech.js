/* Frequency - text to speech.
   Web Speech API only, no recording or recognition. Voice lists load
   asynchronously and vary by OS and browser, so nothing here may throw when
   speech is missing: the app must stay fully usable without audio. */
(function (FQ) {
  'use strict';

  var U = FQ.util;

  var supported = typeof window.speechSynthesis !== 'undefined' &&
                  typeof window.SpeechSynthesisUtterance !== 'undefined';

  var state = {
    voices: [],        // English voices, best first
    chosen: null,
    loaded: false,
    wantedName: null,
    rate: 0.95
  };

  var listeners = [];

  function isEnglish(v) {
    return !!v && typeof v.lang === 'string' && /^en(-|_|$)/i.test(v.lang);
  }

  // Ranks voices by the markers that correlate with natural-sounding output.
  // Detection of "is this English" is deliberately separate from ranking, so a
  // low-quality English voice still qualifies when nothing better exists.
  function score(v) {
    var n = (v.name || '') + ' ' + (v.voiceURI || '');
    var s = 0;
    if (/neural|natural/i.test(n)) s += 45;
    if (/google/i.test(n)) s += 35;
    if (/siri|premium|enhanced/i.test(n)) s += 30;
    if (/online/i.test(n)) s += 20;
    if (v.localService) s += 15;
    if (/desktop/i.test(n)) s -= 12;         // legacy SAPI voices
    if (/espeak|festival/i.test(n)) s -= 25;
    if (/^en-US/i.test(v.lang)) s += 6;
    else if (/^en-GB/i.test(v.lang)) s += 4;
    return s;
  }

  function loadVoices() {
    if (!supported) return;
    var all = [];
    try { all = window.speechSynthesis.getVoices() || []; } catch (e) { all = []; }
    if (!all.length) return;

    state.voices = all.filter(isEnglish).sort(function (a, b) { return score(b) - score(a); });
    state.loaded = true;

    if (state.wantedName) {
      var match = state.voices.filter(function (v) { return v.name === state.wantedName; })[0];
      if (match) state.chosen = match;
    }
    if (!state.chosen || state.voices.indexOf(state.chosen) === -1) {
      state.chosen = state.voices[0] || null;
    }
    listeners.forEach(function (fn) { try { fn(); } catch (e) {} });
  }

  if (supported) {
    loadVoices();
    // Chromium populates the list asynchronously; Safari fires this once.
    try { window.speechSynthesis.onvoiceschanged = loadVoices; } catch (e) {}
    // Some builds never fire the event when the list is already warm.
    setTimeout(loadVoices, 250);
    setTimeout(loadVoices, 1200);
  }

  // Chromium swallows the opening syllables when speak() is issued in the same
  // tick as cancel(), so the utterance is queued after a short gap instead.
  var LEAD_MS = 180;
  var pendingTimer = null;
  var warmed = false;

  // The very first utterance of a page tends to be clipped regardless. Priming
  // the engine with a silent phrase absorbs that.
  function warmUp() {
    if (!supported || warmed) return;
    warmed = true;
    try {
      var u = new window.SpeechSynthesisUtterance(' ');
      u.volume = 0;
      u.rate = 1;
      window.speechSynthesis.speak(u);
    } catch (e) { /* priming is best effort */ }
  }

  function speak(text, opts) {
    opts = opts || {};
    if (!supported || !U.clean(text)) return false;
    var voice = state.chosen;
    // Refuse to fall back to a Japanese system voice reading English, which is
    // what produces katakana-sounding output.
    if (!voice && !opts.allowAnyVoice) return false;

    try {
      clearTimeout(pendingTimer);
      window.speechSynthesis.cancel();

      var lead = opts.delay != null ? opts.delay : LEAD_MS;
      pendingTimer = setTimeout(function () {
        try {
          // A queue left paused by a previous cancel stays silent otherwise.
          if (window.speechSynthesis.paused) window.speechSynthesis.resume();

          var u = new window.SpeechSynthesisUtterance(text);
          if (voice) { u.voice = voice; u.lang = voice.lang; }
          else u.lang = 'en-US';
          u.rate = U.clamp(opts.rate || state.rate, 0.5, 1.5);
          u.pitch = 1;
          window.speechSynthesis.speak(u);
        } catch (e) {
          console.warn('[Frequency] speech failed:', e && e.message);
        }
      }, lead);
      return true;
    } catch (e) {
      console.warn('[Frequency] speech failed:', e && e.message);
      return false;
    }
  }

  FQ.speech = {
    get supported() { return supported; },
    get available() { return supported && state.voices.length > 0; },
    get voices() { return state.voices.slice(); },
    get chosen() { return state.chosen; },
    get loaded() { return state.loaded; },

    onChange: function (fn) { listeners.push(fn); },
    refresh: loadVoices,

    setRate: function (r) { state.rate = U.clamp(r, 0.5, 1.5); },
    setVoiceName: function (name) {
      state.wantedName = name;
      var match = state.voices.filter(function (v) { return v.name === name; })[0];
      if (match) state.chosen = match;
    },
    speak: speak,
    warmUp: warmUp,
    stop: function () {
      clearTimeout(pendingTimer);
      if (supported) { try { window.speechSynthesis.cancel(); } catch (e) {} }
    }
  };

})(window.FQ = window.FQ || {});
