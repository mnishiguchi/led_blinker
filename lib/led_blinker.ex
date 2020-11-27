defmodule LedBlinker do
  @moduledoc """
  A collection of convenience functions for using this system.

  ## Examples

      LedBlinker.turn_on(12)
      LedBlinker.turn_off(12)
      LedBlinker.toggle(12)

      LedBlinker.blink(12)
      LedBlinker.stop_blink(12)

      LedBlinker.brightness(12, 80)

  """

  alias LedBlinker.{LedControllerCache, LedController}

  def turn_on(gpio_pin) do
    gpio_pin |> LedControllerCache.get() |> LedController.turn_on()
  end

  def turn_off(gpio_pin) do
    gpio_pin |> LedControllerCache.get() |> LedController.turn_off()
  end

  def toggle(gpio_pin) do
    gpio_pin |> LedControllerCache.get() |> LedController.toggle()
  end

  def blink(gpio_pin, frequency \\ 1, duty_cycle \\ 50) do
    if LedBlinker.PwmBlinkScheduler.whereis(gpio_pin) do
      {:ok, _pid} = LedBlinker.PwmBlinkScheduler.change_period(gpio_pin, frequency, duty_cycle)
    else
      {:ok, _pid} =
        LedBlinker.BlinkSupervisor.start_child(%{
          gpio_pin: gpio_pin,
          frequency: frequency,
          duty_cycle: duty_cycle,
          # Do not omit the module since the lambdas are called outside this module.
          turn_on_fn: fn -> LedBlinker.turn_on(gpio_pin) end,
          turn_off_fn: fn -> LedBlinker.turn_off(gpio_pin) end
        })
    end
  end

  def stop_blink(gpio_pin) do
    LedBlinker.PwmBlinkScheduler.stop(gpio_pin)
    turn_off(gpio_pin)
  end

  def brightness(gpio_pin, percentage) do
    # 100Hz (period duration: ~10ms) is fast enough.
    blink(gpio_pin, 100, percentage)
  end
end
