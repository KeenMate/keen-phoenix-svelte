defmodule ExampleWeb.InlineEditLive do
  @moduledoc """
  In-place prose editing — the clearest showcase of the `live` bridge going the
  *other* way (island → LiveView).

  LiveView owns the page: the prose blocks, the "I am admin" switch, and the
  floating pencil/translate toolbar rendered over each block. It's plain HEEx,
  no JS. When an admin clicks a toolbar icon, LiveView conditionally renders the
  `prose` Svelte island as an overlay anchored on that block. The island is one
  app with two components (an editor and a translator, chosen by `mode`); when
  it's done it pushes `save_block` back over `live`, LiveView updates the block
  and removes the overlay.

  Persistence is deliberately split: `save_block` (over `live`) updates the block
  in *socket assigns* immediately, and the island also POSTs the same HTML to
  `InlineEditController` over `api`, which writes it into the **Plug session** —
  so the edit survives a reload. `mount` seeds from that session. A LiveView
  can't write the session itself, which is exactly why the durable write goes
  through `api`. Per-user, expires with the session, no shared store to reset.
  """
  use ExampleWeb, :live_view

  alias Example.Content

  @editor_snippet """
  // prose/js/App.svelte — instant update over `live`, durable write over `api`
  // (a LiveView can't write the session itself, so the island persists it).
  async function persist(html) {
    live?.pushEvent("save_block", { id: block.id, html });     // instant, in-session
    await api?.post("/inline-edit/blocks", { id: block.id, html }); // durable (session)
  }
  """

  @host_snippet """
  # inline_edit_live.ex — seed from the session so edits survive a reload; the
  # instant `save_block` update leaves the overlay open until the island's POST
  # to InlineEditController has persisted the same HTML into the session.
  def mount(_params, session, socket) do
    overrides = Map.get(session, "inline_edit", %{})
    blocks = Content.apply_overrides(Content.default_blocks(), overrides)
    {:ok, assign(socket, blocks: blocks, admin: false, editing: nil)}
  end

  def handle_event("save_block", %{"id" => id, "html" => html}, socket) do
    {:reply, %{ok: true}, assign(socket, :blocks, Content.put_html(socket.assigns.blocks, id, html))}
  end
  """

  @toolbar_snippet """
  # inline_edit_live.ex — the toolbar is HEEx + CSS, no JavaScript.
  <div :for={block <- @blocks} class="group relative ...">   # relative anchors it; group enables hover
    <div class="prose ...">{raw(block.html)}</div>

    # Existence: rendered only when admin is on and this block isn't already open.
    # Appearance: `hidden group-hover:flex` reveals it on hover — pure CSS.
    <div :if={@admin and not editing?(@editing, block.id)}
         class="absolute -top-3 right-2 hidden group-hover:flex ...">
      <button phx-click="edit_block"      phx-value-id={block.id}>✎  pencil</button>
      <button phx-click="translate_block" phx-value-id={block.id}>🌐 translate</button>
    </div>
  </div>

  # The click records which block + which tool; the re-render hides the toolbar
  # (editing? is now true) and mounts the `prose` island overlay in its place.
  def handle_event("edit_block", %{"id" => id}, socket), do: {:noreply, open(socket, id, "edit")}

  defp open(socket, id, mode) do
    # Re-check admin on the SERVER — the toggle + CSS are only UX; this is the boundary.
    if socket.assigns.admin and Content.get(socket.assigns.blocks, id),
      do: assign(socket, editing: %{id: id, mode: mode}),
      else: socket
  end
  """

  def mount(_params, session, socket) do
    # Seed from the session so persisted edits survive a reload (see the module
    # doc + InlineEditController); a fresh session just gets the defaults.
    overrides = Map.get(session, "inline_edit", %{})
    blocks = Content.apply_overrides(Content.default_blocks(), overrides)

    {:ok,
     assign(socket,
       page_title: "Inline edit",
       blocks: blocks,
       admin: false,
       editing: nil,
       editor_snippet: @editor_snippet,
       host_snippet: @host_snippet,
       toolbar_snippet: @toolbar_snippet
     )}
  end

  # The admin switch. Turning editing off also closes any open overlay.
  def handle_event("toggle_admin", _params, socket) do
    {:noreply, assign(socket, admin: not socket.assigns.admin, editing: nil)}
  end

  def handle_event("edit_block", %{"id" => id}, socket) do
    {:noreply, open(socket, id, "edit")}
  end

  def handle_event("translate_block", %{"id" => id}, socket) do
    {:noreply, open(socket, id, "translate")}
  end

  def handle_event("close_editor", _params, socket) do
    {:noreply, assign(socket, editing: nil)}
  end

  # Pushed by the island for the instant, in-session update. The overlay is left
  # open here — the island closes it (close_editor) once the durable POST to
  # InlineEditController has persisted the same HTML into the session.
  #
  # Sanitize here too: this HTML is rendered with raw/1 right away, and it's
  # client-controlled (a pushEvent payload), so it gets the same scrubbing the
  # durable save does. In a real app you'd also authorize the caller — the admin
  # toggle is cosmetic; these handlers are the real boundary.
  def handle_event("save_block", %{"id" => id, "html" => html}, socket) do
    blocks = Content.put_html(socket.assigns.blocks, id, HtmlSanitizeEx.basic_html(html))
    {:reply, %{ok: true}, assign(socket, :blocks, blocks)}
  end

  # Reply-style event: the translator asks the server to translate the source
  # HTML into `to` and renders the result (@html) before the admin accepts it.
  # `html` is a client-controlled payload, so sanitize the result before it's
  # rendered back.
  def handle_event("translate_text", %{"html" => html, "to" => to}, socket) do
    {:reply, %{html: HtmlSanitizeEx.basic_html(Content.translate(html, to))}, socket}
  end

  defp open(socket, id, mode) do
    if socket.assigns.admin and Content.get(socket.assigns.blocks, id) do
      assign(socket, editing: %{id: id, mode: mode})
    else
      socket
    end
  end

  # Is the overlay open on this specific block?
  defp editing?(nil, _id), do: false
  defp editing?(%{id: id}, id), do: true
  defp editing?(_editing, _id), do: false

  def render(assigns) do
    ~H"""
    <Layouts.workspace
      current_user={@current_user}
      active={:inline_edit}
      title="Inline edit"
      locale={@locale}
      flash={@flash}
    >
      <div class="max-w-4xl mx-auto space-y-10 pb-6">
        <%!-- The admin switch --%>
        <section class="flex items-center justify-between rounded-xl border border-base-300 bg-base-100 p-4">
          <div>
            <p class="font-semibold">I am an admin</p>
            <p class="text-sm text-base-content/60">
              Flip this to reveal the per-block editing toolbar. It only changes
              what LiveView renders — the island is mounted on demand.
            </p>
          </div>
          <div class="flex items-center gap-3">
            <%!-- Clearing edits means clearing the session — an HTTP request, not
            a LiveView event — so it's a plain form POST that redirects back. --%>
            <form :if={@admin} method="post" action={~p"/inline-edit/reset"}>
              <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
              <button type="submit" class="btn btn-ghost btn-sm gap-1.5" title="Discard saved edits">
                <.icon name="hero-arrow-path" class="size-4" /> Reset
              </button>
            </form>
            <input
              type="checkbox"
              class="toggle toggle-primary"
              checked={@admin}
              phx-click="toggle_admin"
              aria-label="Toggle admin mode"
            />
          </div>
        </section>

        <%!-- The editable article --%>
        <article class="rounded-xl border border-base-300 bg-base-100 p-8 space-y-4">
          <div
            :for={block <- @blocks}
            class={[
              "group relative rounded-lg transition-colors",
              @admin &&
                "-mx-3 px-3 py-1 hover:bg-base-200/60 outline-dashed outline-1 outline-transparent hover:outline-base-300"
            ]}
          >
            <%!-- The block content, owned by LiveView --%>
            <div class="prose max-w-none prose-headings:mt-0 prose-headings:mb-2">
              {raw(block.html)}
            </div>

            <%!-- Floating toolbar: admin-only, hidden while this block is open --%>
            <div
              :if={@admin and not editing?(@editing, block.id)}
              class="absolute -top-3 right-2 hidden group-hover:flex items-center gap-1 rounded-lg border border-base-300 bg-base-100 p-1 shadow-md"
            >
              <button
                type="button"
                class="btn btn-ghost btn-xs btn-square"
                phx-click="edit_block"
                phx-value-id={block.id}
                title="Edit this block"
                aria-label="Edit this block"
              >
                <.icon name="hero-pencil-square" class="size-4 text-primary" />
              </button>
              <button
                type="button"
                class="btn btn-ghost btn-xs btn-square"
                phx-click="translate_block"
                phx-value-id={block.id}
                title="Auto-translate this block"
                aria-label="Auto-translate this block"
              >
                <.icon name="hero-language" class="size-4 text-primary" />
              </button>
            </div>

            <%!-- The island, mounted over the block only while editing it --%>
            <div :if={editing?(@editing, block.id)} class="absolute inset-x-0 -top-2 z-20">
              <.app
                name="prose"
                id={"prose-#{block.id}-#{@editing.mode}"}
                props={%{block: block, mode: @editing.mode, languages: Content.languages()}}
              />
            </div>
          </div>
        </article>

        <%!-- How it works --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-pencil-square" class="size-7 text-primary" />
            <h1 class="text-2xl font-bold tracking-tight">Editing where the words live</h1>
          </div>
          <p class="mt-3 text-base-content/70">
            The blocks above are rendered by <strong>LiveView</strong>, not the island.
            Toggle <em>admin</em>
            and a floating toolbar appears over each block. Clicking the pencil (or the
            translate icon) mounts the <code>prose</code>
            island <strong>over that one block</strong>. It's one Svelte app with two
            components — a TipTap editor and a translator — chosen by a <code>mode</code>
            prop. When you save, the island pushes the new HTML back over <code>live</code>, LiveView updates the block and unmounts the overlay.
          </p>
        </section>

        <%!-- How the floating toolbar works --%>
        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-cursor-arrow-rays" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">The floating toolbar</h2>
          </div>
          <p class="mt-3 text-base-content/70">
            The pencil/translate chip over each block is <strong>pure LiveView + CSS</strong>
            — no JavaScript, no island. Three independent decisions govern it:
          </p>

          <div class="grid gap-4 md:grid-cols-3 mt-4">
            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <.icon name="hero-server" class="size-4 text-primary" />
                <span class="text-sm font-semibold">Existence — server</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                An <code>:if</code>
                guard on <code>@admin</code>
                (and "not editing this block") means LiveView only writes the toolbar into the HTML
                when admin is on. In read mode it isn't in the DOM at all.
              </p>
            </div>

            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <.icon name="hero-eye" class="size-4 text-primary" />
                <span class="text-sm font-semibold">Appearance — CSS</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Even when it exists it's <code>hidden</code>
                until you hover the block. The wrapper is a Tailwind <code>group</code>, so
                <code>group-hover:flex</code>
                reveals the chip on hover — no server round-trip.
              </p>
            </div>

            <div class="card bg-base-100 border border-base-300 rounded-xl p-5">
              <div class="flex items-center gap-2">
                <.icon name="hero-bolt" class="size-4 text-primary" />
                <span class="text-sm font-semibold">Action — phx-click</span>
              </div>
              <p class="text-sm text-base-content/70 mt-2">
                Each button carries <code>phx-click</code>
                (<code>edit_block</code> or <code>translate_block</code>) plus <code>phx-value-id</code>, so the click sends
                the event and the block id back to LiveView.
              </p>
            </div>
          </div>

          <p class="mt-4 text-base-content/70">
            The handler records <em>which</em>
            block and <em>which</em>
            tool in <code>@editing</code>. That re-render hides the toolbar (<code>editing?</code> is now true) and mounts the
            <code>prose</code>
            island overlay in its place — the editor or the translator, picked by <code>mode</code>.
            Crucially <code>open/3</code>
            <strong>re-checks <code>admin</code> on the server</strong>: the toggle and the CSS are
            only UX, the event handler is the real boundary.
          </p>

          <pre class="mt-3 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@toolbar_snippet}</code></pre>
        </section>

        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-arrows-right-left" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">The round-trip, both directions</h2>
          </div>
          <ol class="mt-3 space-y-3 text-sm text-base-content/70 list-decimal pl-5 marker:text-base-content/40">
            <li>
              <strong>LiveView → island (props).</strong>
              The block's current HTML, the <code>mode</code>, and the language list
              are handed in as <code>props</code>
              when the overlay is rendered.
            </li>
            <li>
              <strong>Island edits locally.</strong>
              TipTap owns its own DOM — that's why the mount sits under <code>phx-update="ignore"</code>: LiveView renders
              <em>whether</em>
              the island exists, never <em>what's inside</em>
              it.
            </li>
            <li>
              <strong>Island → LiveView (live.pushEvent).</strong>
              "Save" pushes <code>save_block</code>
              for the instant update; the translator first pushes <code>translate_text</code>
              and gets a reply, then saves on accept.
            </li>
            <li>
              <strong>Durable write over <code>api</code>.</strong>
              A LiveView can't write the Plug session itself, so the island also
              POSTs the HTML to <code>InlineEditController</code>, which stores it
              in the <em>session</em>. <code>mount</code>
              seeds from there — so the edit <strong>survives a reload</strong>,
              per-user, with no shared store.
            </li>
          </ol>
        </section>

        <section>
          <div class="flex items-center gap-2">
            <.icon name="hero-code-bracket" class="size-6 text-primary" />
            <h2 class="text-lg font-semibold">Both sides, in code</h2>
          </div>

          <p class="mt-3 text-sm font-medium">
            1 · The island pushes its result over <code>live</code>
          </p>
          <pre class="mt-1 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@editor_snippet}</code></pre>

          <p class="mt-4 text-sm font-medium">
            2 · LiveView mounts it on demand and owns persistence
          </p>
          <pre class="mt-1 bg-base-300/50 rounded-lg p-3 overflow-x-auto text-[0.72rem] leading-relaxed"><code>{@host_snippet}</code></pre>
        </section>
      </div>

      <:aside>
        <Layouts.info_panel title="Inline edit — the live bridge, reversed">
          <p>
            Most demos push <em>from</em>
            LiveView <em>into</em>
            an island. This one is the reverse: an autonomous editor island pushes
            edits <strong>back</strong>
            to its host LiveView.
          </p>
          <p>
            The toolbar is pure HEEx; the editor is a <strong>TipTap</strong>
            island mounted only while editing. Translation is a deterministic,
            offline mock on the server.
          </p>
          <:wire label="props">
            The block HTML + <code>mode</code>
            (<code>"edit"</code>/<code>"translate"</code>) + language list.
          </:wire>
          <:wire label="live">
            <code>save_block</code>
            persists the HTML; <code>translate_text</code>
            replies with a mock translation.
          </:wire>
          <:wire label="phx-update">
            The mount is <code>ignore</code>d — LiveView controls <em>if</em>
            the island exists, TipTap owns what's inside.
          </:wire>
        </Layouts.info_panel>
      </:aside>
    </Layouts.workspace>
    """
  end
end
