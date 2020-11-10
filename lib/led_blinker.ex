defmodule LedBlinker do
  @moduledoc """
  A collection of convenience functions for using this system.

  ## Examples

      LedBlinker.turn_on(20)
      LedBlinker.turn_off(20)
      LedBlinker.toggle(20)
      LedBlinker.blink(20, 1000)
      LedBlinker.stop(20)
      LedBlinker.pwm(20, frequency: 5000, duty_cycle: 80)
      LedBlinker.stop(20)
      LedBlinker.rgb_modulation([23, 24, 25])

  """

  alias LedBlinker.{LedControllerCache, LedController}

  def turn_on(gpio_pin) do
    LedControllerCache.get(gpio_pin) |> LedController.turn_on()
  end

  def turn_off(gpio_pin) do
    LedControllerCache.get(gpio_pin) |> LedController.turn_off()
  end

  def toggle(gpio_pin) do
    LedControllerCache.get(gpio_pin) |> LedController.toggle()
  end

  def blink(gpio_pin, interval \\ 500) do
    LedControllerCache.get(gpio_pin) |> LedController.blink(interval)
  end

  def pwm(gpio_pin, frequency: frequency, duty_cycle: duty_cycle) do
    LedControllerCache.get(gpio_pin)
    |> LedController.pwm(frequency: frequency, duty_cycle: duty_cycle)
  end

  def rgb_modulation(gpio_pins, options \\ []) when is_list(gpio_pins) do
    duration = options[:duration] || 5000
    gpio_pins |> Enum.each(fn gpio_pins ->
      {:ok, pid} = LedBlinker.Rgb.Modulator.start_link(gpio_pins)
      :timer.apply_after(duration, GenServer, :stop, [pid])
      pid
    end)
  end

  def stop(gpio_pin)  when is_number(gpio_pin) do
    LedControllerCache.get(gpio_pin) |> LedController.stop()
  end

  def stop(gpio_pins) when is_list(gpio_pins) do
    Enum.each(gpio_pins, &(stop(&1)))
  end
end
