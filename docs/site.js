/* Glint landing — scroll-driven live notch + interactions (vanilla, no deps) */
(function () {
  'use strict';
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];

  const island = $('#island');
  const notchbar = $('#notchbar');

  /* ---- build the compact equalizer: tall bars fading into dots (like the real notch) ---- */
  const eq = $('#eqNotch');
  const BARS = 13, ANIMATED = 8;   // first 8 dance, last 5 sit as dots
  const bars = [];
  if (eq) for (let i = 0; i < BARS; i++) {
    const s = document.createElement('span');
    if (i >= ANIMATED) s.className = 'dot';
    eq.appendChild(s); bars.push(s);
  }

  /* ---- decorative color swatches for the "adaptive" block ---- */
  const swWrap = $('#swatches');
  if (swWrap) {
    ['#37d67a', '#ff8a4c', '#5fd6ff', '#ff5f6d', '#c9b6ff', '#ffd166'].forEach((c, i) => {
      const d = document.createElement('div');
      d.className = 'swatch';
      d.style.setProperty('--sw', c);
      d.style.background = `linear-gradient(150deg, ${c}22, #0c0e15)`;
      swWrap.appendChild(d);
    });
  }

  /* ---- scroll-driven notch state via IntersectionObserver ---- */
  const feats = $$('.feat[data-state]');
  let currentState = 'compact';
  const setState = (s) => {
    if (s === currentState) return;
    currentState = s;
    island.dataset.state = s;
  };

  // pick the feature whose center is closest to viewport center
  function pickState() {
    const mid = innerHeight / 2;
    let best = null, bestDist = Infinity;
    for (const f of feats) {
      const r = f.getBoundingClientRect();
      if (r.bottom < 0 || r.top > innerHeight) continue;
      const d = Math.abs((r.top + r.bottom) / 2 - mid);
      if (d < bestDist) { bestDist = d; best = f; }
    }
    // Fall back to the calm "now playing" state whenever no feature beat
    // owns the viewport (hero above, or the lower sections below).
    setState(best ? best.dataset.state : 'compact');
  }

  // is the notch "stuck" (features section in view) → show faux menu bar
  const featSection = $('#features');
  function updateStuck() {
    if (!featSection) return;
    const r = featSection.getBoundingClientRect();
    const stuck = r.top < innerHeight * 0.4 && r.bottom > innerHeight * 0.3;
    notchbar.classList.toggle('stuck', stuck);
    // idle when hero is fully in view and features far below
    if (r.top > innerHeight * 0.85) setState('compact');
  }

  let ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      pickState();
      updateStuck();
      parallax();
      ticking = false;
    });
  }
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll, { passive: true });

  /* ---- reveal-on-scroll ---- */
  const revealTargets = $$('.section-head, .feat, .how-card, .adaptive, .priv-inner, .steps li, .terminal, .finalcta, .stage-caption');
  revealTargets.forEach(el => el.classList.add('reveal'));
  if ('IntersectionObserver' in window && !reduce) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { threshold: 0.14, rootMargin: '0px 0px -8% 0px' });
    revealTargets.forEach(el => io.observe(el));
  } else {
    revealTargets.forEach(el => el.classList.add('in'));
  }

  /* ---- parallax on screenshots + hero lid ---- */
  const shots = $$('.shot');
  function parallax() {
    if (reduce) return;
    const vh = innerHeight;
    for (const s of shots) {
      const r = s.getBoundingClientRect();
      if (r.bottom < 0 || r.top > vh) continue;
      const p = (r.top + r.height / 2 - vh / 2) / vh; // -0.5..0.5
      s.style.setProperty('transform', `translateY(${(-p * 22).toFixed(1)}px)`);
    }
  }

  /* ---- hero lid: subtle 3D tilt toward cursor ---- */
  const lid = $('#lidframe');
  const stage = $('#heroStage');
  if (lid && stage && !reduce && matchMedia('(pointer:fine)').matches) {
    stage.addEventListener('pointermove', (e) => {
      const r = stage.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width - 0.5;
      const y = (e.clientY - r.top) / r.height - 0.5;
      lid.style.transform = `rotateY(${(-11 + x * 10).toFixed(2)}deg) rotateX(${(5 - y * 8).toFixed(2)}deg)`;
    });
    stage.addEventListener('pointerleave', () => {
      lid.style.transform = 'rotateY(-11deg) rotateX(5deg)';
    });
  }

  /* ---- magnetic buttons ---- */
  if (!reduce && matchMedia('(pointer:fine)').matches) {
    $$('.btn').forEach(btn => {
      btn.addEventListener('pointermove', (e) => {
        const r = btn.getBoundingClientRect();
        const x = e.clientX - r.left - r.width / 2;
        const y = e.clientY - r.top - r.height / 2;
        btn.style.transform = `translate(${x * 0.14}px, ${(y * 0.22 - 3).toFixed(1)}px)`;
      });
      btn.addEventListener('pointerleave', () => { btn.style.transform = ''; });
    });
  }

  /* ---- hero video: sound toggle ---- */
  const video = $('#heroVideo');
  const soundBtn = $('#soundBtn');
  if (video && soundBtn) {
    soundBtn.addEventListener('click', () => {
      video.muted = !video.muted;
      soundBtn.classList.toggle('on', !video.muted);
      if (!video.muted) { video.currentTime = 0; video.play().catch(() => {}); }
    });
    // ensure autoplay kicks off on mobile/Safari
    const kick = () => { video.play().catch(() => {}); removeEventListener('touchstart', kick); removeEventListener('click', kick); };
    addEventListener('touchstart', kick, { once: true, passive: true });
  }

  /* ---- equalizer animation (only while notch shows music-ish states) ---- */
  const musicStates = new Set(['compact', 'expanded']);
  let t0 = performance.now();
  function tickEq(now) {
    const t = (now - t0) / 1000;
    const active = musicStates.has(currentState) && !document.hidden;
    for (let i = 0; i < bars.length; i++) {
      if (bars[i].classList.contains('dot')) continue; // dots keep their CSS size
      let h = 4;
      if (active) {
        const p = i * 1.9;
        const w = Math.sin(t * 6.1 + p) * 0.5 + Math.sin(t * 9.7 + p * 1.3) * 0.3 + Math.sin(t * 2.7 + p * 0.7) * 0.2;
        h = 4 + (w + 1) / 2 * 12;
      }
      bars[i].style.height = h.toFixed(1) + 'px';
    }
    requestAnimationFrame(tickEq);
  }
  if (!reduce) requestAnimationFrame(tickEq);
  else bars.forEach((b, i) => b.style.height = (4 + (i % 4) * 3) + 'px');

  /* init */
  island.dataset.state = 'compact';
  onScroll();
})();
