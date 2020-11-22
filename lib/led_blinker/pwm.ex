defmodule LedBlinker.Pwm do
  @moduledoc """
  An OTP behaviour for our Pwm interface.
  """

  # https://hexdocs.pm/elixir/typespecs.html
  @callback call(
              gpio_pin :: pos_integer(),
              frequency :: pos_integer(),
              duty_cycle_in_percentage :: 0..100
            ) ::
              :ok | {:error, any}
end
