defmodule LedBlinker.LedControllerCache do
  @moduledoc """
  Maintains a collection of `LedController` processes and is responsible for
  their creation and retrieval.

  Examples:

      gpio_pin = 20
      gpio_pin |> LedControllerCache.get |> LedController.turn_on
      gpio_pin |> LedControllerCache.get |> LedController.turn_off
      gpio_pin |> LedControllerCache.get |> LedController.toggle
      gpio_pin |> LedControllerCache.get |> LedController.blink(300)
      gpio_pin |> LedControllerCache.get |> LedController.blink(600)
      gpio_pin |> LedControllerCache.get |> LedController.stop

  """

  def child_spec(_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  # Link to the caller process. It is required if we want to run the process
  # under a supervisor. When a process crashe, the supervisor will replace it
  # with a new process so the process needs to be registered under a local alias
  # instead of passing a pid around.
  def start_link() do
    IO.puts("Starting #{__MODULE__}")

    # Start the supervisor process here but no children are specified at this
    # point. The process is registered under a local name, which makes it easy
    # to interact with that process and ask it to start a child.
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  @doc """
  Finds or creates a LED controller process for a given GPIO pin.
  """
  def get(gpio_pin) when is_number(gpio_pin) do
    # The way start_child is used here is not very efficient. Every time we want
    # to work with a to-do list, we issue a request to the supervisor, so the
    # supervisor process can become a bottleneck. We will improve it later.
    case start_child(gpio_pin) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
  end

  defp start_child(gpio_pin) when is_number(gpio_pin) do
    # Ask the supervisor to start a child. DynamicSupervisor.start_child/2 is a
    # cross-process synchronous call. A request is sent to the supervisor
    # process, which then starts the child. If multiple client processes
    # simultaneously try to start a child under the same supervisor, the
    # requests will be serialized.
    DynamicSupervisor.start_child(__MODULE__, {LedBlinker.LedController, gpio_pin})
  end
end
