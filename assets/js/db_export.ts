interface ExportFileMeta {
  url: string;
  size_bytes: number;
  rows?: number;
  sha256: string;
}

interface ExportManifest {
  generated_at: string;
  files: Record<string, ExportFileMeta>;
}

function formatBytes(bytes: number): string {
  if (bytes >= 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  if (bytes >= 1024) return `${(bytes / 1024).toFixed(1)} kB`;
  return `${bytes} B`;
}

export function setupDbExportManifest() {
  const container = document.getElementById('bf-db-export');
  if (!container) return;

  const updatedEl = document.getElementById('bf-db-updated');

  fetch('https://media.beastforge.org/db_export/manifest.json', { cache: 'no-store' })
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.json() as Promise<ExportManifest>;
    })
    .then(data => {
      if (updatedEl && data.generated_at) {
        const dt = new Date(data.generated_at);
        updatedEl.textContent = `${dt.toUTCString()} (${dt.toLocaleString()} local)`;
      }

      container.querySelectorAll<HTMLElement>('[data-export-file]').forEach(row => {
        const key = row.dataset.exportFile;
        const meta = key ? data.files[key] : undefined;
        if (!meta) return;

        const sizeEl = row.querySelector<HTMLElement>('.js-export-size');
        const rowsEl = row.querySelector<HTMLElement>('.js-export-rows');
        const shaEl = row.querySelector<HTMLElement>('.js-export-sha');

        if (sizeEl) sizeEl.textContent = formatBytes(meta.size_bytes);
        if (rowsEl && typeof meta.rows === 'number') {
          rowsEl.textContent = meta.rows.toLocaleString();
        }
        if (shaEl) {
          shaEl.textContent = meta.sha256;
          shaEl.style.fontSize = '11px';
          shaEl.style.wordBreak = 'break-all';

          const td = shaEl.parentElement;
          if (td && !td.querySelector('.js-copy-sha')) {
            const copyBtn = document.createElement('button');
            copyBtn.type = 'button';
            copyBtn.className = 'button button--inline js-copy-sha';
            copyBtn.textContent = 'Copy';
            copyBtn.style.marginLeft = '6px';
            copyBtn.style.padding = '2px 6px';
            copyBtn.style.fontSize = '11px';
            copyBtn.style.cursor = 'pointer';

            copyBtn.addEventListener('click', () => {
              navigator.clipboard.writeText(meta.sha256).then(() => {
                copyBtn.textContent = 'Copied!';
                setTimeout(() => {
                  copyBtn.textContent = 'Copy';
                }, 1500);
              });
            });

            td.appendChild(copyBtn);
          }
        }
      });
    })
    .catch(() => {
      if (updatedEl) updatedEl.textContent = 'Updated daily at 04:00 UTC';
    });
}
