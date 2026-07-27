// A data table — lazily imported on the Table tab.
export default function render(container, data) {
  const rows = data.rows || [];
  container.innerHTML = `
    <table class="keen-dash__table">
      <thead><tr><th>Account</th><th>Plan</th><th>Seats</th></tr></thead>
      <tbody>
        ${rows.map((r) => `<tr><td>${r.name}</td><td>${r.plan}</td><td>${r.seats}</td></tr>`).join("")}
      </tbody>
    </table>`;
}
