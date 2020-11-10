defmodule LedBlinker.Rgb.Modulator do
  @moduledoc """
  Repeats changing the PWM state of a given GPIO pin.

  Examples:

      LedBlinker.Rgb.Modulator.start_link(23)
      LedBlinker.Rgb.Modulator.via_tuple(23) |> GenServer.stop

      gpio_pins = [23, 24, 25]
      gpio_pins |> Enum.map(fn gpio_pins ->
        {:ok, pid} = LedBlinker.Rgb.Modulator.start_link(gpio_pins)
        :timer.apply_after(5000, GenServer, :stop, [pid])
        pid
      end)

  """

  @duty_step_allowlist [2, 5, 10, 20, 25]
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

  @impl true
  @spec init({any, any}) :: {:ok, nil}
  def init({gpio_pin, options}) do
    # Initialize later so we can avoid blocking the caller.
    send(self(), {:initialize_state, {gpio_pin, options}})

    send(self(), :tick)

    {:ok, nil}
  end

  @impl true
  def handle_info({:initialize_state, {gpio_pin, options}}, _) do
    led_controller = LedControllerCache.get(gpio_pin)
    parsed_options = %{frequency: frequency} = parse_options(options)

    {
      :noreply,
      parsed_options
      |> Map.merge(%{
        pmw_fn: fn duty_cycle ->
          LedController.pwm(led_controller, frequency: frequency, duty_cycle: duty_cycle)
        end
      })
    }
  end

  # Fire now and schedule next.
  @impl true
  def handle_info(:tick, state) do
    %{pmw_fn: pmw_fn, interval: interval, duty_step: duty_step} = state

    for duty_cycle <- Enum.filter(1..100, &(rem(&1, duty_step) == 0)) do
      pmw_fn.(duty_cycle)
      :timer.sleep(interval)
    end

    for duty_cycle <- Enum.filter(99..0, &(rem(&1, duty_step) == 0)) do
      pmw_fn.(duty_cycle)
      :timer.sleep(interval)
    end

    Process.send_after(self(), :tick, interval)

    {:noreply, state}
  end

  defp parse_options(options) when is_list(options) do
    %{
      # The PWM frequency in Hz.
      frequency: options[:frequency] || @default_frequency,
      # The percentage points by which the duty cycle increments and decrements.
      # Random mode if the value is 0 or less.
      # if duty step is 0 or less, randomly select one.
      duty_step:
        cond do
          options[:duty_step] in @duty_step_allowlist -> options[:duty_step]
          true -> Enum.take_random(@duty_step_allowlist, 1) |> hd
        end,
      # The time span between duty cycle changes.
      interval: options[:interval] || @default_interval
    }
  end
end
