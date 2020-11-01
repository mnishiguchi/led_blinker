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
  """
  def via_tuple(key) do
    {:via, Registry, {__MODULE__, key}}
  end

  @doc """
  Starts a unique registry.
  """
  def start_link() do
    IO.puts("Starting #{__MODULE__}")
    Registry.start_link(keys: :unique, name: __MODULE__)
  end
end
