defmodule LedBlinker.Led do
  @moduledoc """
  A collection of helper functions to manipulate LEDs.
  """

  @doc """
  Returns true is the LED is currently switched on; else false.
  """
  def on?(gpio_pin) when is_number(gpio_pin) do
    # TODO: Implement
    Task.async(fn ->
      IO.puts("Checking the LED state")
    end)
    |> Task.await()

    false
  end

  def turn_on(gpio_pin) when is_number(gpio_pin) do
    # TODO: Implement
    Task.start_link(fn ->
      IO.puts("Turning on the LED async")
    end)
  end

  def turn_off(gpio_pin) when is_number(gpio_pin) do
    # TODO: Implement
    Task.start_link(fn ->
      IO.puts("Turning off the LED async")
    end)
  end
end
