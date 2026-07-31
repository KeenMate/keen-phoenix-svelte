defmodule Example.Content do
  @moduledoc """
  Seed prose for the `/inline-edit` demo plus a deterministic mock translator.

  This module is **pure functions only** — the editable blocks live in the
  hosting LiveView's *socket assigns* (per session/connection), so every edit is
  private to that page and simply resets on reload. There is no shared Agent/ETS
  store, and therefore nothing to wire into the periodic reset job: a LiveView
  can't write back to the Plug session after mount anyway, so keeping the working
  copy in assigns is the natural fit.
  """

  @blocks [
    %{
      id: "headline",
      title: "Headline",
      html: "<h2>Welcome to KeenSpace</h2>"
    },
    %{
      id: "intro",
      title: "Intro paragraph",
      html:
        "<p>KeenSpace lets your team ship autonomous Svelte islands into Phoenix. " <>
          "Each app mounts itself, talks to the server, and stays simple and fast.</p>"
    },
    %{
      id: "feature",
      title: "Feature blurb",
      html:
        "<p>Edit this text today. An admin can open the editor right on the page, " <>
          "change the words, and translate everything for a global team.</p>"
    }
  ]

  # Target languages offered by the Translator component. Kept tiny and offline —
  # the point is to show the *round-trip*, not to be a real MT engine.
  @languages [
    %{code: "es", label: "Español"},
    %{code: "fr", label: "Français"},
    %{code: "de", label: "Deutsch"}
  ]

  # Word-level dictionaries. The seed prose above is written from these words so
  # an "auto translation" is visibly different without needing a network call.
  @dicts %{
    "es" => %{
      "Welcome" => "Bienvenido",
      "team" => "equipo",
      "ship" => "enviar",
      "islands" => "islas",
      "apps" => "aplicaciones",
      "app" => "aplicación",
      "server" => "servidor",
      "simple" => "simple",
      "fast" => "rápido",
      "Edit" => "Edita",
      "text" => "texto",
      "today" => "hoy",
      "admin" => "administrador",
      "editor" => "editor",
      "page" => "página",
      "words" => "palabras",
      "translate" => "traducir",
      "everything" => "todo",
      "global" => "global",
      "change" => "cambiar",
      "open" => "abrir",
      "mounts" => "monta",
      "autonomous" => "autónomas"
    },
    "fr" => %{
      "Welcome" => "Bienvenue",
      "team" => "équipe",
      "ship" => "expédier",
      "islands" => "îlots",
      "apps" => "applications",
      "app" => "application",
      "server" => "serveur",
      "simple" => "simple",
      "fast" => "rapide",
      "Edit" => "Modifier",
      "text" => "texte",
      "today" => "aujourd’hui",
      "admin" => "administrateur",
      "editor" => "éditeur",
      "page" => "page",
      "words" => "mots",
      "translate" => "traduire",
      "everything" => "tout",
      "global" => "mondiale",
      "change" => "changer",
      "open" => "ouvrir",
      "mounts" => "monte",
      "autonomous" => "autonomes"
    },
    "de" => %{
      "Welcome" => "Willkommen",
      "team" => "Team",
      "ship" => "ausliefern",
      "islands" => "Inseln",
      "apps" => "Apps",
      "app" => "App",
      "server" => "Server",
      "simple" => "einfach",
      "fast" => "schnell",
      "Edit" => "Bearbeite",
      "text" => "Text",
      "today" => "heute",
      "admin" => "Administrator",
      "editor" => "Editor",
      "page" => "Seite",
      "words" => "Wörter",
      "translate" => "übersetzen",
      "everything" => "alles",
      "global" => "globales",
      "change" => "ändern",
      "open" => "öffnen",
      "mounts" => "montiert",
      "autonomous" => "autonome"
    }
  }

  @doc "The default prose blocks, used to seed a fresh session."
  @spec default_blocks() :: [map()]
  def default_blocks, do: @blocks

  @doc "The languages the translator can target (code + label)."
  @spec languages() :: [map()]
  def languages, do: @languages

  @doc "Fetch one block from a working set by id."
  @spec get([map()], String.t()) :: map() | nil
  def get(blocks, id), do: Enum.find(blocks, &(&1.id == id))

  @doc """
  Apply a map of `id => html` overrides (as persisted in the session) onto the
  default blocks. Unknown ids and non-string values are ignored.
  """
  @spec apply_overrides([map()], map()) :: [map()]
  def apply_overrides(blocks, overrides) when is_map(overrides) do
    Enum.map(blocks, fn %{id: id} = block ->
      case Map.fetch(overrides, id) do
        {:ok, html} when is_binary(html) -> %{block | html: html}
        _ -> block
      end
    end)
  end

  def apply_overrides(blocks, _overrides), do: blocks

  @doc "Return a new working set with `id`'s html replaced."
  @spec put_html([map()], String.t(), String.t()) :: [map()]
  def put_html(blocks, id, html) do
    Enum.map(blocks, fn
      %{id: ^id} = b -> %{b | html: html}
      b -> b
    end)
  end

  @doc """
  A deterministic, offline stand-in for an "auto translate" service: swap known
  words for the target language, leaving HTML tags and unknown words untouched.
  Unknown target languages return the text unchanged.
  """
  @spec translate(String.t(), String.t()) :: String.t()
  def translate(html, to) do
    dict = Map.get(@dicts, to, %{})

    Enum.reduce(dict, html, fn {from, into}, acc ->
      Regex.replace(~r/\b#{Regex.escape(from)}\b/, acc, into)
    end)
  end
end
