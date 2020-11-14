defmodule LedBlinker.BlinkSchedulerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias LedBlinker.BlinkScheduler

  test "blinking" do
    assert capture_io(fn -> run_scheduler() end) == """
           Starting Elixir.LedBlinker.BlinkScheduler
           Hello
           Hello
           Hello
           Hello
           """
  end

  defp run_scheduler() do
    BlinkScheduler.start_link(%{
      gpio_pin: 20,
      interval: 500,
      blink_fn: fn -> IO.puts("Hello") end
    })

    :timer.sleep(2000)
  end
end
