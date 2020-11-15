defmodule LedBlinker.LedController do
  @moduledoc """
  Controls a given LED. Each process serves as a synchronization point for that
  particular LED. Users start/access a LedController process by calling
  LedControllerCache.get(gpio_pin).
  """

  # Does not restart on termination. If a process crashes, it will be started on
  # the next use, so there is no need to restart it automatically.
  use GenServer, restart: :temporary

  require Logger

  @idle_timeout :timer.minutes(10)

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple(__MODULE__, gpio_pin)
  end

  def start_link(gpio_pin) when is_number(gpio_pin) do
    GenServer.start_link(__MODULE__, gpio_pin, name: via_tuple(gpio_pin))
  end

  def stop(pid) when is_pid(pid), do: GenServer.stop(pid)
  def stop(gpio_pin) when is_number(gpio_pin), do: GenServer.stop(via_tuple(gpio_pin))

  def on?(pid) when is_pid(pid), do: GenServer.call(pid, :on?)
  def off?(pid), do: !on?(pid)

  def turn_on(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_on)
  def turn_off(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_off)
  def toggle(pid) when is_pid(pid), do: GenServer.cast(pid, :toggle)

  @impl true
  def init(gpio_pin) do
    # Initialize later so we can avoid blocking the caller.
    send(self(), {:initialize_state, gpio_pin})
    {:ok, nil, @idle_timeout}
  end

  @impl true
  def handle_info({:initialize_state, gpio_pin}, _) do
    gpio_ref = LedBlinker.GpioLed.gpio_ref(gpio_pin)

    {
      :noreply,
      %{
        gpio_pin: gpio_pin,
        gpio_ref: gpio_ref,
        switched_on: LedBlinker.GpioLed.on?(gpio_ref)
      },
      @idle_timeout
    }
  end

  @impl true
  def handle_info(:timeout, %{gpio_pin: gpio_pin} = state) do
    Logger.info("Timeout #{__MODULE__}:#{gpio_pin}")

    {:stop, :normal, {state, @idle_timeout}}
  end

  @impl true
  def handle_call(:on?, _caller_pid, %{switched_on: switched_on} = state) do
    {:reply, switched_on, state, @idle_timeout}
  end

  @impl true
  def handle_cast(:turn_on, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    unless switched_on, do: LedBlinker.GpioLed.turn_on(gpio_ref)

    {
      :noreply,
      %{state | switched_on: true},
      @idle_timeout
    }
  end

  @impl true
  def handle_cast(:turn_off, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    if switched_on, do: LedBlinker.GpioLed.turn_off(gpio_ref)

    {
      :noreply,
      %{state | switched_on: false},
      @idle_timeout
    }
  end

  @impl true
  def handle_cast(:toggle, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    if switched_on,
      do: LedBlinker.GpioLed.turn_off(gpio_ref),
      else: LedBlinker.GpioLed.turn_on(gpio_ref)

    {
      :noreply,
      %{state | switched_on: !switched_on},
      @idle_timeout
    }
  end

  @impl true
  def terminate(_reason, %{gpio_ref: gpio_ref} = state) do
    LedBlinker.GpioLed.turn_off(gpio_ref)

    {
      :noreply,
      %{state | switched_on: false},
      @idle_timeout
    }
  end
end
