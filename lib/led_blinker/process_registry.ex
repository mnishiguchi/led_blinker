defmodule LedBlinker.ProcessRegistry do
  def child_spec(_args) do
    Supervisor.child_spec(
      Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  @doc """
  Returns a standardized via-tuple for this registry.

  Examples:

      ProcessRegistry.via_tuple(LedController, 20)
      # {:via, Registry, {LedBlinker.ProcessRegistry, {LedBlinker.LedController, 20}}}

  """
  def via_tuple(module_name, identifier) when is_atom(module_name) do
    {:via, Registry, {__MODULE__, {module_name, identifier}}}
  end

  @doc """
  Returns a PID or :undefined.

  Examples:

      ProcessRegistry.whereis_name({LedController, 20})
      # #PID<0.235.0>

  """
  def whereis_name(key) when is_tuple(key) do
    Registry.whereis_name({__MODULE__, key})
  end

  @doc """
  Returns a PID or :undefined.

  Examples:

      LedController.via_tuple(20) |> ProcessRegistry.whereis_via_tuple()
      # :undefined

      LedController.start_link(20)
      # {:ok, #PID<0.235.0>}

      LedController.via_tuple(20) |> ProcessRegistry.whereis_via_tuple()
      # #PID<0.235.0>

  """
  def whereis_via_tuple({:via, _, {_, key}}) when is_tuple(key) do
    whereis_name(key)
  end

  @doc """
  Starts a unique registry.
  """
  def start_link() do
    IO.puts("Starting #{__MODULE__}")
    Registry.start_link(keys: :unique, name: __MODULE__)
  end
end
