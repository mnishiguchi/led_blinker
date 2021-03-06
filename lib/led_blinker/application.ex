defmodule LedBlinker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LedBlinker.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: LedBlinker.Worker.start_link(arg)
        # {LedBlinker.Worker, arg},
        {LedBlinker.System, nil}
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: LedBlinker.Worker.start_link(arg)
      # {LedBlinker.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: LedBlinker.Worker.start_link(arg)
      # {LedBlinker.Worker, arg},
    ]
  end

  def target() do
    Application.get_env(:led_blinker, :target)
  end
end
