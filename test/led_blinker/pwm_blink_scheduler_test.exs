defmodule LedBlinker.PwmBlinkSchedulerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  test "pulse width modulation" do
    run_one_second = fn ->
      {:ok, _pid} =
        LedBlinker.PwmBlinkScheduler.start_link(%{
          gpio_pin: 19,
          frequency: 1,
          duty_cycle: 50,
          turn_on_fn: fn -> IO.puts("1") end,
          turn_off_fn: fn -> IO.puts("0") end
        })

      :timer.sleep(1000)
    end

    assert capture_io(run_one_second) ==
             """
             1
             0
             """
  end
end
