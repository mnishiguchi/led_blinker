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

  def stop(gpio_pin) do
    LedControllerCache.get(gpio_pin) |> LedController.stop()
  end
end
