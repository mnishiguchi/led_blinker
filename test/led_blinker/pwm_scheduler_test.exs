defmodule LedBlinker.Gpio.PwmTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "pulse width modulation" do
    assert capture_io(fn -> run_scheduler() end) == """
           1
           0
           1
           0
           1
           0
           1
           0
           """
  end

  defp run_scheduler() do
    {:ok, _pid} =
      LedBlinker.PwmScheduler.start_link(%{
        gpio_pin: 19,
        frequency: 5000,
        duty_cycle: 80,
        turn_on_fn: fn -> IO.puts("1") end,
        turn_off_fn: fn -> IO.puts("0") end
      })

    :timer.sleep(2000)
  end
end
