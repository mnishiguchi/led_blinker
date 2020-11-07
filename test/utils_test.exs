defmodule LedBlinker.UtilsTest do
  use ExUnit.Case, async: true

  import LedBlinker.Utils

  test "period_duration_from_hz converts Hz to period in milliseconds" do
    assert period_duration_from_hz(1) == 1000
    assert period_duration_from_hz(2) == 500
    assert period_duration_from_hz(3) == 333
    assert period_duration_from_hz(11) == 91
    assert period_duration_from_hz(22) == 45
    assert period_duration_from_hz(33) == 30
    assert period_duration_from_hz(44) == 23
    assert period_duration_from_hz(55) == 18
    assert period_duration_from_hz(66) == 15
    assert period_duration_from_hz(77) == 13
    assert period_duration_from_hz(88) == 11
    assert period_duration_from_hz(99) == 10
  end

  test "percentage_from_ten_bit" do
    assert percentage_from_ten_bit(1) == 0.09775171065493646
    assert percentage_from_ten_bit(123) == 12.023460410557185
    assert percentage_from_ten_bit(1023) == 100
  end

  test "map_value_in_range" do
    assert map_value_in_range(5, {0, 255}, {0, 100}) == 1.9607843137254901
    assert map_value_in_range(65, {0, 255}, {0, 100}) == 25.49019607843137
    assert map_value_in_range(250, {0, 255}, {0, 100}) == 98.03921568627452
  end
end
