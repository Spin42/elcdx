defmodule Elcdx.Driver.Hardware do
  @moduledoc """
  Low-level hardware communication module for ELCD LCD displays.

  This module handles direct UART communication with the LCD hardware,
  implementing the ELCD protocol commands for display control, cursor
  management, and text output.

  ## UART Protocol Commands

  The ELCD modules use the following command set:

  - `0xA0`: Initialize display
  - `0xA3, 0x01`: Clear display
  - `0xA3, 0x0C`: Cursor off
  - `0xA3, 0x0E`: Cursor on
  - `0xA1`: Move cursor (followed by X, Y coordinates)
  - `0xA2`: Print line (followed by text and null terminator)

  ## Responsibilities

  - Direct UART communication
  - Command encoding and transmission
  - Hardware initialization and setup
  - Cursor control commands
  - Text output to display
  - Error handling for communication failures

  ## Hardware Considerations

  - All commands require proper timing
  - Display initialization needs 600ms delay
  - Text output requires null termination
  - Coordinate system is 0-based (column, line)
  """

  alias Circuits.UART

  # Protocol timing constants
  @init_delay_ms 600

  @doc """
  Initializes the LCD display hardware.

  Sends the initialization command and waits for the required delay
  before the display is ready for further operations.

  ## Parameters

  - `state`: Driver state containing UART connection

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.

  ## Timing

  Includes a 600ms delay after initialization for hardware stability.
  """
  def init_display(%{uart: uart}) do
    case UART.write(uart, <<0xA0>>) do
      :ok ->
        Process.sleep(@init_delay_ms)
        :ok
      error ->
        error
    end
  end

  @doc """
  Clears the entire display.

  Sends the clear display command to erase all content and reset
  the display to a blank state.

  ## Parameters

  - `state`: Driver state containing UART connection

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.
  """
  def clear_display(state) do
    send_command(state, <<0xA3, 0x01>>)
  end

  @doc """
  Moves the cursor to a specific position.

  Sets the cursor position for subsequent text output operations.
  Coordinates are 0-based with (0,0) at the top-left corner.

  ## Parameters

  - `state`: Driver state containing UART connection
  - `column`: Column position (0-based, typically 0-15)
  - `line`: Line position (0-based, typically 0-1)

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.

  ## Protocol

  Sends command sequence: `0xA1` + column byte + line byte
  """
  def move_cursor(%{uart: uart}, column, line) do
    with :ok <- UART.write(uart, <<0xA1>>),
         :ok <- UART.write(uart, <<column>>),
         :ok <- UART.write(uart, <<line>>) do
      :ok
    end
  end

  @doc """
  Sends a raw command to the display.

  Low-level function for sending arbitrary command bytes to the display.
  Used internally by other functions for specific operations.

  ## Parameters

  - `state`: Driver state containing UART connection
  - `command`: Binary command data to send

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.
  """
  def send_command(%{uart: uart}, command) do
    UART.write(uart, command)
  end

  @doc """
  Prints a line of text to the display.

  Outputs text to the current cursor position. The text is automatically
  null-terminated as required by the ELCD protocol.

  ## Parameters

  - `state`: Driver state containing UART connection
  - `text`: Text string to display

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.

  ## Protocol

  Sends command sequence: `0xA2` + text bytes + null terminator (`0x00`)

  ## Notes

  - Text should fit within the display width
  - No automatic wrapping is performed at this level
  - Cursor position is not automatically updated
  """
  def print_line(%{uart: uart}, text) do
    with :ok <- UART.write(uart, <<0xA2>>),
         :ok <- UART.write(uart, text),
         :ok <- UART.write(uart, <<0x00>>) do
      :ok
    end
  end

  @doc """
  Controls cursor visibility on the display.

  Shows or hides the cursor indicator on the LCD display.

  ## Parameters

  - `state`: Driver state containing UART connection
  - `visible`: Boolean - true to show cursor, false to hide

  ## Returns

  `:ok` on success, `{:error, reason}` on communication failure.

  ## Protocol Commands

  - Cursor on: `0xA3, 0x0E`
  - Cursor off: `0xA3, 0x0C`
  """
  def set_cursor_visibility(state, true), do: send_command(state, <<0xA3, 0x0E>>)
  def set_cursor_visibility(state, false), do: send_command(state, <<0xA3, 0x0C>>)
end
