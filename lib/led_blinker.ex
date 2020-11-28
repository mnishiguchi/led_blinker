defmodule LedBlinker do
  @moduledoc """
  A collection of convenience functions for using this system.

  ## Examples

      LedBlinker.turn_on(12)
      LedBlinker.turn_off(12)
      LedBlinker.toggle(12)

      LedBlinker.blink(12)

      LedBlinker.brightness(12, 80)

      LedBlinker.potentiometer(12)

  """

  require Logger
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
    LedBlinker.Pigpio.Pwm.call(gpio_pin, frequency, duty_cycle)
  end

  def stop_blink(gpio_pin) do
    LedBlinker.Pigpio.Pwm.call(gpio_pin, 1, 0)
  end

  def brightness(gpio_pin, percentage) when percentage in 0..100 do
    # 100Hz (period duration: ~10ms) is fast enough.
    LedBlinker.Pigpio.Pwm.call(gpio_pin, 100, percentage)
  end

  def potentiometer(gpio_pin) do
    unless LedBlinker.SPI.Potentiometer.whereis(gpio_pin) do
      {:ok, _pid} =
        LedBlinker.SPI.PotentiometerSupervisor.start_child(%{
          gpio_pin: gpio_pin,
          on_scan_fn: fn percentage ->
            Logger.info("#{round(percentage)}")

            # Error handling
            LedBlinker.Pigpio.Pwm.call(gpio_pin, 100, round(percentage))
          end
        })
    end
  end

  def stop_potentiometer(gpio_pin) do
    LedBlinker.SPI.Potentiometer.stop(gpio_pin)
  end
end
