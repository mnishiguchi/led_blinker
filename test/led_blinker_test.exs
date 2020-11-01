defmodule LedBlinkerTest do
  use ExUnit.Case
  doctest LedBlinker

  test "greets the world" do
    assert LedBlinker.hello() == :world
  end
end
