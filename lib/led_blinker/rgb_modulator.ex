defmodule LedBlinker.RgbModulator do
  @moduledoc """
  Repeats changing the PWM state of a given GPIO pin.

  ## Examples

      LedBlinker.RgbModulator.start_link(23)
      LedBlinker.RgbModulator.via_tuple(23) |> GenServer.stop

      gpio_pins = [23, 24, 25]
      gpio_pins |> Enum.map(fn gpio_pins ->
        {:ok, pid} = LedBlinker.RgbModulator.start_link(gpio_pins)
        :timer.apply_after(5000, GenServer, :stop, [pid])
        pid
      end)

  """

  @default_frequency 300
  @default_interval 500

  use GenServer, restart: :temporary

  alias LedBlinker.{LedControllerCache, LedController}

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, gpio_pin)
  end

  def start_link(gpio_pin, options \\ []) when is_number(gpio_pin) and is_list(options) do
    IO.puts("Starting #{__MODULE__}")
    GenServer.start(__MODULE__, {gpio_pin, options}, name: via_tuple(gpio_pin))
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    unless LedBlinker.ProcessRegistry.whereis_via_tuple(via_tuple(gpio_pin)) == :undefined do
      GenServer.stop(via_tuple(gpio_pin))
    end
  end

  @impl true
  def init({gpio_pin, options}) do
    # Initialize later so we can avoid blocking the caller.
    send(self(), {:initialize_state, {gpio_pin, options}})

    send(self(), :tick)

    {:ok, nil}
  end

  @impl true
  def handle_info({:initialize_state, {gpio_pin, options}}, _) do
    {
      :noreply,
      %{
        gpio_pin: gpio_pin,
        # The PWM frequency in Hz.
        frequency: options[:frequency] || @default_frequency,
        # The time span between duty cycle changes.
        interval: options[:interval] || @default_interval,
        #
        scheduler_pid: nil
      }
    }
  end

  # Fire now and schedule next.
  @impl true
  def handle_info(
        :tick,
        %{
          gpio_pin: gpio_pin,
          frequency: frequency,
          interval: interval,
          scheduler_pid: scheduler_pid
        } = state
      ) do
    cleanup_blink_scheduler(scheduler_pid)

    scheduler_pid =
      case LedBlinker.PwmScheduler.start_link(%{
             gpio_pin: gpio_pin,
             frequency: frequency,
             duty_cycle: Enum.random(1..99),
             turn_on_fn: fn -> LedControllerCache.get(gpio_pin) |> LedController.turn_on() end,
             turn_off_fn: fn -> LedControllerCache.get(gpio_pin) |> LedController.turn_off() end
           }) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> pid
      end

    Process.send_after(self(), :tick, interval)

    {:noreply, %{state | scheduler_pid: scheduler_pid}}
  end

  @impl true
  def terminate(_reason, %{scheduler_pid: scheduler_pid} = state) do
    cleanup_blink_scheduler(scheduler_pid)
    {:noreply, state}
  end

  # Stops currently-running scheduler process if any.
  defp cleanup_blink_scheduler(scheduler_pid) do
    if scheduler_pid, do: GenServer.stop(scheduler_pid)
  end
end
