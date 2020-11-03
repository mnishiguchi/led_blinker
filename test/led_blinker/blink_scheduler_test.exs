defmodule LedBlinker.BlinkSchedulerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias LedBlinker.BlinkScheduler

  test "blinking" do
    assert capture_io(fn -> run_scheduler(2000) end) == """
           Starting Elixir.LedBlinker.BlinkScheduler
           Hello
           Hello
           Hello
           """
  end

  defp run_scheduler(milli_seconds) do
    BlinkScheduler.start_link({500, fn -> IO.puts("Hello") end})
    :timer.sleep(milli_seconds)
  end
end
