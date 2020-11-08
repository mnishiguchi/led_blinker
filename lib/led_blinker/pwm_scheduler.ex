defmodule LedBlinker.PwmScheduler do
  @moduledoc """
  Repeats the specified cycle.

  Examples:

      {:ok, pid} =
        LedBlinker.PwmScheduler.start_link(%{
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
  defp via_tuple(frequency, duty_cycle) when is_number(frequency) when is_number(duty_cycle) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, {frequency, duty_cycle})
  end

  def start_link(%{} = args)
      when args.frequency in 100..50_000
      when args.duty_cycle in 0..100
      when is_function(args.turn_on_fn)
      when is_function(args.turn_off_fn) do
    IO.puts("Starting #{__MODULE__}:#{args.frequency}Hz:#{args.duty_cycle}%")

    GenServer.start_link(
      __MODULE__,
      args,
      name: via_tuple(args.frequency, args.duty_cycle)
    )
  end

  def stop(pid) when is_pid(pid), do: GenServer.stop(pid)

  @impl true
  def init(%{} = args) do
    send(self(), :turn_on)
    period = hz_to_period(args.frequency)
    on_time = round(period * (args.duty_cycle / 100))
    off_time = period - on_time
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
