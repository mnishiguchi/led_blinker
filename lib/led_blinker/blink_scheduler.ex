defmodule LedBlinker.BlinkScheduler do
  @moduledoc """
  Repeats running the specified function with the specified interval.

  ## Examples

      {:ok, pid} = LedBlinker.BlinkScheduler.start_link(%{
        gpio_pin: 19,
        interval: 500,
        blink_fn: fn -> IO.puts("Hello") end
      })
      # Hello
      # Hello
      # Hello
      # ...
      LedBlinker.BlinkScheduler.stop(pid)
      # :ok

  """

  use GenServer, restart: :temporary

  # Used as a unique process name when being registered to the process registry.
  defp via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, gpio_pin)
  end

  def start_link(%{gpio_pin: gpio_pin, interval: interval, blink_fn: blink_fn})
      when is_number(gpio_pin) and is_number(interval) and is_function(blink_fn) do
    GenServer.start_link(
      __MODULE__,
      %{gpio_pin: gpio_pin, interval: interval, blink_fn: blink_fn},
      name: via_tuple(gpio_pin)
    )
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    unless LedBlinker.ProcessRegistry.whereis_via_tuple(via_tuple(gpio_pin)) == :undefined do
      GenServer.stop(via_tuple(gpio_pin))
    end
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
