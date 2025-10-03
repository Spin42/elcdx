defmodule Elcdx.Driver.TextRenderer do
  @moduledoc """
  Handles text rendering and formatting for the LCD display.

  This module provides single-line text rendering with horizontal scrolling
  for text that exceeds the display width. Multi-line rendering and text
  wrapping have been removed to keep the implementation simple and focused.

  ## Responsibilities

  - Render text at current cursor position
  - Handle horizontal scrolling for long text
  - Control cursor visibility during rendering
  - Truncate text when scrolling is disabled

  ## Features

  - **Single-line Rendering**: Text is rendered at current cursor position only
  - **Horizontal Scrolling**: Long text scrolls horizontally with animation
  - **Text Truncation**: Truncates text when scrolling is disabled
  - **No Multi-line**: Text never wraps or moves to next line
  """

  alias Elcdx.Driver.Hardware

  @doc """
  Main entry point for printing text with options.

  Text is always rendered at the current cursor position. If the text is longer
  than the remaining space on the current line, it will either scroll horizontally
  (if scroll is enabled) or be truncated (if scroll is disabled).

  ## Parameters

  - `state`: The driver state struct
  - `text`: Text to display (single line only, newlines ignored)
  - `opts`: Display options
    - `:show_cursor` - Show cursor during display (default: false)
    - `:scroll` - Enable horizontal scrolling for long text (default: true)

  ## Returns

  `:ok` on success, `{:error, reason}` on failure.

  ## Behavior

  - Text longer than remaining space will scroll horizontally if `:scroll` is true
  - Text longer than remaining space will be truncated if `:scroll` is false
  - Newline characters in text are ignored (treated as regular characters)
  - Cursor position is not automatically advanced to next line
  """
  def print_text(state, text, opts) do
    show_cursor = Keyword.get(opts, :show_cursor, false)
    scroll = Keyword.get(opts, :scroll, true)

    # Remove any newlines to ensure single-line behavior
    clean_text = String.replace(text, ~r/\r?\n/, " ")

    with :ok <- Hardware.set_cursor_visibility(state, show_cursor) do
      render_single_line_text(state, clean_text, scroll)
    end
  end

  # Private rendering functions

  defp render_single_line_text(state, text, scroll) do
    text_length = String.length(text)
    remaining_space = state.columns - state.current_column

    cond do
      # Text fits in remaining space - print directly
      text_length <= remaining_space ->
        Hardware.print_line(state, text)

      # Text is too long and scrolling is enabled - animate horizontal scroll
      scroll ->
        animate_horizontal_scroll_at_cursor(state, text)

      # Text is too long and scrolling is disabled - truncate
      true ->
        truncated = String.slice(text, 0, remaining_space)
        Hardware.print_line(state, truncated)
    end
  end

  defp animate_horizontal_scroll_at_cursor(state, text) do
    remaining_space = state.columns - state.current_column
    text_length = String.length(text)

    # If there's no space left, don't print anything
    if remaining_space <= 0 do
      :ok
    else
      # Calculate how many scroll positions we need
      max_scroll = text_length - remaining_space

      # Start by showing the beginning of the text
      initial_part = String.slice(text, 0, remaining_space)
      with :ok <- Hardware.print_line(state, initial_part) do
        if max_scroll > 0 do
          Process.sleep(500)  # Pause before scrolling starts
          scroll_text_horizontally(state, text, remaining_space, max_scroll)
        else
          :ok
        end
      end
    end
  end

  defp scroll_text_horizontally(state, text, display_width, max_scroll) do
    # Move cursor back to starting position for scrolling animation
    current_line = state.current_line
    start_column = state.current_column

    1..max_scroll
    |> Enum.reduce_while(:ok, fn i, _acc ->
      with :ok <- Hardware.move_cursor(state, start_column, current_line) do
        Process.sleep(200)  # Scroll speed
        visible_part = String.slice(text, i, display_width)

        case Hardware.print_line(state, visible_part) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      else
        error -> {:halt, error}
      end
    end)
  end
end
