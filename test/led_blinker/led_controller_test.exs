defmodule LedBlinker.LedControllerTest do
  use ExUnit.Case

  alias LedBlinker.LedController

  test "switching on and off" do
    {:ok, pid} = LedController.start_link(-1)

    LedController.turn_on(pid)
    assert LedController.on?(pid) == true
    assert LedController.off?(pid) == false

    LedController.turn_off(pid)
    assert LedController.off?(pid)

    LedController.turn_on(pid)
    assert LedController.on?(pid)
  end

  test "toggle" do
    {:ok, pid} = LedController.start_link(-1)

    LedController.turn_on(pid)
    LedController.toggle(pid)
    assert LedController.off?(pid)

    LedController.toggle(pid)
    assert LedController.on?(pid)
  end

  test "blinking" do
    {:ok, pid} = LedController.start_link(-1)
    LedController.turn_on(pid)
    assert LedController.on?(pid)

    LedController.blink(pid, 500)
    :timer.sleep(499)
    assert LedController.off?(pid)
    :timer.sleep(500)
    assert LedController.on?(pid)
    :timer.sleep(500)
    assert LedController.off?(pid)
  end
end
