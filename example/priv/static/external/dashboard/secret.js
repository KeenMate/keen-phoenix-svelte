// Present on the origin but intentionally ABSENT from keen-manifest.json.
// `dashboard-guarded` 404s this before any upstream fetch; the unguarded
// `dashboard-open` app serves it. That contrast is the point of the demo.
export const marker = "served-secret";
