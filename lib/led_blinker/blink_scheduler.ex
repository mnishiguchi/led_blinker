defmodule LedBlinker.BlinkScheduler do
  @moduledoc """
  Repeats running the specified function with the specified interval.

  Examples:

      {:ok, pid} = LedBlinker.BlinkScheduler.start_link([500, fn -> IO.puts("Hello") end])
      # Hello
      # Hello
      # Hello
      # ...
      LedBlinker.BlinkScheduler.stop(pid)
      # :ok

  """

  use GenServer

  # Used as a unique process name when being registered to the process registry.
  defp via_tuple(blink_fn) when is_function(blink_fn) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, blink_fn)
  end

  def start_link([interval, blink_fn]) when is_number(interval) and is_function(blink_fn) do
    IO.puts("Starting #{__MODULE__}")

    GenServer.start_link(
      __MODULE__,
      %{interval: interval, blink_fn: blink_fn},
      name: via_tuple(blink_fn)
    )
  end

  @impl true
  def init(initial_state) do
    send(self(), :tick)
    {:ok, initial_state}
  end

  # Fire now and schedule next.
  @impl true
  def handle_info(:tick, %{interval: interval, blink_fn: blink_fn} = state) do
    blink_fn.()
    Process.send_after(self(), :tick, interval)
    {:noreply, state}
  end
end
