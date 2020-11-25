defmodule LedBlinker.PwmBlinkScheduler do
  @moduledoc """
  Repeats the specified cycle for blinking LEDs. For faster PWM, please consider
  using better alternatives.

  ## Examples

      {:ok, pid} =
        LedBlinker.PwmBlinkScheduler.start_link(%{
          gpio_pin: 19,
          frequency: 1,
          duty_cycle: 80,
          turn_on_fn: fn -> IO.puts("1") end,
          turn_off_fn: fn -> IO.puts("0") end
        })
      # 1 # 80% of the period_duration
      # 0 # 20% of the period_duration
      # 1
      # ...
      LedBlinker.Gpio.Pwm.stop(pid)
      # :ok

  """

  use GenServer, restart: :temporary

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple({__MODULE__, gpio_pin})
  end

  def whereis(gpio_pin) when is_number(gpio_pin) do
    case LedBlinker.ProcessRegistry.whereis_name({__MODULE__, gpio_pin}) do
      :undefined -> nil
      pid -> pid
    end
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
             frequency in 1..100 and
             duty_cycle in 0..100 and
             is_function(turn_on_fn) and
             is_function(turn_off_fn) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(gpio_pin))
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    if whereis(gpio_pin), do: GenServer.stop(via_tuple(gpio_pin))
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
    period_duration = hz_to_period_duration_in_milliseconds(frequency)
    on_time = round(period_duration * (duty_cycle / 100))
    off_time = period_duration - on_time

    # Determine initial action. Do not generate pulse when on/off time is 0.
    cond do
      frequency == 0 -> turn_off_fn.()
      on_time == 0 -> turn_off_fn.()
      off_time == 0 -> turn_on_fn.()
      true -> send(self(), :turn_on)
    end

    {:ok,
     Map.merge(args, %{period_duration: period_duration, on_time: on_time, off_time: off_time})}
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

  @impl true
  def terminate(_reason, %{turn_off_fn: turn_off_fn} = state) do
    turn_off_fn.()
    {:noreply, state}
  end

  # Converts frequency (Hz) to period_duration in milliseconds.
  defp hz_to_period_duration_in_milliseconds(hz) when is_number(hz) do
    LedBlinker.Frequency.to_period_duration(hz)
  end
end
