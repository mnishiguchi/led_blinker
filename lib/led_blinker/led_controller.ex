defmodule LedBlinker.LedController do
  @moduledoc """
  Controls a given LED. Each process serves as a synchronization point for that
  particular LED.
  """

  # Does not restart on termination. If a process crashes, it will be started on
  # the next use, so there is no need to restart it automatically.
  use GenServer, restart: :temporary

  @idle_timeout :timer.seconds(10)

  # Used as a unique process name when being registered to the process registry.
  defp via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple({__MODULE__, gpio_pin})
  end

  def start_link(gpio_pin) when is_number(gpio_pin) do
    IO.puts("Starting #{__MODULE__}:#{gpio_pin}")
    GenServer.start(__MODULE__, gpio_pin, name: via_tuple(gpio_pin))
  end

  def stop(pid) when is_pid(pid), do: GenServer.stop(pid)

  def on?(pid) when is_pid(pid), do: GenServer.call(pid, :on?)
  def off?(pid), do: !on?(pid)

  def turn_on(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_on)
  def turn_off(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_off)
  def toggle(pid) when is_pid(pid), do: GenServer.cast(pid, :toggle)

  def blink(pid, interval \\ 500) when is_pid(pid) when is_number(interval) do
    schedule_blink(pid, interval)
  end

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
    {:ok, nil, @idle_timeout}
  end

  def handle_info({:initialize_state, gpio_pin}, _) do
    gpio_ref = LedBlinker.Led.gpio_ref(gpio_pin)

    {
      :noreply,
      %{
        gpio_pin: gpio_pin,
        gpio_ref: gpio_ref,
        switched_on: LedBlinker.Led.on?(gpio_ref)
      },
      @idle_timeout
    }
  end

  def handle_info(:timeout, %{gpio_pin: gpio_pin} = state) do
    IO.puts("Stopping #{__MODULE__}:#{gpio_pin}")
    {:stop, :normal, {state, @idle_timeout}}
  end

  def handle_info({:schedule_blink, pid, interval}, state) do
    schedule_blink(pid, interval)
    {:noreply, state, @idle_timeout}
  end

  def handle_call(:on?, _caller_pid, %{switched_on: switched_on} = state) do
    {
      :reply,
      switched_on,
      state,
      @idle_timeout
    }
  end

  def handle_cast(:turn_on, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    unless switched_on, do: LedBlinker.Led.turn_on(gpio_ref)

    {
      :noreply,
      %{state | switched_on: true},
      @idle_timeout
    }
  end

  def handle_cast(:turn_off, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    if switched_on, do: LedBlinker.Led.turn_off(gpio_ref)

    {
      :noreply,
      %{state | switched_on: false},
      @idle_timeout
    }
  end

  def handle_cast(:toggle, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    if switched_on,
      do: LedBlinker.Led.turn_off(gpio_ref),
      else: LedBlinker.Led.turn_on(gpio_ref)

    {
      :noreply,
      %{state | switched_on: !switched_on},
      @idle_timeout
    }
  end
end
