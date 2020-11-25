defmodule LedBlinker.FrequencyTest do
  use ExUnit.Case

  LedBlinker.Frequency

  test "to_period_duration converts Hz to period in milliseconds" do
    [
      {1, 1000},
      {2, 500},
      {3, 333},
      {11, 91},
      {22, 45},
      {33, 30},
      {44, 23},
      {55, 18},
      {66, 15},
      {77, 13},
      {88, 11},
      {99, 10}
    ]
    |> Enum.each(fn {hz, ms} ->
      assert LedBlinker.Frequency.to_period_duration(hz) == ms
    end)
  end
end
