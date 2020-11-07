defmodule LedBlinker.Utils do
  @doc """
  Converts Hz to period in milliseconds.
  """
  def period_duration_from_hz(hz) do
    # Hz = cycle count / second
    # second = cycle count / Hz
    round(1 / hz * 1_000)
  end

  @doc """
  ## Examples

      percentage_from_ten_bit(123)  #=> 12.023460410557185
      percentage_from_ten_bit(1023) #=> 100

  """
  def percentage_from_ten_bit(value) when value in 0..1023 do
    map_value_in_range(value, {0, 1023}, {0, 100})
  end

  @doc """
  ## Examples

      map_value_in_range(65, {0, 255}, {0, 100}) #=> 25.49019607843137

  """
  def map_value_in_range(x, {in_min, in_max}, {out_min, out_max})
      when is_number(x) and in_min < in_max and out_min < out_max do
    (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
  end
end
