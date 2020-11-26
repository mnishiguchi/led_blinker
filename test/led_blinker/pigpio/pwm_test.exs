defmodule LedBlinker.Pigpio.PwmTest do
  use ExUnit.Case, async: true

  test "valid args does not raise a runtime error at least" do
    {:error, _} = LedBlinker.Pigpio.Pwm.call(12, 100, 100)
  end

  test "invalid gpio_pin" do
    [0, "GPIO12"]
    |> Enum.each(fn invalid_gpio_pin ->
      assert_raise FunctionClauseError, fn ->
        LedBlinker.Pigpio.Pwm.call(invalid_gpio_pin, 5000, 100)
      end
    end)
  end

  test "invalid frequency" do
    [0, "100"]
    |> Enum.each(fn invalid_frequency ->
      assert_raise FunctionClauseError, fn ->
        LedBlinker.Pigpio.Pwm.call(12, invalid_frequency, 100)
      end
    end)
  end

  test "invalid duty_cycle" do
    [-1, 101]
    |> Enum.each(fn invalid_duty_cycle ->
      assert_raise FunctionClauseError, fn ->
        LedBlinker.Pigpio.Pwm.call(12, 5000, invalid_duty_cycle)
      end
    end)
  end
end
