defmodule LedBlinker.PwmSchedulerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias LedBlinker.PwmScheduler

  test "pulse width modulation" do
    assert capture_io(fn -> run_scheduler() end) == """
           Starting Elixir.LedBlinker.PwmScheduler:5000Hz:80%
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
      PwmScheduler.start_link(%{
        frequency: 5000,
        duty_cycle: 80,
        turn_on_fn: fn -> IO.puts("1") end,
        turn_off_fn: fn -> IO.puts("0") end
      })

    :timer.sleep(2000)
  end
end
