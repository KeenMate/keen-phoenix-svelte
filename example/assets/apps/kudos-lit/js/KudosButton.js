import { LitElement, html, css } from "lit";

// A tiny Lit web component. Styling lives in the shadow DOM (Lit's model), so the
// island still ships no separate stylesheet — consistent with the others.
export class KudosButton extends LitElement {
  static properties = { label: {}, count: { type: Number } };

  static styles = css`
    :host {
      display: inline-block;
      font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    }
    button {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      border: 1px solid #f9a8d4;
      background: #fdf2f8;
      color: #be185d;
      border-radius: 999px;
      padding: 8px 16px;
      font: inherit;
      font-weight: 600;
      cursor: pointer;
    }
    button:hover {
      background: #fce7f3;
    }
    .n {
      background: #ec4899;
      color: #fff;
      border-radius: 999px;
      padding: 0 8px;
      font-size: 0.8rem;
    }
  `;

  constructor() {
    super();
    this.label = "Kudos";
    this.count = 0;
  }

  _click() {
    this.count += 1;
    this.dispatchEvent(
      new CustomEvent("kudos", { detail: { count: this.count }, bubbles: true, composed: true }),
    );
  }

  render() {
    return html`<button @click=${this._click}>👏 ${this.label} <span class="n">${this.count}</span></button>`;
  }
}

// Guard against re-definition across live navigation / remounts.
if (!customElements.get("kudos-button")) {
  customElements.define("kudos-button", KudosButton);
}
