defmodule KeenPhoenixSvelte.Application do
  @moduledoc false
  # Starts the (optional) proxy machinery: a Task.Supervisor for upstream
  # fetches and the single-flight ProxyCache. Both are idle unless the app proxy
  # (`KeenPhoenixSvelte.Apps.Proxy`) is actually mounted and hit.
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # `max_children` caps concurrent upstream fetches so a flood of distinct
      # sub-paths can't spawn unbounded tasks/sockets (the GenServer refuses new
      # fetches at the same ceiling and serves stale / 503 instead).
      {Task.Supervisor,
       name: KeenPhoenixSvelte.Apps.ProxyTaskSupervisor,
       max_children: KeenPhoenixSvelte.Apps.ProxyCache.max_concurrent_fetches()},
      KeenPhoenixSvelte.Apps.ProxyCache
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: KeenPhoenixSvelte.Supervisor)
  end
end
