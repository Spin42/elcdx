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

  @type t :: pid()

  defstruct uart: nil,
            device: nil,
            speed: nil,
            lines: 2,
            columns: 16,
            current_column: 0,
            current_line: 0

  # UART Protocol Commands
  @init_cmd <<0xA0>>
  @clear_cmd <<0xA3, 0x01>>
  @cursor_off_cmd <<0xA3, 0x0C>>
  @cursor_on_cmd <<0xA3, 0x0E>>
  @move_cmd <<0xA1>>
  @print_line_cmd <<0xA2>>

  # Configuration
  @default_speed 19200
  @default_lines 2
  @default_columns 16
  @init_delay 600

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
    speed = Keyword.get(opts, :speed, @default_speed)
    lines = Keyword.get(opts, :lines, @default_lines)
    columns = Keyword.get(opts, :columns, @default_columns)

    case UART.start_link() do
      {:ok, uart} ->
        case UART.open(uart, device, speed: speed, active: false) do
          :ok ->
            state = %__MODULE__{
              uart: uart,
              device: device,
              speed: speed,
              lines: lines,
              columns: columns,
              current_column: 0,
              current_line: 0
            }

            case init_display(state) do
              :ok ->
                clear_display(state)
                move_cursor(state, 0, 0)
                {:ok, state}

              {:error, reason} ->
                UART.close(uart)
                {:stop, reason}
            end

          {:error, reason} ->
            {:stop, reason}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:clear, _from, state) do
    result = clear_display(state)
    # Reset cursor position after clear
    new_state = case result do
      :ok -> %{state | current_column: 0, current_line: 0}
      {:error, _} -> state
    end
    {:reply, result, new_state}
  end

  def handle_call({:move, column, line}, _from, state) do
    result = move_cursor(state, column, line)
    new_state = case result do
      :ok -> %{state | current_column: column, current_line: line}
      {:error, _} -> state
    end
    {:reply, result, new_state}
  end

  def handle_call(:cursor_off, _from, state) do
    result = send_command(state, @cursor_off_cmd)
    {:reply, result, state}
  end

  def handle_call(:cursor_on, _from, state) do
    result = send_command(state, @cursor_on_cmd)
    {:reply, result, state}
  end

  def handle_call({:print, text, opts}, _from, state) do
    result = print_text(state, text, opts)

    # Update cursor position after printing
    new_state = case result do
      :ok ->
        # Calculate new position after printing
        text_length = String.length(text)
        new_column = rem(state.current_column + text_length, state.columns)
        new_line = state.current_line + div(state.current_column + text_length, state.columns)
        new_line = min(new_line, state.lines - 1)
        %{state | current_column: new_column, current_line: new_line}

      {:error, _} -> state
    end

    {:reply, result, new_state}
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

  defp init_display(%__MODULE__{uart: uart}) do
    case UART.write(uart, @init_cmd) do
      :ok ->
        Process.sleep(@init_delay)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp clear_display(%__MODULE__{} = state) do
    send_command(state, @clear_cmd)
  end

  defp move_cursor(%__MODULE__{uart: uart}, column, line) do
    with :ok <- UART.write(uart, @move_cmd),
         :ok <- UART.write(uart, <<column>>),
         :ok <- UART.write(uart, <<line>>) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp send_command(%__MODULE__{uart: uart}, command) do
    UART.write(uart, command)
  end

  defp print_text(state, text, opts) do
    show_cursor = Keyword.get(opts, :show_cursor, false)
    scroll = Keyword.get(opts, :scroll, true)

    with :ok <- set_cursor_visibility(state, show_cursor) do
      sentences = String.split(text, "\n")

      if length(sentences) > 1 do
        print_multiline(state, sentences, scroll)
      else
        # For simple text, use current cursor position
        print_at_current_position(state, List.first(sentences), scroll)
      end
    end
  end

  defp set_cursor_visibility(state, true), do: send_command(state, @cursor_on_cmd)
  defp set_cursor_visibility(state, false), do: send_command(state, @cursor_off_cmd)

  defp print_multiline(state, sentences, scroll) do
    Enum.with_index(sentences)
    |> Enum.reduce_while(:ok, fn {sentence, line}, _acc ->
      result =
        if line >= state.lines do
          with :ok <- print_sentence(state, Enum.at(sentences, line - 1), 0, scroll),
               :ok <- print_sentence(state, sentence, 1, scroll) do
            :ok
          end
        else
          print_sentence(state, sentence, line, scroll)
        end

      case result do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp print_line(%__MODULE__{uart: uart}, sentence) do
    with :ok <- UART.write(uart, @print_line_cmd),
         :ok <- UART.write(uart, sentence),
         :ok <- UART.write(uart, <<0x00>>) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp print_sentence(state, sentence, line, scroll) do
    cond do
      !scroll or String.length(sentence) <= state.columns ->
        with :ok <- move_cursor(state, 0, line),
             :ok <- print_line(state, String.pad_trailing(sentence, state.columns)) do
          :ok
        end

      scroll ->
        with :ok <- move_cursor(state, 0, line),
             :ok <- print_line(state, String.slice(sentence, 0, state.columns - 1)) do
          Process.sleep(500)
          scroll_text(state, sentence, line)
        end
    end
  end

  defp print_at_current_position(state, sentence, scroll) do
    cond do
      # If text fits in remaining space on current line
      !scroll or String.length(sentence) + state.current_column <= state.columns ->
        print_line(state, sentence)

      # If text is too long and we need to scroll
      scroll ->
        # Print what fits on current line
        remaining_space = state.columns - state.current_column
        if remaining_space > 0 do
          first_part = String.slice(sentence, 0, remaining_space)
          rest_part = String.slice(sentence, remaining_space, String.length(sentence))

          with :ok <- print_line(state, first_part) do
            # Continue on next line or scroll
            next_line = min(state.current_line + 1, state.lines - 1)
            with :ok <- move_cursor(state, 0, next_line) do
              print_at_current_position(%{state | current_column: 0, current_line: next_line}, rest_part, scroll)
            end
          end
        else
          # No space on current line, move to next
          next_line = min(state.current_line + 1, state.lines - 1)
          with :ok <- move_cursor(state, 0, next_line) do
            print_at_current_position(%{state | current_column: 0, current_line: next_line}, sentence, scroll)
          end
        end

      # No scroll, truncate text
      true ->
        remaining_space = state.columns - state.current_column
        truncated = String.slice(sentence, 0, max(0, remaining_space))
        print_line(state, truncated)
    end
  end

  defp scroll_text(state, sentence, line) do
    max_scroll = String.length(sentence) - state.columns

    Enum.reduce_while(1..max_scroll, :ok, fn i, _acc ->
      case move_cursor(state, 0, line) do
        :ok ->
          Process.sleep(200)
          case print_line(state, String.slice(sentence, i, state.columns)) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end
end
