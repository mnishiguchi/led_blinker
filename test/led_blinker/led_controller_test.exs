defmodule LedBlinker.LedControllerTest do
  use ExUnit.Case

  alias LedBlinker.{LedControllerCache,LedController}

  setup do
    gpio_pin = 20
    pid = LedControllerCache.get(gpio_pin)
    {:ok, pid: pid}
  end

  test "switching on and off", %{pid: pid} do
    LedController.turn_on(pid)
    assert LedController.on?(pid)
    refute LedController.off?(pid)

    LedController.turn_off(pid)
    assert LedController.off?(pid)

    LedController.turn_on(pid)
    assert LedController.on?(pid)
  end

  test "toggle", %{pid: pid} do
    LedController.turn_on(pid)
    LedController.toggle(pid)
    assert LedController.off?(pid)

    LedController.toggle(pid)
    assert LedController.on?(pid)
  end

  test "blinking", %{pid: pid} do
    # Initially ON.
    LedController.turn_on(pid)

    # Start blinking.
    LedController.blink(pid, 500)

    # This is a magic number to simulate latency.
    :timer.sleep(600)

    assert LedController.off?(pid)
    :timer.sleep(500)
    assert LedController.on?(pid)
    :timer.sleep(500)
    assert LedController.off?(pid)
  end
end
