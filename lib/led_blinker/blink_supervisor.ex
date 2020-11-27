defmodule LedBlinker.BlinkSupervisor do
  @moduledoc """
  A simple dynamic supervisor that supervises `PwmBlinkScheduler` processes.
  """

  def child_spec(_args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end

  def start_link() do
    DynamicSupervisor.start_link(name: __MODULE__, strategy: :one_for_one)
  end

  def start_child(args) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {LedBlinker.PwmBlinkScheduler, args}
    )
  end
end
