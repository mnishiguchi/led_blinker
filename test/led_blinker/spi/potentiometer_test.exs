defmodule LedBlinker.SPI.PotentiometerTest do
  use ExUnit.Case

  test "start and stop" do
    {:ok, pid} =
      LedBlinker.SPI.Potentiometer.start_link(%{
        gpio_pin: 12,
        on_scan_fn: fn _ -> nil end
      })

    Process.exit(pid, :kill)
  end
end
