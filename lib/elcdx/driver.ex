defmodule Elcdx.Driver do
  @moduledoc """
  Low-level driver for ELCD LCD modules using Circuits.UART.

  This module handles the UART communication protocol for ELCD LCD displays.
  It implements the command set for controlling LCD operations including
  initialization, text display, cursor control, and screen management.

  ## UART Protocol

  The ELCD modules use a simple UART protocol with the following commands:

  - `0xA0`: Initialize display
  - `0xA3, 0x01`: Clear display
  - `0xA3, 0x0C`: Cursor off
  - `0xA3, 0x0E`: Cursor on
  - `0xA1`: Move cursor (followed by X, Y coordinates)
  - `0xA2`: Print line (followed by text and null terminator)

  ## Error Handling

  All functions return either `:ok` on success or `{:error, reason}` on failure.
  Common error scenarios include:
  - UART communication failures
  - Invalid device paths
  - Hardware not responding
  """

  use GenServer
  alias Circuits.UART
  alias Elcdx.Driver.{Hardware, CursorTracker, TextRenderer}

  @type t :: pid()

  defstruct uart: nil,
            device: nil,
            speed: nil,
            lines: 2,
            columns: 16,
            current_column: 0,
            current_line: 0

  # UART Protocol Commands (defined inline in Hardware module)
  # Configuration
  @default_speed 19200
  @default_lines 2
  @default_columns 16

  # =============================================================================
  # Public API
  # =============================================================================

  @doc """
  Starts the LCD driver process.

  ## Parameters

  - `device`: UART device path
  - `opts`: Configuration options
    - `:speed` - UART baud rate (default: 19200)
    - `:lines` - Number of display lines (default: 2)
    - `:columns` - Number of display columns (default: 16)

  ## Returns

  `{:ok, pid}` on success, `{:error, reason}` on failure.
  """
  @spec start_link(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def start_link(device, opts \\ []) do
    GenServer.start_link(__MODULE__, {device, opts})
  end

  @doc """
  Clears the LCD display.
  """
  @spec clear(t()) :: :ok | {:error, term()}
  def clear(pid) do
    GenServer.call(pid, :clear)
  end

  @doc """
  Moves the cursor to the specified position.

  ## Parameters

  - `pid`: Driver process
  - `column`: Column position (0-based)
  - `line`: Line position (0-based)
  """
  @spec move(t(), non_neg_integer(), non_neg_integer()) :: :ok | {:error, term()}
  def move(pid, column, line) when is_integer(column) and is_integer(line) do
    GenServer.call(pid, {:move, column, line})
  end

  @doc """
  Turns the cursor off.
  """
  @spec cursor_off(t()) :: :ok | {:error, term()}
  def cursor_off(pid) do
    GenServer.call(pid, :cursor_off)
  end

  @doc """
  Turns the cursor on.
  """
  @spec cursor_on(t()) :: :ok | {:error, term()}
  def cursor_on(pid) do
    GenServer.call(pid, :cursor_on)
  end

  @doc """
  Displays text on the LCD with various options.

  ## Parameters

  - `pid`: Driver process
  - `text`: Text to display
  - `opts`: Display options
    - `:show_cursor` - Show cursor (default: false)
    - `:scroll` - Enable scrolling for long text (default: true)
  """
  @spec print(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def print(pid, text, opts \\ []) do
    GenServer.call(pid, {:print, text, opts})
  end

  @doc """
  Stops the driver and closes the UART connection.
  """
  @spec stop(t()) :: :ok
  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  @impl true
  def init({device, opts}) do
    with {:ok, state} <- build_initial_state(device, opts),
         {:ok, uart} <- start_uart_connection(),
         :ok <- open_uart_device(uart, device, state.speed),
         :ok <- initialize_lcd_display(%{state | uart: uart}) do
      final_state = %{state | uart: uart}
      {:ok, final_state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    case Hardware.clear_display(state) do
      :ok ->
        new_state = CursorTracker.reset_position(state)
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:move, column, line}, _from, state) do
    case Hardware.move_cursor(state, column, line) do
      :ok ->
        new_state = CursorTracker.set_position(state, column, line)
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:cursor_off, _from, state) do
    result = Hardware.send_command(state, <<0xA3, 0x0C>>)
    {:reply, result, state}
  end

  def handle_call(:cursor_on, _from, state) do
    result = Hardware.send_command(state, <<0xA3, 0x0E>>)
    {:reply, result, state}
  end

  def handle_call({:print, text, opts}, _from, state) do
    case TextRenderer.print_text(state, text, opts) do
      :ok ->
        new_state = CursorTracker.update_after_print(state, text, opts)
        {:reply, :ok, new_state}
      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:stop, _from, state) do
    UART.close(state.uart)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def terminate(_reason, %{uart: uart}) when is_pid(uart) do
    UART.close(uart)
  end

  def terminate(_reason, _state), do: :ok

  # =============================================================================
  # Initialization Helpers
  # =============================================================================

  defp build_initial_state(device, opts) do
    state = %__MODULE__{
      device: device,
      speed: Keyword.get(opts, :speed, @default_speed),
      lines: Keyword.get(opts, :lines, @default_lines),
      columns: Keyword.get(opts, :columns, @default_columns),
      current_column: 0,
      current_line: 0
    }
    {:ok, state}
  end

  defp start_uart_connection do
    UART.start_link()
  end

  defp open_uart_device(uart, device, speed) do
    UART.open(uart, device, speed: speed, active: false)
  end

  defp initialize_lcd_display(state) do
    with :ok <- Hardware.init_display(state),
         :ok <- Hardware.clear_display(state),
         :ok <- Hardware.move_cursor(state, 0, 0) do
      :ok
    end
  end
end
