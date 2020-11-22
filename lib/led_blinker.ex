defmodule LedBlinker do
  @moduledoc """
  A collection of convenience functions for using this system.

  ## Examples

      LedBlinker.turn_on(12)
      LedBlinker.turn_off(12)
      LedBlinker.toggle(12)

      LedBlinker.blink(12, 1000)
      LedBlinker.stop_blink(12)

      LedBlinker.pwm(12, 80)
      LedBlinker.stop_pwm(12)

      [12, 13, 19] |> Enum.shuffle |> Enum.map(fn gpio_pin ->
        Task.start_link(fn ->
          Enum.to_list(1..100) ++ Enum.to_list(99..0)
          |> Enum.each fn level -> LedBlinker.pwm(gpio_pin, level); :timer.sleep(10) end
        end)
        :timer.sleep(2000)
      end)

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

  def pwm(gpio_pin, percentage) do
    LedBlinker.Pigpio.Pwm.call(gpio_pin, 800, percentage)
  end

  def stop_pwm(gpio_pin) do
    LedBlinker.Pigpio.Pwm.call(gpio_pin, 800, 0)
  end
end
