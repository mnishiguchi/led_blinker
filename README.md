# LedBlinker

This is my playground where I learn the basics of the IoT development using Nerves.

## Usage

```ex
gpio_pin = 12
LedBlinker.turn_on(gpio_pin)
LedBlinker.turn_off(gpio_pin)
LedBlinker.toggle(gpio_pin)
```

```ex
gpio_pin = 12
LedBlinker.blink(gpio_pin, 1000)
LedBlinker.stop_blink(gpio_pin)
```

```ex
gpio_pin = 12
LedBlinker.pwm(gpio_pin, 80)
LedBlinker.stop_pwm(gpio_pin)
```

```ex
[12, 13, 19] |> Enum.shuffle |> Enum.map(fn gpio_pin ->
  Task.start_link(fn ->
    Enum.to_list(1..10) ++ Enum.to_list(9..0)
    |> Enum.map(fn x -> x * 10 end)
    |> Enum.map(fn level ->
      LedBlinker.brightness(gpio_pin, level)
      :timer.sleep(499)
    end)
  end)

  :timer.sleep(10_000)
end)
```

## Targets

Nerves applications produce images for hardware targets based on the
`MIX_TARGET` environment variable. If `MIX_TARGET` is unset, `mix` builds an
image that runs on the host (e.g., your laptop). This is useful for executing
logic tests, running utilities, and debugging. Other targets are represented by
a short name like `rpi3` that maps to a Nerves system image for that platform.
All of this logic is in the generated `mix.exs` and may be customized. For more
information about targets see:

https://hexdocs.pm/nerves/targets.html#content

## Getting Started

To start your Nerves app:

- `export MIX_TARGET=my_target` or prefix every command with
  `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi3`
- Install dependencies with `mix deps.get`
- Create firmware with `mix firmware`
- Burn to an SD card with `mix firmware.burn`

## Learn more

- Official docs: https://hexdocs.pm/nerves/getting-started.html
- Official website: https://nerves-project.org/
- Forum: https://elixirforum.com/c/nerves-forum
- Discussion Slack elixir-lang #nerves ([Invite](https://elixir-slackin.herokuapp.com/))
- Source: https://github.com/nerves-project/nerves
