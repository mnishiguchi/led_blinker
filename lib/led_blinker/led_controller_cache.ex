defmodule LedBlinker.LedControllerCache do
  @moduledoc """
  Maintains a collection of `LedController` processes and is responsible for
  their creation and retrieval.
  """

  # https://hexdocs.pm/elixir/GenServer.html
  use GenServer

  # ---
  # The client API
  # ---

  def start_link(_) do
    IO.puts("Starting #{__MODULE__}")
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc """
  Finds or creates a LED controller by GPIO pin number.
  """
  def get(gpio_pin) when is_number(gpio_pin) do
    GenServer.call(__MODULE__, {:get, gpio_pin})
  end

  # ---
  # The server callbacks
  # ---

  def init(_) do
    # A map of LED tag to pid, initially blank. It will be something like:
    #
    #     %{"LED A" => #PID<0.208.0>, "LED B" => #PID<0.209.0>, ...}
    #
    led_controllers = %{}

    {:ok, led_controllers}
  end

  def handle_call({:get, gpio_pin}, _caller_pid, led_controllers) when is_number(gpio_pin) do
    case find_or_create_led_controller(led_controllers, gpio_pin) do
      {:found, led_controller} ->
        {:reply, led_controller, led_controllers}

      {:created, led_controller} ->
        {:reply, led_controller, led_controllers |> Map.put(gpio_pin, led_controller)}
    end
  end

  defp find_or_create_led_controller(led_controllers, gpio_pin) do
    case Map.fetch(led_controllers, gpio_pin) do
      {:ok, led_controller} ->
        {:found, led_controller}

      :error ->
        {:ok, led_controller} = LedBlinker.LedController.start_link(gpio_pin)
        {:created, led_controller}
    end
  end
end
