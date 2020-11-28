defmodule ExLCD.LCD1602 do
  @moduledoc """
  Base code adopted from: https://github.com/cthree/ex_lcd/blob/43b4fb055e254e851058410be2586fd43c297df9/lib/ex_lcd/hd44780.ex

  ## Examples

  https://github.com/cthree/ex_lcd_examples/blob/master/hd44780_demo/lib/application.ex

  ```elixir
  ExLCD.LCD1602.start([])

  {:ok, pid} = ExLCD.start_link({ExLCD.LCD1602, []})
  ExLCD.clear()
  ExLCD.write("Hello, Joe")

  TODO How to set it to 8bit mode?
  TODO How to turn on backlight?
  TODO Check all the ExLCD features
  TODO Refactor
  ```
  """

  use Bitwise
  use ExLCD.Driver
  require Logger

  # commands
  @lcd_clear_display 0x01
  @lcd_return_home 0x02
  @lcd_entry_mode_set 0x04
  @lcd_display_control 0x08
  @lcd_cursor_shift 0x10
  @lcd_function_set 0x20
  @lcd_set_cgram_address 0x40
  @lcd_set_ddram_address 0x80

  # flags for display entry mode
  @lcd_entry_left 0x02
  @lcd_entry_increment 0x01

  # flags for display on/off control
  @lcd_display_on 0x04
  @lcd_cursor_on 0x02
  @lcd_blink_on 0x01

  # flags for display/cursor shift
  @lcd_display_move 0x08
  @lcd_move_right 0x04

  # flags for function set
  @lcd_4bit_mode 0x01
  @lcd_8bit_mode 0x00
  @lcd_5x8_dots 0x00
  @lcd_5x10_dots 0x04
  @lcd_one_line 0x00
  @lcd_two_lines 0x08

  # flags for backlight control
  @lcd_backlight_on 0x08

  @enable_bit 0b00000100

  @register_select_instruction 0
  @register_select_data 1

  @i2c_device "i2c-1"
  @i2c_address 0x27
  @default_display %{
    i2c_ref: nil,
    rows: 2,
    cols: 16,
    # feature flags
    backlight: 0x00,
    function_set: 0x00,
    display_control: 0x00,
    entry_mode: 0x00,
    shift_control: 0x00
  }

  @doc false
  @impl true
  def start(config) do
    bits =
      case config[:d0] do
        nil -> @lcd_4bit_mode
        _ -> @lcd_8bit_mode
      end

    lines =
      case config[:rows] do
        1 -> @lcd_one_line
        _ -> @lcd_two_lines
      end

    font =
      case config[:font_5x10] do
        true -> @lcd_5x10_dots
        _ -> @lcd_5x8_dots
      end

    # TODO: DI i2c module from config because Circuits.I2C only works in target.
    {:ok, i2c_ref} = Circuits.I2C.open(@i2c_device)

    display = %{
      @default_display
      | i2c_ref: i2c_ref,
        backlight: @lcd_backlight_on,
        function_set: @lcd_function_set ||| bits ||| font ||| lines,
        display_control: @lcd_display_control ||| @lcd_display_on,
        entry_mode: @lcd_entry_mode_set ||| @lcd_entry_left,
        shift_control: @lcd_cursor_shift
    }

    # ???
    # |> rs(@low)
    # |> en(@low)
    # |> poi(bits)
    # |> set_feature(:function_set)
    # |> clear()

    display
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

  defp command(display, {:clear, _params}) do
    clear(display)
    {:ok, display}
  end

  defp command(display, {:home, _params}) do
    home(display)
    {:ok, display}
  end

  # translate string to charlist
  defp command(display, {:print, content}) do
    characters = String.to_charlist(content)
    command(display, {:write, characters})
  end

  defp command(display, {:write, content}) do
    content |> Enum.each(fn x -> write_data(display, x) end)
    {:ok, display}
  end

  defp command(display, {:set_cursor, {row, col}}) do
    {:ok, set_cursor(display, {row, col})}
  end

  defp command(display, {:cursor, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @lcd_cursor_on)}
  end

  defp command(display, {:cursor, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @lcd_cursor_on)}
  end

  defp command(display, {:blink, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @lcd_blink_on)}
  end

  defp command(display, {:blink, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @lcd_blink_on)}
  end

  defp command(display, {:display, :off}) do
    {:ok, disable_feature_flag(display, :display_control, @lcd_display_on)}
  end

  defp command(display, {:display, :on}) do
    {:ok, enable_feature_flag(display, :display_control, @lcd_display_on)}
  end

  defp command(display, {:autoscroll, :off}) do
    {:ok, disable_feature_flag(display, :entry_mode, @lcd_entry_increment)}
  end

  defp command(display, {:autoscroll, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @lcd_entry_increment)}
  end

  defp command(display, {:rtl_text, :on}) do
    {:ok, disable_feature_flag(display, :entry_mode, @lcd_entry_left)}
  end

  defp command(display, {:ltr_text, :on}) do
    {:ok, enable_feature_flag(display, :entry_mode, @lcd_entry_left)}
  end

  # Scroll the entire display left (-) or right (+)
  defp command(display, {:scroll, 0}), do: {:ok, display}

  defp command(display, {:scroll, cols}) when cols < 0 do
    write_instruction(display, @lcd_cursor_shift ||| @lcd_display_move)
    command(display, {:scroll, cols + 1})
  end

  defp command(display, {:scroll, cols}) do
    write_instruction(display, @lcd_cursor_shift ||| @lcd_display_move ||| @lcd_move_right)
    command(display, {:scroll, cols - 1})
  end

  # Scroll(move) cursor right
  defp command(display, {:right, 0}), do: {:ok, display}

  defp command(display, {:right, cols}) do
    write_instruction(display, @lcd_cursor_shift ||| @lcd_move_right)
    command(display, {:right, cols - 1})
  end

  # Scroll(move) cursor left
  defp command(display, {:left, 0}), do: {:ok, display}

  defp command(display, {:left, cols}) do
    write_instruction(display, @lcd_cursor_shift)
    command(display, {:left, cols - 1})
  end

  # Program custom character to CGRAM
  defp command(display, {:char, idx, bitmap}) when idx in 0..7 and length(bitmap) === 8 do
    write_instruction(display, @lcd_set_cgram_address ||| idx <<< 3)

    for line <- bitmap do
      write_data(display, line)
    end

    {:ok, display}
  end

  # All other commands are unsupported
  defp command(display, _), do: {:unsupported, display}

  # ---
  # Low-level device and utility functions
  # ---

  defp clear(display) when is_map(display) do
    display |> write_instruction(@lcd_clear_display) |> delay(3)
  end

  defp home(display) when is_map(display) do
    display |> write_instruction(@lcd_return_home) |> delay(3)
  end

  # DDRAM is organized as two 40 byte rows. In a 2x display the first row
  # maps to address 0x00 - 0x27 and the second row maps to 0x40 - 0x67
  # in a 4x display rows 0 & 2 are mapped to the first row of DDRAM and
  # rows 1 & 3 map to the second row of DDRAM. This means that the rows
  # are not contiguous in memory.
  #
  # row_offsets/1 determines the starting DDRAM address of each display row
  # and returns a map for up to 4 rows.
  defp row_offsets(cols) when is_integer(cols) do
    %{0 => 0x00, 1 => 0x40, 2 => 0x00 + cols, 3 => 0x40 + cols}
  end

  # Set the DDRAM address corresponding to the {row,col} position
  defp set_cursor(%{cols: cols, rows: rows} = display, {row, col})
       when is_integer(rows) and is_integer(cols) and is_integer(row) and is_integer(col) do
    col = min(col, cols - 1)
    row = min(row, rows - 1)
    %{^row => offset} = row_offsets(cols)
    write_instruction(display, @lcd_set_ddram_address ||| col + offset)
  end

  # Switch a register flag bit OFF(0). Return the updated state.
  defp disable_feature_flag(display, feature, flag) when is_map(display) and is_atom(feature) do
    %{display | feature => display[feature] &&& ~~~flag}
    |> set_feature(feature)
  end

  # Switch a register flag bit ON(1). Return the updated state.
  defp enable_feature_flag(display, feature, flag) when is_map(display) and is_atom(feature) do
    %{display | feature => display[feature] ||| flag}
    |> set_feature(feature)
  end

  # Write a feature register to the controller and return the state.
  defp set_feature(display, feature) when is_map(display) and is_atom(feature) do
    write_instruction(display, display[feature])
  end

  # Write a byte to the device
  defp write_instruction(display, byte) when is_map(display) do
    display
    |> write_4_bits(@register_select_instruction ||| (byte &&& 0xF0))
    |> write_4_bits(@register_select_instruction ||| (byte <<< 4 &&& 0xF0))
  end

  defp write_data(display, byte) when is_map(display) do
    display
    |> write_4_bits(@register_select_data ||| (byte &&& 0xF0))
    |> write_4_bits(@register_select_data ||| (byte <<< 4 &&& 0xF0))
  end

  # Write 4 bits to the device
  defp write_4_bits(display, bits) when is_map(display) and is_integer(bits) do
    display
    |> i2c_write(bits)
    |> pulse_enable(bits)
  end

  defp pulse_enable(display, bits) do
    display
    |> i2c_write(bits ||| @enable_bit)
    |> delay(1)
    |> i2c_write(bits &&& ~~~@enable_bit)
  end

  defp i2c_write(display, bits) when is_map(display) and is_integer(bits) do
    %{i2c_ref: i2c_ref} = display
    :ok = Circuits.I2C.write(i2c_ref, @i2c_address, <<bits>>)
    display
  end

  defp delay(display, milliseconds) do
    # Unfortunately, BEAM does not provides microsecond precision
    # And if we need waiting, we MUST wait
    Process.sleep(milliseconds)
    display
  end
end
