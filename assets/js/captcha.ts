import { assertNotNull } from './utils/assert';
import { delegate, leftClick } from './utils/events';
import { clearEl, makeEl } from './utils/dom';

function insertCaptcha(_event: Event, target: HTMLInputElement) {
  const parentElement = assertNotNull(target.parentElement);

  const script = makeEl('script', { src: 'https://challenges.cloudflare.com/turnstile/v0/api.js?compat=hcaptcha', async: true, defer: true });
  const frame = makeEl('div', { className: 'h-captcha' });

  frame.dataset.sitekey = target.dataset.sitekey;

  clearEl(parentElement);

  parentElement.insertAdjacentElement('beforeend', frame);
  parentElement.insertAdjacentElement('beforeend', script);
}

export function bindCaptchaLinks() {
  delegate(document, 'click', { '.js-captcha': leftClick(insertCaptcha) });
}
