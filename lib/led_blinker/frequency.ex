defmodule LedBlinker.Frequency do
  @doc """
  Converts Hz to period in milliseconds.
  """
  def to_period_duration(hz) do
    # Hz = cycle count / second
    # second = cycle count / Hz
    round(1 / hz * 1_000)
  end
end
