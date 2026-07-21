defmodule KeenPhoenixSvelte.Application do
  @moduledoc false
  # Starts the (optional) proxy machinery: a Task.Supervisor for upstream
  # fetches and the single-flight ProxyCache. Both are idle unless the app proxy
  # (`KeenPhoenixSvelte.Apps.Proxy`) is actually mounted and hit.
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: KeenPhoenixSvelte.Apps.ProxyTaskSupervisor},
      KeenPhoenixSvelte.Apps.ProxyCache
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: KeenPhoenixSvelte.Supervisor)
  end
end
