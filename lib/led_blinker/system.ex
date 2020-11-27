defmodule LedBlinker.System do
  use Supervisor

  def start_link(_args) do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_args) do
    # Child processes are started synchronously.
    # Always make sure our init/1 functions run quickly.
    Supervisor.init(
      [
        {LedBlinker.ProcessRegistry, nil},
        {LedBlinker.LedControllerCache, nil},
        {LedBlinker.BlinkSupervisor, nil}
      ],
      strategy: :one_for_one
    )
  end
end
