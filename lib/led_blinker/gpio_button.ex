defmodule LedBlinker.GpioButton do
  @moduledoc """
  Monitors the state of the button (0 or 1).

  ## Examples

      {:ok, pid} = LedBlinker.GpioButton.start_link({
        13,
        fn at -> IO.puts(at) end
      })

  """

  use GenServer, restart: :temporary

  @debounce_time 200_000_000

  def start_link({gpio_pin, on_push_fn}) when is_number(gpio_pin) and is_function(on_push_fn) do
    GenServer.start_link(__MODULE__, {gpio_pin, on_push_fn})
  end

  def init({gpio_pin, on_push_fn}) do
    # Get a ref to the GPIO pin.
    {:ok, gpio_ref} = Circuits.GPIO.open(gpio_pin, :input)

    # Get messages every time the button is pushed.
    Circuits.GPIO.set_interrupts(gpio_ref, :rising)

    {
      :ok,
      %{
        gpio_pin: gpio_pin,
        gpio_ref: gpio_ref,
        last_pushed_at: 0,
        on_push_fn: on_push_fn
      }
    }
  end

  def handle_info({:circuits_gpio, _, at, 1}, state) do
    %{last_pushed_at: last_pushed_at, on_push_fn: on_push_fn} = state

    # Ignore messages for certain interval because one push can send many messages.
    should_accept = @debounce_time < at - last_pushed_at
    if should_accept, do: on_push_fn.(at)

    {:noreply, %{state | last_pushed_at: at}}
  end
end
