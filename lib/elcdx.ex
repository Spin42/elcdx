defmodule Elcdx do
  @moduledoc """
  Elixir library for communicating with ELCD LCD display modules via UART.

  This library provides a simple and efficient way to control LCD displays
  through UART communication. It supports various LCD operations including:

  - Text display with automatic line wrapping
  - Cursor control (show/hide)
  - Screen clearing and positioning
  - Scrolling text functionality
  - Multiple display sizes support

  ## Example

      {:ok, lcd} = Elcdx.start_link("/dev/ttyUSB0")

      Elcdx.clear(lcd)
      Elcdx.print(lcd, "Hello, World!")
      Elcdx.move(lcd, 0, 1)
      Elcdx.print(lcd, "Line 2 text")

  ## Configuration

  The library supports various LCD configurations:
  - 16x2 (default)
  - 20x4
  - Custom sizes

  Default UART settings:
  - Baud rate: 19200
  - Data bits: 8
  - Stop bits: 1
  - Parity: None
  """

  alias Elcdx.Driver

  @type t :: Driver.t()
  @type start_option ::
    {:device, String.t()} |
    {:speed, pos_integer()} |
    {:lines, pos_integer()} |
    {:columns, pos_integer()}

  @doc """
  Starts a new LCD connection.

  ## Parameters

  - `device`: UART device path (e.g., "/dev/ttyUSB0")
  - `opts`: Optional configuration
    - `:speed` - UART baud rate (default: 19200)
    - `:lines` - Number of display lines (default: 2)
    - `:columns` - Number of display columns (default: 16)

  ## Examples

      {:ok, lcd} = Elcdx.start_link("/dev/ttyUSB0")
      {:ok, lcd} = Elcdx.start_link("/dev/ttyUSB0", speed: 9600, lines: 4, columns: 20)

  """
  @spec start_link(String.t(), [start_option()]) :: {:ok, t()} | {:error, term()}
  def start_link(device, opts \\ []) do
    Driver.start_link(device, opts)
  end

  @doc """
  Clears the LCD display.

  ## Example

      Elcdx.clear(lcd)

  """
  @spec clear(t()) :: :ok | {:error, term()}
  def clear(lcd), do: Driver.clear(lcd)

  @doc """
  Moves the cursor to the specified position.

  ## Parameters

  - `lcd`: LCD instance
  - `column`: Column position (0-based)
  - `line`: Line position (0-based)

  ## Example

      Elcdx.move(lcd, 5, 1)  # Move to column 5, line 1

  """
  @spec move(t(), non_neg_integer(), non_neg_integer()) :: :ok | {:error, term()}
  def move(lcd, column, line), do: Driver.move(lcd, column, line)

  @doc """
  Displays text on the LCD.

  ## Parameters

  - `lcd`: LCD instance
  - `text`: Text to display
  - `opts`: Display options
    - `:show_cursor` - Show cursor (default: false)
    - `:scroll` - Enable scrolling for long text (default: true)

  ## Examples

      Elcdx.print(lcd, "Hello World")
      Elcdx.print(lcd, "Long text that will scroll", scroll: true)
      Elcdx.print(lcd, "Cursor visible", show_cursor: true)

  """
  @spec print(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def print(lcd, text, opts \\ []), do: Driver.print(lcd, text, opts)

  @doc """
  Shows the cursor.

  ## Example

      Elcdx.cursor_on(lcd)

  """
  @spec cursor_on(t()) :: :ok | {:error, term()}
  def cursor_on(lcd), do: Driver.cursor_on(lcd)

  @doc """
  Hides the cursor.

  ## Example

      Elcdx.cursor_off(lcd)

  """
  @spec cursor_off(t()) :: :ok | {:error, term()}
  def cursor_off(lcd), do: Driver.cursor_off(lcd)

  @doc """
  Stops the LCD connection and cleans up resources.

  ## Example

      Elcdx.stop(lcd)

  """
  @spec stop(t()) :: :ok
  def stop(lcd), do: Driver.stop(lcd)
end
