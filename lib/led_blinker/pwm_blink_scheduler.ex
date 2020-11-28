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
      # 1 # 80% of the period
      # 0 # 20% of the period
      # ...

      LedBlinker.PwmBlinkScheduler.change_period(19, 1, 50)
      # 1 # 50% of the period
      # 0 # 50% of the period
      # ...

      LedBlinker.PwmBlinkScheduler.stop(19)
      # :ok

  """

  use GenServer, restart: :temporary
  require Logger

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

  def start_link(%{} = args)
      when is_number(args.gpio_pin) and
             args.frequency in 1..100 and
             args.duty_cycle in 0..100 and
             is_function(args.turn_on_fn) and
             is_function(args.turn_off_fn) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(args.gpio_pin))
  end

  def change_period(gpio_pin, frequency, duty_cycle)
      when frequency in 1..100 and duty_cycle in 0..100 do
    GenServer.call(via_tuple(gpio_pin), {:change_period, frequency, duty_cycle})
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    if whereis(gpio_pin), do: gpio_pin |> via_tuple()|> GenServer.stop()
  end

  @impl true
  def init(%{gpio_pin: gpio_pin, frequency: frequency, duty_cycle: duty_cycle} = args) do
    initial_state = Map.merge(args, calculate_period(frequency, duty_cycle))

    # Do nothing in duty_cycle if zero.
    unless initial_state.duty_cycle == 0, do: send(self(), :turn_on_and_schedule_next)

    Logger.info("#{__MODULE__}.init: #{gpio_pin}")

    {:ok, initial_state}
  end

  @impl true
  def handle_call({:change_period, frequency, duty_cycle}, _from, state) do
    %{gpio_pin: gpio_pin} = state
    new_state = Map.merge(state, calculate_period(frequency, duty_cycle))

    Logger.info("#{__MODULE__}.change_period: #{gpio_pin}")

    {:reply, {:ok, self()}, new_state}
  end

  @impl true
  def handle_info(:turn_on_and_schedule_next, state) do
    %{turn_off_fn: turn_off_fn, turn_on_fn: turn_on_fn, on_time: on_time} = state
    if on_time == 0, do: turn_off_fn.(), else: turn_on_fn.()
    Process.send_after(self(), :turn_off_and_schedule_next, on_time)
    {:noreply, state}
  end

  @impl true
  def handle_info(:turn_off_and_schedule_next, state) do
    %{turn_off_fn: turn_off_fn, period: period, on_time: on_time} = state
    turn_off_fn.()
    off_time = period - on_time
    Process.send_after(self(), :turn_on_and_schedule_next, off_time)
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{gpio_pin: gpio_pin, turn_off_fn: turn_off_fn} = state) do
    Logger.info("#{__MODULE__}.terminate: #{gpio_pin}")

    turn_off_fn.()
    {:noreply, state}
  end

  defp calculate_period(frequency, duty_cycle)
       when frequency in 1..100 and duty_cycle in 0..100 do
    period = round(1 / frequency * 1_000)

    # The on/off time must be of integer type.
    on_time = round(period * (duty_cycle / 100))

    %{
      frequency: frequency,
      duty_cycle: duty_cycle,
      period: period,
      on_time: on_time
    }
  end
end
