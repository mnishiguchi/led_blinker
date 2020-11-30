defmodule ExLCD.HD44780 do
  @moduledoc """
  Base code adopted from: https://github.com/cthree/ex_lcd/blob/43b4fb055e254e851058410be2586fd43c297df9/lib/ex_lcd/hd44780.ex

  [How to Use Character LCD Module](http://elm-chan.org/docs/lcd/hd44780_e.html)

  ## Examples

  https://github.com/cthree/ex_lcd_examples/blob/master/hd44780_demo/lib/application.ex

  ```elixir
  display = ExLCD.HD44780.start([])

  {:ok, pid} = ExLCD.start_link({ExLCD.HD44780, []})
  ExLCD.clear()
  ExLCD.write("Hello, Joe")

  TODO Check all the ExLCD features
  TODO Refactor
  ```
  """

  use Bitwise
  use ExLCD.Driver
  require Logger

  # commands
  # See datasheet page 28
  @cmd_clear_display 0x01
  @cmd_return_home 0x02
  @cmd_entry_mode_set 0x04
  @cmd_display_control 0x08
  @cmd_cursor_shift 0x10
  @cmd_function_set 0x20
  @cmd_set_cgram_address 0x40
  @cmd_set_ddram_address 0x80

  # flags for display entry mode
  @entry_left 0x02
  @entry_increment 0x01

  # flags for display on/off control
  @display_on 0x04
  @display_off 0x00
  @cursor_on 0x02
  @cursor_off 0x00
  @blink_on 0x01
  @blink_off 0x00

  # flags for display/cursor shift
  @display_move 0x08
  @move_right 0x04

  # flags for function set
  @font_size_5x10 0x04
  @font_size_5x8 0x00
  @number_of_lines_2 0x08
  @number_of_lines_1 0x00

  # flags for backlight control
  @backlight_on 0x08
  @backlight_off 0x00

  # EN, RW and RS
  @enable_bit 0b00000100
  @register_select_instruction 0b00000000
  @register_select_data 0b00000001

  # TODO: guard for config
  @doc false
  @impl true
  def start(config) do
    # TODO: DI i2c module from config because Circuits.I2C only works in target.
    {:ok, i2c_ref} = Circuits.I2C.open(config[:i2c_device] || "i2c-1")

    lines = if config[:rows] == 1, do: @number_of_lines_1, else: @number_of_lines_2
    font_size = if config[:font_size] == "5x10", do: @font_size_5x10, else: @font_size_5x8

    display = %{
      i2c_ref: i2c_ref,
      i2c_address: config[:i2c_address] || 0x27,
      rows: config[:rows] || 2,
      cols: config[:cols] || 16,
      # feature flags
      entry_mode: @cmd_entry_mode_set ||| @entry_left,
      display_control: @cmd_display_control ||| @display_on,
      backlight: @backlight_on
    }

    display
    # Wait for more than 40ms after power rises above 2.7V before sending commands.
    |> delay(50)
    |> expander_write(display.backlight)
    |> delay(1000)

    # Function set (8-bit mode) x 3 times
    |> write_4_bits(0x03 <<< 4)
    |> delay(5)
    |> write_4_bits(0x03 <<< 4)
    |> delay(5)
    |> write_4_bits(0x03 <<< 4)
    |> delay(1)

    # Function set (4-bit mode)
    |> write_4_bits(0x02 <<< 4)
    |> write_instruction(@cmd_function_set ||| font_size ||| lines)
    |> write_instruction(display.display_control)
    |> clear()
    |> write_instruction(display.entry_mode)
    |> home()
  end

  @doc false
  @impl true
  def stop(display) do
    {:ok, _display} = command(display, {:display, :off})
    :ok
  end

  @doc false
  @impl true
  def execute do
    &command/2
  end

  # ---
  # ExLCD API callback
  # ---

  def command(display, {:clear, _params}) do
    clear(display)
    {:ok, display}
  end

  def command(display, {:home, _params}) do
    home(display)
    {:ok, display}
  end

  # translate string to charlist
  def command(display, {:print, content}) do
    characters = String.to_charlist(content)
    command(display, {:write, characters})
  end

  def command(display, {:write, content}) do
    content |> Enum.each(fn x -> write_data(display, x) end)
    {:ok, display}
  end

  def command(display, {:set_cursor, {row, col}}) do
    {:ok, set_cursor(display, {row, col})}
  end

  def command(display, {:cursor, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @cursor_on)}
  end

  def command(display, {:cursor, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @cursor_on)}
  end

  def command(display, {:blink, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @blink_on)}
  end

  def command(display, {:blink, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @blink_on)}
  end

  def command(display, {:display, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @display_on)}
  end

  def command(display, {:display, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @display_on)}
  end

  def command(display, {:autoscroll, :off}) do
    {:ok, disable_feature_flag(display, :entry_mode, @entry_increment)}
  end

  def command(display, {:autoscroll, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @entry_increment)}
  end

  def command(display, {:rtl_text, :on}) do
    {:ok, disable_feature_flag(display, :entry_mode, @entry_left)}
  end

  def command(display, {:ltr_text, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @entry_left)}
  end

  # Scroll the entire display left (-) or right (+)
  def command(display, {:scroll, 0}), do: {:ok, display}

  def command(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @cmd_cursor_shift ||| @display_move)
    {:ok, _display} = command(display, {:scroll, cols + 1})
  end

  def command(display, {:scroll, cols}) do
    write_instruction(display, @cmd_cursor_shift ||| @display_move ||| @move_right)
    {:ok, _display} = command(display, {:scroll, cols - 1})
  end

  # Scroll(move) cursor right
  def command(display, {:right, 0}), do: {:ok, display}

  def command(display, {:right, cols}) do
    write_instruction(display, @cmd_cursor_shift ||| @move_right)
    {:ok, _display} = command(display, {:right, cols - 1})
  end

  # Scroll(move) cursor left
  def command(display, {:left, 0}), do: {:ok, display}

  def command(display, {:left, cols}) do
    write_instruction(display, @cmd_cursor_shift)
    {:ok, _display} = command(display, {:left, cols - 1})
  end

  # Program custom character to CGRAM
  def command(display, {:char, idx, bitmap}) when idx in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @cmd_set_cgram_address ||| idx <<< 3)

    for line <- bitmap do
      write_data(display, line)
    end

    {:ok, display}
  end

  # All other commands are unsupported
  def command(display, _), do: {:unsupported, display}

  # ---
  # Low-level device and utility functions
  # ---

  def clear(display) when is_map(display) do
    display
    |> write_instruction(@cmd_clear_display)
    |> delay(3)
  end

  def home(display) when is_map(display) do
    display
    |> write_instruction(@cmd_return_home)
    |> delay(3)
  end

  # DDRAM is organized as two 40 byte rows. In a 2x display the first row
  # maps to address 0x00 - 0x27 and the second row maps to 0x40 - 0x67
  # in a 4x display rows 0 & 2 are mapped to the first row of DDRAM and
  # rows 1 & 3 map to the second row of DDRAM. This means that the rows
  # are not contiguous in memory.
  #
  # row_offsets/1 determines the starting DDRAM address of each display row
  # and returns a map for up to 4 rows.
  def row_offsets(cols) when is_integer(cols) do
    %{0 => 0x00, 1 => 0x40, 2 => 0x00 + cols, 3 => 0x40 + cols}
  end

  # Set the DDRAM address corresponding to the {row,col} position
  def set_cursor(%{cols: cols, rows: rows} = display, {row, col})
      when is_integer(rows) and is_integer(cols) and is_integer(row) and is_integer(col) do
    col = min(col, cols - 1)
    row = min(row, rows - 1)
    %{^row => offset} = row_offsets(cols)
    write_instruction(display, @cmd_set_ddram_address ||| col + offset)
  end

  def set_backlight(display, flag) do
    %{display | backlight: if(flag, do: @backlight_on, else: @backlight_off)}
    |> expander_write(0)
  end

  # Switch a register flag bit OFF(0). Return the updated state.
  def disable_feature_flag(display, feature, flag) when is_map(display) and is_atom(feature) do
    %{display | feature => display[feature] &&& ~~~flag}
    |> write_instruction(display[feature])
  end

  # Switch a register flag bit ON(1). Return the updated state.
  def enable_feature_flag(display, feature, flag) when is_map(display) and is_atom(feature) do
    %{display | feature => display[feature] ||| flag}
    |> write_instruction(display[feature])
  end

  def write_instruction(display, byte) when is_map(display) do
    write_byte(display, byte, @register_select_instruction)
  end

  def write_data(display, byte) when is_map(display) do
    write_byte(display, byte, @register_select_data)
  end

  def write_byte(display, byte, mode \\ 0) when is_map(display) and mode in 0..1 do
    display
    |> write_4_bits((byte &&& 0xF0) ||| mode)
    |> write_4_bits((byte <<< 4 &&& 0xF0) ||| mode)
  end

  # Write 4 bits to the device
  def write_4_bits(display, bits) when is_map(display) and is_integer(bits) do
    display
    |> expander_write(bits)
    |> pulse_enable(bits)
  end

  def pulse_enable(display, bits) do
    display
    |> expander_write(bits ||| @enable_bit)
    |> delay(1)
    |> expander_write(bits &&& ~~~@enable_bit)
  end

  def expander_write(
        %{i2c_ref: i2c_ref, i2c_address: i2c_address, backlight: backlight} = display,
        bits
      )
      when is_reference(i2c_ref) and is_integer(i2c_address) and is_integer(bits) do
    Logger.info(
      "Write #{
        Integer.to_string(bits, 2)
        |> String.pad_leading(8, "0")
      } to 0x#{Integer.to_string(i2c_address, 16)}"
    )

    :ok = Circuits.I2C.write(i2c_ref, i2c_address, <<bits ||| backlight>>)
    display
  end

  def delay(display, milliseconds) do
    Process.sleep(milliseconds)
    display
  end
end
