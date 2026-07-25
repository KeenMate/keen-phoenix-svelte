defmodule ExampleWeb.StressLive do
  @moduledoc """
  A deliberate **stress test** of the island machinery: a searchable, paginated
  catalog of 500 products where *every visible row mounts its own `qr-tag` Svelte
  island*.

  Load vectors, on purpose:

    * **Mount at scale** — up to a full page of rows (100) mount at once off one
      shared, preloaded bundle; **paging tears down this page's islands and mounts
      the next**, so switching pages churns mount/teardown through `AppsManager`
      + the `KeenApp` hook.
    * **Server → island prop-sync at scale** — the amount `<input>` is
      **LiveView-owned** (HEEx, not the island). Each edit round-trips to the
      server, which recomputes the line `total`, re-renders that row, and the hook
      pushes fresh props to just that island via `setProps` — which re-encodes its
      QR. "Set page amounts" fans one server event out to every visible island.

  The island itself (`assets/apps/qr-tag`) holds no client state: it encodes
  whatever `{code, title, unit_price, amount, total}` the server hands it.
  """
  use ExampleWeb, :live_view

  alias Example.Catalog

  @page_sizes [10, 25, 50, 100]
  @default_page_size 25

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       # sku => amount; absent means the default of 1
       amounts: %{},
       page_sizes: @page_sizes,
       total_count: Catalog.count(),
       preload_apps: ["qr-tag"],
       page_title: "Stress test"
     )}
  end

  # The URL owns query/page/size/eager: the page-size select push_patches here
  # (live, keeps amounts), the eager toggle full-redirects here (eager only
  # applies at app.js parse). Reading them here covers the initial load too.
  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     assign(socket,
       query: params["query"] || "",
       page: parse_page(params["page"] || "1"),
       page_size: parse_size(params["page_size"] || ""),
       eager: params["eager"] == "1"
     )}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, assign(socket, query: query, page: 1)}
  end

  def handle_event("set_page_size", %{"page_size" => size}, socket) do
    %{query: query, eager: eager} = socket.assigns

    params = %{
      query: query,
      page: 1,
      page_size: parse_size(size),
      eager: if(eager, do: "1", else: "0")
    }

    {:noreply, push_patch(socket, to: ~p"/stress?#{params}")}
  end

  def handle_event("goto_page", %{"page" => page}, socket) do
    {:noreply, assign(socket, :page, parse_page(page))}
  end

  def handle_event("toggle_eager", _params, socket) do
    %{eager: eager, query: query, page: page, page_size: page_size} = socket.assigns

    # A full-page redirect (not push_navigate): eager mounting only takes effect
    # when `mountStatic()` sees `data-eager` in the dead render at app.js parse.
    params = %{eager: if(eager, do: "0", else: "1"), query: query, page: page, page_size: page_size}
    {:noreply, redirect(socket, to: ~p"/stress?#{params}")}
  end

  def handle_event("set_amount", %{"sku" => sku, "amount" => amount}, socket) do
    {:noreply, assign(socket, :amounts, Map.put(socket.assigns.amounts, sku, parse_amount(amount)))}
  end

  def handle_event("set_all", %{"amount" => amount}, socket) do
    n = parse_amount(amount)
    results = Catalog.search(socket.assigns.query)
    page = clamp_page(socket.assigns.page, length(results), socket.assigns.page_size)

    amounts =
      results
      |> page_slice(page, socket.assigns.page_size)
      |> Enum.reduce(socket.assigns.amounts, fn p, acc -> Map.put(acc, p.code, n) end)

    {:noreply, assign(socket, :amounts, amounts)}
  end

  # blank / garbage => 0; never negative
  defp parse_amount(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> 0
    end
  end

  defp parse_size(value) do
    case Integer.parse(to_string(value)) do
      {n, _} -> if n in @page_sizes, do: n, else: @default_page_size
      _ -> @default_page_size
    end
  end

  defp parse_page(value) do
    case Integer.parse(to_string(value)) do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp total_pages(count, size), do: max(1, ceil(count / size))
  defp clamp_page(page, count, size), do: page |> max(1) |> min(total_pages(count, size))
  defp page_slice(results, page, size), do: Enum.slice(results, (page - 1) * size, size)
  defp page_window(page, pages), do: Enum.to_list(max(1, page - 2)..min(pages, page + 2))

  defp amount_for(amounts, code), do: Map.get(amounts, code, 1)
  defp line_total(unit_price, amount), do: Float.round(unit_price * amount, 2)
  defp money(n), do: "$" <> :erlang.float_to_binary(n * 1.0, decimals: 2)

  @impl true
  def render(assigns) do
    all = Catalog.search(assigns.query)
    count = length(all)
    pages = total_pages(count, assigns.page_size)
    page = clamp_page(assigns.page, count, assigns.page_size)

    assigns =
      assign(assigns,
        results: page_slice(all, page, assigns.page_size),
        match_count: count,
        pages: pages,
        page: page,
        window: page_window(page, pages),
        first: if(count == 0, do: 0, else: (page - 1) * assigns.page_size + 1),
        last: min(count, page * assigns.page_size)
      )

    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:stress}
      title="Stress test"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-6xl mx-auto space-y-8 pb-6">
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-qr-code" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">QR catalog under load</h1>
            <span :if={@eager} class="badge badge-primary badge-sm gap-1">
              <.icon name="hero-bolt-mini" class="size-3" /> eager
            </span>
          </div>
          <p class="mt-3 text-base-content/70">
            A catalog of <strong>{@total_count} products</strong>, paginated. Every visible row
            mounts its own <code>qr-tag</code>
            Svelte island — up to <strong>{@page_size} per page</strong>
            — whose QR encodes the product code, title, unit price, the amount you type, and the line
            total. The amount box is <strong>LiveView-owned</strong>: each edit round-trips to the
            server, which recomputes the total and pushes fresh props back to that one island (which
            re-encodes). Paging tears down this page's islands and mounts the next — mount/teardown
            churn on top of the per-row prop-sync.
          </p>
          <p class="mt-2 text-base-content/70">
            Flip <strong>Eager mount</strong>
            to compare cold-load behavior: on, the QR islands are mounted by
            <code>mountStatic()</code>
            the instant <code>app.js</code>
            parses — before the socket connects — so they paint immediately; off, each waits for the
            <code>KeenApp</code>
            hook after connect. The toggle reloads the page, since eager only applies to the initial
            paint (the qty inputs are LiveView-owned and stay interactive only after connect either
            way).
          </p>
        </section>

        <section class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <form phx-change="search" class="flex-1">
            <label class="input input-bordered flex items-center gap-2 max-w-md">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-60" />
              <input
                type="text"
                name="query"
                value={@query}
                phx-debounce="200"
                placeholder="Search products…"
                class="grow"
                autocomplete="off"
              />
            </label>
          </form>

          <div class="flex items-end gap-3">
            <div class="form-control">
              <span class="label-text text-xs text-base-content/60">Eager mount</span>
              <div class="flex items-center gap-2 h-8">
                <input
                  type="checkbox"
                  class="toggle toggle-primary toggle-sm"
                  checked={@eager}
                  phx-click="toggle_eager"
                  aria-label="Toggle eager mounting"
                />
                <span class="text-xs text-base-content/50">reloads</span>
              </div>
            </div>

            <form phx-change="set_page_size">
              <label class="form-control">
                <span class="label-text text-xs text-base-content/60">Page size</span>
                <select name="page_size" class="select select-bordered select-sm w-28">
                  <option :for={s <- @page_sizes} value={s} selected={s == @page_size}>
                    {s} / page
                  </option>
                </select>
              </label>
            </form>

            <form phx-submit="set_all" class="flex items-end gap-2">
              <label class="form-control">
                <span class="label-text text-xs text-base-content/60">Set page amounts</span>
                <input
                  type="number"
                  name="amount"
                  min="0"
                  value="1"
                  class="input input-bordered input-sm w-24"
                />
              </label>
              <button type="submit" class="btn btn-sm btn-primary">Apply</button>
            </form>
          </div>
        </section>

        <section class="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p class="text-sm text-base-content/60">
            Showing <strong>{@first}–{@last}</strong> of {@match_count}
            <span :if={@match_count != @total_count}>matched</span>
            <span class="opacity-60">· {@total_count} in catalog</span>
          </p>
          <.pager page={@page} pages={@pages} window={@window} />
        </section>

        <section class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          <div
            :for={p <- @results}
            class="card bg-base-100 border border-base-300 rounded-xl p-4 flex flex-row gap-4"
          >
            <div class="min-w-0 flex-1">
              <code class="text-xs font-mono text-primary">{p.code}</code>
              <h3 class="font-semibold truncate" title={p.title}>{p.title}</h3>
              <p class="text-sm text-base-content/60 mt-0.5">{money(p.unit_price)} / unit</p>

              <form phx-change="set_amount" class="mt-3 flex items-center gap-2">
                <input type="hidden" name="sku" value={p.code} />
                <label class="text-xs text-base-content/60">Qty</label>
                <input
                  type="number"
                  name="amount"
                  min="0"
                  value={amount_for(@amounts, p.code)}
                  phx-debounce="300"
                  class="input input-bordered input-sm w-20"
                />
                <span class="text-sm font-semibold ml-auto">
                  {money(line_total(p.unit_price, amount_for(@amounts, p.code)))}
                </span>
              </form>
            </div>

            <.app
              name="qr-tag"
              id={"qr-#{p.code}"}
              eager={@eager}
              props={%{
                code: p.code,
                title: p.title,
                unit_price: p.unit_price,
                amount: amount_for(@amounts, p.code),
                total: line_total(p.unit_price, amount_for(@amounts, p.code))
              }}
            >
              <:placeholder>
                <div class="skeleton size-24 rounded-md shrink-0"></div>
              </:placeholder>
            </.app>
          </div>
        </section>

        <p :if={@match_count == 0} class="text-center text-base-content/50 py-12">
          No products match "<strong>{@query}</strong>".
        </p>

        <div :if={@pages > 1} class="flex justify-center">
          <.pager page={@page} pages={@pages} window={@window} />
        </div>
      </div>

      <:aside>
        <Layouts.info_panel title="What's under load">
          <p>
            One shared, preloaded <code>qr-tag</code>
            bundle, mounted once per visible row. The island is stateless — it just encodes the props
            the server gives it.
          </p>
          <:wire label="mount at scale">
            Up to <strong>{@page_size}</strong>
            islands mount per page from one <code>import()</code>; paging remounts them.
          </:wire>
          <:wire label="qty (LiveView-owned)">
            The <code>&lt;input&gt;</code>
            lives in HEEx. Editing it round-trips to the server (debounced), which recomputes
            <code>total</code>.
          </:wire>
          <:wire label="prop-sync">
            The server re-renders the row; the hook's <code>updated()</code>
            pushes new props to that island via <code>setProps</code>, which re-encodes the QR.
          </:wire>
          <:wire label="set page amounts">
            One server event updates every amount on the current page — a fan-out of
            <code>setProps</code> to all mounted islands at once.
          </:wire>
          <:wire label="eager mount">
            {(@eager && "On") || "Off"} — when on, <code>mountStatic()</code>
            mounts the QRs before the socket connects; the toggle reloads, since eager only applies
            to the dead render's first paint.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end

  # Numbered pager: « first · ‹ prev · a window of pages around the current one ·
  # next › · last ». Each button drives the "goto_page" event.
  attr :page, :integer, required: true
  attr :pages, :integer, required: true
  attr :window, :list, required: true

  defp pager(assigns) do
    ~H"""
    <nav :if={@pages > 1} class="join">
      <button
        class="join-item btn btn-sm"
        disabled={@page == 1}
        phx-click="goto_page"
        phx-value-page="1"
      >
        «
      </button>
      <button
        class="join-item btn btn-sm"
        disabled={@page == 1}
        phx-click="goto_page"
        phx-value-page={@page - 1}
      >
        ‹
      </button>
      <button
        :for={n <- @window}
        class={["join-item btn btn-sm", n == @page && "btn-active btn-primary"]}
        phx-click="goto_page"
        phx-value-page={n}
      >
        {n}
      </button>
      <button
        class="join-item btn btn-sm"
        disabled={@page == @pages}
        phx-click="goto_page"
        phx-value-page={@page + 1}
      >
        ›
      </button>
      <button
        class="join-item btn btn-sm"
        disabled={@page == @pages}
        phx-click="goto_page"
        phx-value-page={@pages}
      >
        »
      </button>
    </nav>
    """
  end
end
