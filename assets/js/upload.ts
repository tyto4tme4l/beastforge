/**
 * Fetch and display preview images for various image upload forms.
 */

import { findOr } from './utils/array';
import { assertType, assertNotNull, assertString } from './utils/assert';
import { normalizedKeyboardKey, keys } from './utils/keyboard';
import { fetchJson } from './utils/requests';
import { $, $$, clearEl, hideEl, makeEl, showEl } from './utils/dom';
import { addTag } from './tagsinput';
import { oncePersistedPageShown } from './utils/events';

const MATROSKA_MAGIC = 0x1a45dfa3;

interface ScraperImage {
  camo_url: string | ArrayBuffer;
  type?: string;
  url?: string;
}

interface ScraperResponse {
  images: ScraperImage[];
  source_url?: string;
  description?: string;
  author_name?: string;
}

interface ScraperError {
  errors: string[];
}

function scrapeUrl(url: string): Promise<ScraperResponse | ScraperError> {
  return fetchJson('POST', '/images/scrape', { url }).then(response => {
    // Scrape failures are reported as 422 with a JSON body of error
    // messages; anything else non-2xx is an unexpected server error.
    if (!response.ok && response.status !== 422) {
      throw new Error('Received error from server');
    }
    return response.json();
  });
}

function elementForEmbeddedImage({ camo_url, type }: ScraperImage): HTMLImageElement | HTMLVideoElement {
  // The upload was fetched from the scraper and is a path name
  if (typeof camo_url === 'string') {
    return makeEl('img', { className: 'scraper-preview--image', src: camo_url });
  }

  // The upload was fetched from a file input and is an ArrayBuffer
  const objectUrl = URL.createObjectURL(new Blob([camo_url], { type }));
  const tagName = new DataView(camo_url).getUint32(0) === MATROSKA_MAGIC ? 'video' : 'img';

  return makeEl(tagName, { className: 'scraper-preview--image', src: objectUrl });
}

function getStringOrDefault(elements: (string | null | undefined)[], defaultValue: string): string {
  return assertString(findOr(elements, e => Boolean(e), defaultValue));
}

export function setupImageUpload() {
  const imgPreviews = $<HTMLDivElement>('#js-image-upload-previews');

  if (!imgPreviews) return;

  const form = imgPreviews.closest('form');

  if (!form) return;

  const scraperElements = $$<HTMLInputElement>('.js-scraper', form);
  const fileField = scraperElements[0];
  const remoteUrl = scraperElements[1];
  const scraperError = scraperElements[2];

  if (!fileField || !remoteUrl || !scraperError) return;

  const descrEl = $<HTMLTextAreaElement>('.js-image-descr-input', form);
  const tagsEl = $<HTMLTextAreaElement>('.js-image-tags-input', form);
  const sourceEl = $$<HTMLInputElement>('.js-source-url', form).find(input => input.value === '');
  const fetchButton = $<HTMLButtonElement>('#js-scraper-preview');

  if (!fetchButton) return;

  const showImages = (images: ScraperImage[]) => {
    clearEl(imgPreviews);

    images.forEach((image, index) => {
      const img = elementForEmbeddedImage(image);
      const imgWrap = makeEl('span', { className: 'scraper-preview--image-wrapper' });
      imgWrap.appendChild(img);

      const label = makeEl('label', { className: 'scraper-preview--label' });
      const radio = makeEl('input', {
        type: 'radio',
        className: 'scraper-preview--input',
      });

      if (image.url) {
        radio.name = 'scraper_cache';
        radio.value = image.url;
      }

      if (index === 0) {
        radio.checked = true;
      }

      label.appendChild(radio);
      label.appendChild(imgWrap);
      imgPreviews.appendChild(label);
    });
  };

  const disableFetch = () => {
    fetchButton.setAttribute('disabled', '');
  };

  const enableFetch = () => {
    fetchButton.removeAttribute('disabled');
  };

  const showError = () => {
    clearEl(imgPreviews);
    showEl(scraperError);
    enableFetch();
  };

  const hideError = () => {
    hideEl(scraperError);
  };

  const reader = new FileReader();

  reader.addEventListener('load', event => {
    const result = event.target?.result;

    if (!result || !fileField.files?.[0]) return;

    showImages([
      {
        camo_url: assertType(result, ArrayBuffer),
        type: fileField.files[0].type,
      },
    ]);

    // Clear any currently cached data, because the file field
    // has higher priority than the scraper:
    remoteUrl.value = '';
    disableFetch();
    hideError();
  });

  // Watch for files added to the form
  fileField.addEventListener('change', () => {
    if (fileField.files && fileField.files.length) {
      reader.readAsArrayBuffer(fileField.files[0]);
    }
  });

  // Watch for [Fetch] clicks
  fetchButton.addEventListener('click', () => {
    if (!remoteUrl.value) return;

    disableFetch();

    scrapeUrl(remoteUrl.value)
      .then(data => {
        if ('errors' in data) {
          scraperError.innerText = data.errors.join(' ');
          showError();
          return;
        }

        hideError();

        // Set source
        if (sourceEl) sourceEl.value = getStringOrDefault([sourceEl.value, data.source_url], '');
        // Set description
        if (descrEl) descrEl.value = getStringOrDefault([descrEl.value, data.description], '');
        // Add author
        if (tagsEl && data.author_name) {
          addTag(tagsEl, `artist:${data.author_name.toLowerCase()}`);
        }
        // Clear selected file, if any
        fileField.value = '';
        showImages(data.images);

        enableFetch();
      })
      .catch(showError);
  });

  // Fetch on "enter" in url field
  remoteUrl.addEventListener('keydown', event => {
    if (normalizedKeyboardKey(event) === keys.Enter) {
      // Hit enter
      fetchButton.click();
    }
  });

  // Enable/disable the fetch button based on content in the image scraper. Fetching with no URL makes no sense.
  function setFetchEnabled() {
    if (remoteUrl.value.length > 0) {
      enableFetch();
    } else {
      disableFetch();
    }
  }

  remoteUrl.addEventListener('input', () => setFetchEnabled());
  setFetchEnabled();

// Catch unintentional navigation away from the page

  const beforeUnload = (event: BeforeUnloadEvent): string => {
    event.preventDefault();
    event.returnValue = '';
    return '';
  };

  const registerBeforeUnload = () => {
    window.addEventListener('beforeunload', beforeUnload);
  };

  const unregisterBeforeUnload = () => {
    window.removeEventListener('beforeunload', beforeUnload);
    window.onbeforeunload = null;
  };

  const submitHandler = () => {
    unregisterBeforeUnload();
  };

  const createTagError = (message: string) => {
    const buttonAfter = $<HTMLButtonElement>('#tagsinput-save');

    if (!buttonAfter) return;

    const errorElement = makeEl('span', { className: 'help-block tag-error', innerText: message });
    buttonAfter.insertAdjacentElement('beforebegin', errorElement);
  };

  const clearTagErrors = () => {
    $$('.tag-error').forEach(el => el.remove());
  };

  const ratingsTags = ['safe', 'suggestive', 'questionable', 'explicit', 'semi-grimdark', 'grimdark', 'grotesque'];

  // populate tag error helper bars as necessary
  // return true if all checks pass
  // return false if any check fails

  // Disabled broken client-side check so form submits directly to server-side tag_validator.ex
  const validateTags = (): boolean => {
    return true;
  };

  fileField.addEventListener('change', registerBeforeUnload);
  fetchButton.addEventListener('click', registerBeforeUnload);
  form.addEventListener('submit', submitHandler);
  oncePersistedPageShown(unregisterBeforeUnload);
}
