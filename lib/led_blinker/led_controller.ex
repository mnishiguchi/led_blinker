defmodule LedBlinker.LedController do
  @moduledoc """
  Controls a given LED. Each process serves as a synchronization point for that
  particular LED. Users start/access a LedController process by calling
  LedControllerCache.get(gpio_pin).
  """

  # Does not restart on termination. If a process crashes, it will be started on
  # the next use, so there is no need to restart it automatically.
  use GenServer, restart: :temporary

  @idle_timeout :timer.minutes(10)

  # Used as a unique process name.
  def via_tuple(gpio_pin) when is_number(gpio_pin) do
    LedBlinker.ProcessRegistry.via_tuple({__MODULE__, gpio_pin})
  end

  def start_link(gpio_pin) when is_number(gpio_pin) do
    IO.puts("Starting #{__MODULE__}:#{gpio_pin}")
    GenServer.start(__MODULE__, gpio_pin, name: via_tuple(gpio_pin))
  end

  def stop(pid) when is_pid(pid), do: GenServer.stop(pid)
  def stop(gpio_pin) when is_number(gpio_pin), do: GenServer.stop(via_tuple(gpio_pin))

  def on?(pid) when is_pid(pid), do: GenServer.call(pid, :on?)
  def off?(pid), do: !on?(pid)

  def turn_on(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_on)
  def turn_off(pid) when is_pid(pid), do: GenServer.cast(pid, :turn_off)
  def toggle(pid) when is_pid(pid), do: GenServer.cast(pid, :toggle)

  def blink(pid, interval \\ 500) when is_pid(pid) when is_number(interval) do
    GenServer.cast(pid, {:blink, interval})
  end

  def pwm(pid, frequency: frequency, duty_cycle: duty_cycle)
      when is_pid(pid)
      when frequency in 100..50_000
      when duty_cycle in 0..100 do
    GenServer.cast(pid, {:pwm, frequency, duty_cycle})
  end

  @impl true
  def init(gpio_pin) do
    # Initialize later so we can avoid blocking the caller.
    send(self(), {:initialize_state, gpio_pin})
    {:ok, nil, @idle_timeout}
  end

  @impl true
  def handle_info({:initialize_state, gpio_pin}, _) do
    gpio_ref = LedBlinker.Led.gpio_ref(gpio_pin)

    {
      :noreply,
      %{
        gpio_pin: gpio_pin,
        gpio_ref: gpio_ref,
        switched_on: LedBlinker.Led.on?(gpio_ref),
        blink_pid: nil
      },
      @idle_timeout
    }
  end

  @impl true
  def handle_info(:timeout, %{gpio_pin: gpio_pin, blink_pid: blink_pid} = state) do
    IO.puts("Stopping #{__MODULE__}:#{gpio_pin}")
    cleanup_blink_scheduler(blink_pid)

    {:stop, :normal, {%{state | blink_pid: nil}, @idle_timeout}}
  end

  @impl true
  def handle_call(:on?, _caller_pid, %{switched_on: switched_on} = state) do
    {:reply, switched_on, state, @idle_timeout}
  end

  @impl true
  def handle_cast(:turn_on, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    unless switched_on, do: LedBlinker.Led.turn_on(gpio_ref)

    {
      :noreply,
      %{state | switched_on: true},
      @idle_timeout
    }
  end

  @impl true
  def handle_cast(:turn_off, %{gpio_ref: gpio_ref, switched_on: switched_on} = state) do
    if switched_on, do: LedBlinker.Led.turn_off(gpio_ref)

    {
      :noreply,
      %{state | switched_on: false},
      @idle_timeout
    }
  end

  @impl true
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

  # Handle the blinking of the LED.
  @impl true
  def handle_cast({:blink, interval}, %{gpio_pin: gpio_pin, blink_pid: blink_pid} = state) do
    cleanup_blink_scheduler(blink_pid)

    {:ok, blink_pid} =
      LedBlinker.BlinkScheduler.start_link([
        interval,
        fn -> GenServer.cast(via_tuple(gpio_pin), :toggle) end
      ])

    {
      :noreply,
      %{state | blink_pid: blink_pid},
      @idle_timeout
    }
  end

  # Handle changing the brightness of the LED.
  @impl true
  def handle_cast(
        {:pwm, frequency, duty_cycle},
        %{gpio_pin: gpio_pin, blink_pid: blink_pid} = state
      ) do
    cleanup_blink_scheduler(blink_pid)

    {:ok, blink_pid} =
      LedBlinker.PwmScheduler.start_link(%{
        frequency: frequency,
        duty_cycle: duty_cycle,
        turn_on_fn: fn -> GenServer.cast(via_tuple(gpio_pin), :turn_on) end,
        turn_off_fn: fn -> GenServer.cast(via_tuple(gpio_pin), :turn_off) end
      })

    {
      :noreply,
      %{state | blink_pid: blink_pid},
      @idle_timeout
    }
  end

  @impl true
  def terminate(_reason, %{blink_pid: blink_pid} = state) do
    cleanup_blink_scheduler(blink_pid)

    {
      :noreply,
      %{state | blink_pid: nil},
      @idle_timeout
    }
  end

  # Stops currently-running blink process if any.
  defp cleanup_blink_scheduler(blink_pid) do
    if blink_pid, do: GenServer.stop(blink_pid)
  end
end
