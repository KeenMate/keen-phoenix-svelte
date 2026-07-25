<script>
  import qrcode from "qrcode-generator";

  // Everything the QR encodes arrives as props from the server. The amount lives
  // in a LiveView <input> (not here), so each edit round-trips to the server,
  // which recomputes `total` and pushes fresh props — this island just re-encodes.
  let { code, title, unit_price, amount, total } = $props();

  // The scannable payload: the five fields, compactly. Recomputed whenever any
  // prop changes (i.e. whenever the server pushes a new amount/total).
  const payload = $derived(
    JSON.stringify({ code, title, unitPrice: unit_price, amount, total }),
  );

  // Encode to an inline SVG. type 0 = auto-size to fit the data; "M" error
  // correction. `scalable` drops the fixed px size so CSS sizes it — the same
  // string renders tiny in the card and large in the zoom modal.
  const svg = $derived.by(() => {
    const qr = qrcode(0, "M");
    qr.addData(payload);
    qr.make();
    return qr.createSvgTag({ cellSize: 3, margin: 2, scalable: true });
  });

  const money = (n) => "$" + Number(n).toFixed(2);

  // Zoom modal. Only rendered while open, so there aren't N hidden overlays on a
  // page of N islands; the Escape listener is attached only while open too.
  let open = $state(false);

  $effect(() => {
    if (!open) return;
    const onKey = (e) => e.key === "Escape" && (open = false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });
</script>

<button type="button" class="qr" onclick={() => (open = true)} aria-label={`Zoom QR for ${code}`}>
  <!-- eslint-disable-next-line svelte/no-at-html-tags -->
  {@html svg}
  <span class="cap">tap to zoom · {code}</span>
</button>

{#if open}
  <div class="qr-modal" role="dialog" aria-modal="true" aria-label={`QR for ${code}`}>
    <button type="button" class="qr-backdrop" aria-label="Close" onclick={() => (open = false)}
    ></button>
    <div class="qr-card">
      <button type="button" class="x" onclick={() => (open = false)} aria-label="Close">×</button>

      <div class="big">
        <!-- eslint-disable-next-line svelte/no-at-html-tags -->
        {@html svg}
      </div>

      <div class="meta">
        <div class="title">{title}</div>
        <div class="code">{code}</div>
        <dl>
          <div><dt>Unit</dt><dd>{money(unit_price)}</dd></div>
          <div><dt>Qty</dt><dd>{amount}</dd></div>
          <div class="tot"><dt>Total</dt><dd>{money(total)}</dd></div>
        </dl>
      </div>
    </div>
  </div>
{/if}

<style>
  .qr {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    border: 0;
    padding: 0;
    background: none;
    cursor: zoom-in;
    border-radius: 8px;
    transition: transform 0.1s ease;
  }
  .qr:hover {
    transform: scale(1.04);
  }
  .qr:focus-visible {
    outline: 2px solid #6366f1;
    outline-offset: 3px;
  }
  .qr :global(svg) {
    width: 96px;
    height: 96px;
    display: block;
    background: #fff;
    border-radius: 6px;
  }
  .cap {
    font: 600 0.65rem/1 ui-monospace, "SFMono-Regular", Menlo, monospace;
    color: #94a3b8;
    letter-spacing: 0.02em;
  }

  .qr-modal {
    position: fixed;
    inset: 0;
    z-index: 9999;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 1rem;
  }
  .qr-backdrop {
    position: absolute;
    inset: 0;
    border: 0;
    padding: 0;
    background: rgba(15, 23, 42, 0.72);
    -webkit-backdrop-filter: blur(2px);
    backdrop-filter: blur(2px);
    animation: qr-fade 0.12s ease-out;
    cursor: zoom-out;
  }
  .qr-card {
    position: relative;
    z-index: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    max-width: min(92vw, 420px);
    padding: 1.75rem;
    background: #fff;
    color: #0f172a;
    border-radius: 18px;
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.4);
    cursor: default;
    animation: qr-pop 0.14s cubic-bezier(0.16, 1, 0.3, 1);
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  .x {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    width: 32px;
    height: 32px;
    border: 0;
    border-radius: 999px;
    background: #f1f5f9;
    color: #475569;
    font-size: 1.25rem;
    line-height: 1;
    cursor: pointer;
  }
  .x:hover {
    background: #e2e8f0;
  }
  .big :global(svg) {
    width: min(72vw, 300px);
    height: auto;
    display: block;
    background: #fff;
    border-radius: 8px;
  }
  .meta {
    text-align: center;
    width: 100%;
  }
  .meta .title {
    font-weight: 700;
    font-size: 1.05rem;
  }
  .meta .code {
    font: 600 0.75rem/1.4 ui-monospace, "SFMono-Regular", Menlo, monospace;
    color: #6366f1;
  }
  .meta dl {
    display: flex;
    justify-content: center;
    gap: 1.25rem;
    margin: 0.9rem 0 0;
  }
  .meta dl div {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .meta dt {
    font-size: 0.65rem;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    color: #94a3b8;
  }
  .meta dd {
    margin: 0;
    font-weight: 600;
    font-variant-numeric: tabular-nums;
  }
  .meta .tot dd {
    color: #059669;
  }

  @keyframes qr-fade {
    from {
      opacity: 0;
    }
  }
  @keyframes qr-pop {
    from {
      opacity: 0;
      transform: translateY(8px) scale(0.96);
    }
  }
</style>
