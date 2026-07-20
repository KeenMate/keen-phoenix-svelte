<script>
  let { disabled = false, onSend, t = (k) => k } = $props();

  let text = $state("");
  let input = $state();

  function submit(event) {
    event.preventDefault();
    const value = text.trim();
    if (!value || disabled) return;
    onSend(value);
    text = "";
    input?.focus();
  }
</script>

<form class="composer" onsubmit={submit}>
  <input
    bind:this={input}
    bind:value={text}
    {disabled}
    placeholder={disabled ? t("connecting") : t("messagePlaceholder")}
    autocomplete="off"
    aria-label={t("messageAria")}
  />
  <button type="submit" disabled={disabled || !text.trim()}>{t("send")}</button>
</form>

<style>
  .composer {
    display: flex;
    gap: 8px;
    padding: 12px 16px;
    border-top: 1px solid #e2e8f0;
    background: #fff;
  }
  input {
    flex: 1;
    padding: 10px 14px;
    border: 1px solid #cbd5e1;
    border-radius: 10px;
    font: inherit;
    font-size: 0.92rem;
    outline: none;
  }
  input:focus {
    border-color: #6366f1;
    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.15);
  }
  button {
    padding: 0 18px;
    border: 0;
    border-radius: 10px;
    background: #6366f1;
    color: #fff;
    font: inherit;
    font-weight: 600;
    cursor: pointer;
  }
  button:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
</style>
