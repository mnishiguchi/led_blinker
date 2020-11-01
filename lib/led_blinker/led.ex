defmodule LedBlinker.Led do
  @moduledoc """
  A collection of helper functions to manipulate LEDs. Built with Circuits.GPIO
  functions. https://github.com/elixir-circuits/circuits_gpio#gpio
  """

  @gpio_on 1
  @gpio_off 0

  @doc """
  Returns a reference to a given GPIO pin.

  ## Examples

      Led.gpio_ref(20)
      # #Reference<0.1277966640.803078163.183293>

  """
  def gpio_ref(gpio_pin) do
    IO.puts("Obtaining the LED ref for #{gpio_pin}")

    {:ok, gpio_ref} = Circuits.GPIO.open(gpio_pin, :output)
    gpio_ref
  end

  @doc """
  Returns true is the LED is currently switched on; else false.

  ## Examples

      Led.gpio_ref(20) |> Led.on?
      # false

  """
  def on?(gpio_ref) when is_reference(gpio_ref) do
    Task.async(fn ->
      IO.puts("Checking the LED state")

      case Circuits.GPIO.read(gpio_ref) do
        @gpio_on -> true
        @gpio_off -> false
      end
    end)
    |> Task.await()
  end

  def off?(gpio_ref), do: !on?(gpio_ref)

  @doc """
  Turns on the LED for a given GPIO ref

  ## Examples

      Led.gpio_ref(20) |> Led.turn_on
      # {:ok, #PID<0.236.0>}

  """
  def turn_on(gpio_ref) when is_reference(gpio_ref) do
    Task.start_link(fn ->
      IO.puts("Turning on the LED async")
      Circuits.GPIO.write(gpio_ref, @gpio_on)
    end)
  end

  @doc """
  Turns off the LED for a given GPIO ref

  ## Examples

      Led.gpio_ref(20) |> Led.turn_off
      # {:ok, #PID<0.240.0>}

  """
  def turn_off(gpio_ref) when is_reference(gpio_ref) do
    Task.start_link(fn ->
      IO.puts("Turning off the LED async")
      Circuits.GPIO.write(gpio_ref, @gpio_off)
    end)
  end
end
