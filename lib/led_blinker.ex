defmodule LedBlinker do
  @moduledoc """
  A collection of convenience functions for using this system.

  ## Examples

      LedBlinker.turn_on(20)
      LedBlinker.turn_off(20)
      LedBlinker.toggle(20)

      LedBlinker.blink(20, 1000)
      LedBlinker.stop_blink(20)

      LedBlinker.pwm(20, frequency: 5000, duty_cycle: 80)
      LedBlinker.stop_pwm(20)

      LedBlinker.rgb_modulation([23, 24, 25])
      LedBlinker.stop_rgb_modulation([23, 24, 25])

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

  def blink(gpio_pin, interval \\ 500) do
    case LedBlinker.BlinkScheduler.whereis(gpio_pin) do
      nil ->
        LedBlinker.BlinkScheduler.start_link(%{
          gpio_pin: gpio_pin,
          interval: interval,
          blink_fn: fn -> gpio_pin |> LedControllerCache.get() |> LedController.toggle() end
        })

      pid ->
        GenServer.stop(pid)
        blink(gpio_pin, interval)
    end
  end

  def stop_blink(gpio_pin) do
    LedBlinker.BlinkScheduler.stop(gpio_pin)
    turn_off(gpio_pin)
  end

  def pwm(gpio_pin, frequency: frequency, duty_cycle: duty_cycle) do
    case LedBlinker.PwmScheduler.whereis(gpio_pin) do
      nil ->
        LedBlinker.PwmScheduler.start_link(%{
          gpio_pin: gpio_pin,
          frequency: frequency,
          duty_cycle: duty_cycle,
          turn_on_fn: fn -> gpio_pin |> LedControllerCache.get() |> LedController.turn_on() end,
          turn_off_fn: fn -> gpio_pin |> LedControllerCache.get() |> LedController.turn_off() end
        })

      pid ->
        GenServer.stop(pid)
        pwm(gpio_pin, frequency: frequency, duty_cycle: duty_cycle)
    end
  end

  def stop_pwm(gpio_pin) do
    LedBlinker.PwmScheduler.stop(gpio_pin)
    turn_off(gpio_pin)
  end

  def rgb_modulation(gpio_pins, options \\ []) when is_list(gpio_pins) do
    duration = options[:duration] || 5000

    Enum.map(gpio_pins, fn gpio_pin ->
      Task.start_link(fn ->
        case LedBlinker.RgbModulator.whereis(gpio_pin) do
          nil ->
            LedBlinker.RgbModulator.start_link(gpio_pin)
            :timer.apply_after(duration, LedBlinker.RgbModulator, :stop, [gpio_pin])

          pid ->
            GenServer.stop(pid)
            rgb_modulation(gpio_pins, options)
        end
      end)
    end)
  end

  def stop_rgb_modulation(gpio_pins) when is_list(gpio_pins) do
    Enum.map(gpio_pins, fn gpio_pin ->
      Task.start_link(fn ->
        LedBlinker.RgbModulator.stop(gpio_pin)
        turn_off(gpio_pin)
      end)
    end)
  end
end
