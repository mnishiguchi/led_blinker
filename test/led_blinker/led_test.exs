defmodule LedBlinker.LedTest do
  use ExUnit.Case

  alias LedBlinker.Led

  setup do
    gpio_pin = 20
    gpio_ref = Led.gpio_ref(gpio_pin)
    {:ok, gpio_ref: gpio_ref}
  end

  test "switching on and off", %{gpio_ref: gpio_ref} do
    Led.turn_on(gpio_ref)
    :timer.sleep(1)
    assert Led.on?(gpio_ref)

    Led.turn_off(gpio_ref)
    :timer.sleep(1)
    assert Led.off?(gpio_ref)

    Led.turn_on(gpio_ref)
    :timer.sleep(1)
    assert Led.on?(gpio_ref)
  end
end
