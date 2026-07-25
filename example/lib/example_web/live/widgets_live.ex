defmodule ExampleWeb.WidgetsLive do
  @moduledoc """
  Demonstrates a **multi-component island** and the `<.app component="…">` sugar.

  Both cards on this page mount the *same* `widgets` app — one bundle, one shared
  Svelte runtime, `import()`ed once — and differ only by `component`: one renders
  the `chart` view, the other the `table` view. They receive **identical** props
  (`title` + `data`); "Randomize" regenerates the data on the server and pushes it
  to both islands at once via `setProps`, so both views re-render in lockstep.

  This is the alternative to shipping `chart` and `table` as two separate apps
  (which would inline two copies of the Svelte runtime): keep related views in one
  app and select between them with a prop.
  """
  use ExampleWeb, :live_view

  @labels ~w(Jan Feb Mar Apr May Jun)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       data: gen_data(),
       preload_apps: ["widgets"],
       page_title: "Widgets"
     )}
  end

  @impl true
  def handle_event("randomize", _params, socket) do
    {:noreply, assign(socket, :data, gen_data())}
  end

  defp gen_data do
    Enum.map(@labels, fn label -> %{label: label, value: :rand.uniform(90) + 10} end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:widgets}
      title="Widgets"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-5xl mx-auto space-y-8 pb-6">
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-squares-2x2" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">One app, two views</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            Both cards below mount the <em>same</em>
            <code>widgets</code>
            island — a single bundle with a shared Svelte runtime, imported once. Each
            <code>&lt;.app&gt;</code>
            picks its view with <code>component=</code>, which is just sugar for a
            <code>component</code>
            prop. They get identical <code>data</code>; <strong>Randomize</strong>
            regenerates it on the server and pushes to both at once.
          </p>
        </section>

        <div>
          <button class="btn btn-primary btn-sm gap-2" phx-click="randomize">
            <.icon name="hero-arrow-path" class="size-4" /> Randomize
          </button>
        </div>

        <section class="grid gap-6 md:grid-cols-2">
          <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
            <.app
              name="widgets"
              id="widgets-chart"
              component="chart"
              props={%{title: "Monthly sales", data: @data}}
            >
              <:placeholder>
                <div class="skeleton h-48 w-full rounded-xl"></div>
              </:placeholder>
            </.app>
          </div>

          <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
            <.app
              name="widgets"
              id="widgets-table"
              component="table"
              props={%{title: "Monthly sales", data: @data}}
            >
              <:placeholder>
                <div class="skeleton h-48 w-full rounded-xl"></div>
              </:placeholder>
            </.app>
          </div>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="Multi-component island">
          <p>
            Related views ship in one app so they share a runtime, instead of two apps each
            inlining their own copy of Svelte.
          </p>
          <:wire label="one bundle">
            Both cards <code>import()</code>
            the same <code>widgets/main.mjs</code> — fetched once, mounted twice.
          </:wire>
          <:wire label="component=">
            <code>&lt;.app component="chart"&gt;</code>
            desugars to a <code>component</code> prop; the mount fn maps it to a Svelte component.
          </:wire>
          <:wire label="shared props">
            Both views take the same <code>data</code>; Randomize pushes new props to both via
            <code>setProps</code>.
          </:wire>
          <:wire label="fixed at mount">
            The view is chosen once at mount (not reactively swappable) — one view per
            <code>&lt;.app&gt;</code>.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
