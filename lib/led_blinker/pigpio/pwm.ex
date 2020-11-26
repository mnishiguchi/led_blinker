defmodule LedBlinker.Pigpio.Pwm do
  @moduledoc """
  A thin wrapper of Pigpiox.Pwm. Implements LedBlinker.Pwm behaviour. There is a
  side effect of starting the PWM on the GPIO pin.
  """

  @behaviour LedBlinker.Pwm

  @doc """
  Perform the PWM on a specified pin.

  ## Examples

      LedBlinker.Pigpio.Pwm.call(12, 50, 50)

  """
  @impl LedBlinker.Pwm
  def call(gpio_pin, frequency, duty_cycle)
      when gpio_pin in 1..100 and frequency in 1..100 and duty_cycle in 0..100 do
    # Pigpiox works only on the target device.
    case Code.ensure_compiled(Pigpiox.Pwm) do
      {:module, module} ->
        # Pigpiox.Pwm.hardware_pwm's max duty_cycle is `1_000_000`
        # For some reason, frequency does not do anything.
        module.hardware_pwm(gpio_pin, frequency, duty_cycle * 10_000)

      {:error, _} ->
        # Explain it but not raise an runtime error.
        {:error, "Pigpiox is available only on target devices"}
    end
  end
end
