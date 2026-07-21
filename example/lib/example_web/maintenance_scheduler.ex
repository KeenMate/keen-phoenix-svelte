defmodule ExampleWeb.MaintenanceScheduler do
  @moduledoc """
  Periodically resets the demo's in-memory chat state (every 15 minutes) so the
  public demo doesn't accumulate messages (or spam) indefinitely. Self-scheduling
  `GenServer` — no external cron. The same reset is available on demand via
  `/api/maintenance/reset`.
  """
  use GenServer
  require Logger

  alias ExampleWeb.Maintenance

  @interval :timer.minutes(15)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  @impl true
  def init(:ok) do
    schedule()
    {:ok, nil}
  end

  @impl true
  def handle_info(:reset, state) do
    Logger.info("Resetting demo chat state (scheduled every #{div(@interval, 60_000)}m)")
    Maintenance.reset_chat()
    schedule()
    {:noreply, state}
  end

  defp schedule, do: Process.send_after(self(), :reset, @interval)
end
