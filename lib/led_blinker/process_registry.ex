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

  ## Examples

      ProcessRegistry.via_tuple({LedController, 20})
      # {:via, Registry, {LedBlinker.ProcessRegistry, {LedBlinker.LedController, 20}}}

  """
  def via_tuple(key) when is_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
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
  Starts a unique registry.
  """
  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end
end
