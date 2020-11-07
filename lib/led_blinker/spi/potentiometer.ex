defmodule LedBlinker.SPI.Potentiometer do
  @moduledoc """
  Periodically reads a value from a registered potentiometer.

  ## Examples

      alias LedBlinker.SPI.Potentiometer
      on_scan_fn = fn (value) -> IO.inspect(value) end
      {:ok, pid} =
        LedBlinker.SPI.Potentiometer.start_link(%{
          gpio_pin: 12,
          on_scan_fn: fn (value) -> IO.inspect(value) end
        })
      LedBlinker.SPI.Potentiometer.stop(12)

  """

  # https://hexdocs.pm/elixir/GenServer.html
  use GenServer, restart: :temporary

  import LedBlinker.Utils

  @spi_bus_name "spidev0.0"
  @ch0 <<0x68, 0x00>>
  # @ch1 <<0x78, 0x00>>
  @interval 1000

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple({__MODULE__, gpio_pin})
  end

  def whereis(gpio_pin) when is_number(gpio_pin) do
    case LedBlinker.ProcessRegistry.whereis_name({__MODULE__, gpio_pin}) do
      :undefined -> nil
      pid -> pid
    end
  end

  def start_link(%{gpio_pin: gpio_pin, on_scan_fn: on_scan_fn} = args)
      when is_number(gpio_pin) and is_function(on_scan_fn) do
    GenServer.start_link(__MODULE__, args, name: via_tuple(gpio_pin))
  end

  def stop(gpio_pin) when is_number(gpio_pin) do
    if whereis(gpio_pin), do: GenServer.stop(via_tuple(gpio_pin))
  end

  @impl true
  def init(args) do
    {:ok, spi_ref} = Circuits.SPI.open(@spi_bus_name)
    send(self(), :tick)

    {:ok, Map.put(args, :spi_ref, spi_ref)}
  end

  @impl true
  def handle_info(:tick, state) do
    %{spi_ref: spi_ref, on_scan_fn: on_scan_fn} = state

    spi_ref
    |> read_potentiometer_ten_bit_value()
    |> percentage_from_ten_bit()
    |> on_scan_fn.()

    Process.send_after(self(), :tick, @interval)
    {:noreply, state}
  end

  defp read_potentiometer_ten_bit_value(spi_ref) do
    {:ok, <<_::size(6), ten_bit_value::size(10)>>} = Circuits.SPI.transfer(spi_ref, @ch0)
    ten_bit_value
  end
end
