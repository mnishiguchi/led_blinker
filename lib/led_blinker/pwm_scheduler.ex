defmodule LedBlinker.PwmScheduler do
  @moduledoc """
  Repeats the specified cycle.

  Examples:

      {:ok, pid} =
        LedBlinker.PwmScheduler.start_link(%{
          gpio_pin: 19,
          frequency: 5000,
          duty_cycle: 80,
          turn_on_fn: fn -> IO.puts("1") end,
          turn_off_fn: fn -> IO.puts("0") end
        })
      # 1 # 80% of the period
      # 0 # 20% of the period
      # 1
      # ...
      LedBlinker.PwmScheduler.stop(pid)
      # :ok

  """

  use GenServer

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, gpio_pin)
  end

  def start_link(
        %{
          gpio_pin: gpio_pin,
          frequency: frequency,
          duty_cycle: duty_cycle,
          turn_on_fn: turn_on_fn,
          turn_off_fn: turn_off_fn
        } = args
      )
      when is_number(gpio_pin) and
             frequency in 200..50_000 and
             duty_cycle in 0..100 and
             is_function(turn_on_fn) and
             is_function(turn_off_fn) do
    IO.puts("Starting #{__MODULE__}:#{gpio_pin}:#{frequency}Hz:#{duty_cycle}%")

    GenServer.start_link(__MODULE__, args, name: via_tuple(gpio_pin))
  end

  @impl true
  def init(
        %{
          frequency: frequency,
          duty_cycle: duty_cycle,
          turn_on_fn: turn_on_fn,
          turn_off_fn: turn_off_fn
        } = args
      ) do
    period = hz_to_period(frequency)
    on_time = round(period * (duty_cycle / 100))
    off_time = period - on_time

    # Determine initial action. Do not generate pulse when on/off time is 0.
    cond do
      on_time == 0 -> turn_off_fn.()
      off_time == 0 -> turn_on_fn.()
      true -> send(self(), :turn_on)
    end

    {:ok, Map.merge(args, %{period: period, on_time: on_time, off_time: off_time})}
  end

  # Fire now and schedule next.
  @impl true
  def handle_info(:turn_on, %{turn_on_fn: turn_on_fn, on_time: on_time} = state) do
    turn_on_fn.()
    Process.send_after(self(), :turn_off, on_time)
    {:noreply, state}
  end

  @impl true
  def handle_info(:turn_off, %{turn_off_fn: turn_off_fn, off_time: off_time} = state) do
    turn_off_fn.()
    Process.send_after(self(), :turn_on, off_time)
    {:noreply, state}
  end

  # Converts frequency (Hz) to period in milliseconds.
  defp hz_to_period(hz) when is_number(hz), do: round(hz / 10)
end
