defmodule LedBlinker.LedController do
  @moduledoc """
  Controls a given LED. Each process serves as a synchronization point for that
  particular LED.
  """

  # https://hexdocs.pm/elixir/GenServer.html
  use GenServer

  def start_link(gpio_pin) when is_number(gpio_pin) do
    IO.puts("Starting #{__MODULE__}")
    GenServer.start(__MODULE__, gpio_pin)
  end

  def on?(pid) when is_pid(pid), do: GenServer.call(pid, :on?)
  def off?(pid) when is_pid(pid), do: on?(pid) == false

  def turn_on(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_on)
  def turn_off(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_off)
  def toggle(pid) when is_pid(pid), do: GenServer.cast(pid, :toggle)

  def blink(pid, interval) when is_pid(pid) when is_number(interval) do
    schedule_blink(pid, interval)
  end

  # This is handy when we want to stop the blinking.
  def terminate(pid) when is_pid(pid), do: Process.exit(pid, :kill)

  # Toggles the switch now and schedule next.
  defp schedule_blink(pid, interval) when is_pid(pid) when is_number(interval) do
    GenServer.cast(pid, :toggle)
    Process.send_after(pid, {:schedule_blink, pid, interval}, interval)
  end

  # ---
  # Callbacks
  # ---

  def init(gpio_pin) do
    # Initialize later so we can avoid blocking the caller.
    send(self(), {:initialize_state, gpio_pin})
    {:ok, nil}
  end

  def handle_info({:initialize_state, gpio_pin}, _) do
    {
      :noreply,
      %{
        gpio_pin: gpio_pin,
        switched_on: LedBlinker.Led.on?(gpio_pin)
      }
    }
  end

  def handle_info({:schedule_blink, pid, interval}, state) do
    schedule_blink(pid, interval)
    {:noreply, state}
  end

  def handle_call(:on?, _caller_pid, %{switched_on: switched_on} = state) do
    {:reply, switched_on, state}
  end

  def handle_cast(:turn_on, %{gpio_pin: gpio_pin, switched_on: switched_on} = state) do
    unless switched_on, do: LedBlinker.Led.turn_on(gpio_pin)
    {:noreply, state |> Map.put(:switched_on, true)}
  end

  def handle_cast(:turn_off, %{gpio_pin: gpio_pin, switched_on: switched_on} = state) do
    if switched_on, do: LedBlinker.Led.turn_off(gpio_pin)
    {:noreply, state |> Map.put(:switched_on, false)}
  end

  def handle_cast(:toggle, %{gpio_pin: gpio_pin, switched_on: switched_on} = state) do
    if switched_on,
      do: LedBlinker.Led.turn_off(gpio_pin),
      else: LedBlinker.Led.turn_on(gpio_pin)

    {:noreply, state |> Map.put(:switched_on, !switched_on)}
  end
end
