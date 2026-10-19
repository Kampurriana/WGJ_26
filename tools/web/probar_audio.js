// Abre la build Web y mide si sale sonido: engancha un analizador a todo lo que llega a ctx.destination.
const { chromium } = require('playwright');
(async () => {
  const out = process.argv[2];
  const url = process.argv[3] || 'http://127.0.0.1:8765/index.html';
  const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, locale: 'es-ES' });
  await page.addInitScript(() => {
    window.__ctxs = [];
    window.__an = [];
    const Orig = window.AudioContext;
    window.AudioContext = function (...a) {
      const ctx = new Orig(...a);
      window.__ctxs.push(ctx);
      const an = ctx.createAnalyser(); an.fftSize = 2048; window.__an.push(an);
      return ctx;
    };
    window.AudioContext.prototype = Orig.prototype;
    const conn = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (dest, ...rest) {
      const r = conn.call(this, dest, ...rest);
      if (dest instanceof AudioDestinationNode) {
        const i = window.__ctxs.indexOf(dest.context);
        if (i >= 0) conn.call(this, window.__an[i]);
      }
      return r;
    };
    window.__rms = () => window.__an.map((an, i) => {
      const d = new Float32Array(an.fftSize); an.getFloatTimeDomainData(d);
      let s = 0; for (const v of d) s += v * v;
      return { state: window.__ctxs[i].state, rms: Math.sqrt(s / d.length) };
    });
  });
  const logs = [];
  page.on('console', m => logs.push(`[${m.type()}] ${m.text()}`));
  page.on('pageerror', e => logs.push(`[pageerror] ${e.message}`));
  await page.goto(url);
  const samples = [];
  for (let t = 0; t < 70; t++) {
    if (t === 12) await page.mouse.click(640, 360);     // (como un jugador: un clic, por si el navegador espera un gesto)
    await page.waitForTimeout(500);
    let peak = 0, st = '';
    for (let k = 0; k < 4; k++) {
      const r = await page.evaluate(() => window.__rms());
      for (const x of r) { peak = Math.max(peak, x.rms); st = x.state; }
      await page.waitForTimeout(100);
    }
    samples.push(`${(t * 0.9).toFixed(1)}s ${st} ${peak.toFixed(4)}`);
  }
  await page.screenshot({ path: out + '/audio_fin.png' });
  console.log(samples.join('\n'));
  console.log(logs.filter(l => !l.includes('[debug]')).slice(0, 40).join('\n'));
  await browser.close();
})();
