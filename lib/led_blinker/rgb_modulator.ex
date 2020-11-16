defmodule LedBlinker.RgbModulator do
  @moduledoc """
  Repeats changing the PWM state of a given GPIO pin.

  ## Examples

      LedBlinker.RgbModulator.start_link(23)
      LedBlinker.RgbModulator.via_tuple(23) |> GenServer.stop

  """

  @default_frequency 300
  @default_interval 500

  use GenServer, restart: :temporary

  alias LedBlinker.{ProcessRegistry, LedControllerCache, LedController, PwmScheduler}

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    ProcessRegistry.via_tuple({__MODULE__, gpio_pin})
  end

  def whereis(gpio_pin) when is_number(gpio_pin) do
    case LedBlinker.ProcessRegistry.whereis_name({__MODULE__, gpio_pin}) do
      :undefined -> nil
      pid -> pid
    end
  end

  def start_link(gpio_pin, options \\ []) when is_number(gpio_pin) and is_list(options) do
    GenServer.start(__MODULE__, {gpio_pin, options}, name: via_tuple(gpio_pin))
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    if whereis(gpio_pin), do: GenServer.stop(via_tuple(gpio_pin))
  end

  @impl true
  def init({gpio_pin, options}) do
    send(self(), :tick)

    {:ok,
     %{
       gpio_pin: gpio_pin,
       # The PWM frequency in Hz.
       frequency: options[:frequency] || @default_frequency,
       # The time span between duty cycle changes.
       interval: options[:interval] || @default_interval
     }}
  end

  # Fire now and schedule next.
  @impl true
  def handle_info(
        :tick,
        %{
          gpio_pin: gpio_pin,
          frequency: frequency,
          interval: interval
        } = state
      ) do
    # Stop if already running so that we can restart with new options.
    PwmScheduler.stop(gpio_pin)

    PwmScheduler.start_link(%{
      gpio_pin: gpio_pin,
      frequency: frequency,
      duty_cycle: Enum.random(1..99),
      turn_on_fn: fn -> LedControllerCache.get(gpio_pin) |> LedController.turn_on() end,
      turn_off_fn: fn -> LedControllerCache.get(gpio_pin) |> LedController.turn_off() end
    })

    Process.send_after(self(), :tick, interval)

    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{gpio_pin: gpio_pin} = state) do
    # Do not forget to stop up the currently running PWM scheduler.
    PwmScheduler.stop(gpio_pin)
    {:noreply, state}
  end
end
