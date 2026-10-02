'use strict';
const comparison = document.querySelector('[data-player-comparison]');
if (comparison) {
  const switcher = comparison.querySelector('.state-switch');
  const image = comparison.querySelector('img');
  const caption = comparison.querySelector('figcaption');
  switcher.hidden = false;
  switcher.addEventListener('click', event => {
    const button = event.target.closest('button[data-state]');
    if (!button) return;
    const controls = button.dataset.state === 'controls';
    image.src = `assets/player-${controls ? 'controls' : 'clean'}-1366.webp`;
    image.alt = `The same Sintel frame in Vela, with playback controls ${controls ? 'visible' : 'hidden'}.`;
    caption.textContent = controls ? 'Actual Vela window. Timeline, volume and track menus within reach.' : 'Actual Vela window. Controls hidden; optional watermark switched off.';
    switcher.querySelectorAll('button').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  });
}
