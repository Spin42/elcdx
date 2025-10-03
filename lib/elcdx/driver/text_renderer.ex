defmodule Elcdx.Driver.TextRenderer do
  @moduledoc """
  Handles text rendering and formatting for the LCD display.

  This module provides comprehensive text rendering capabilities including
  single-line and multi-line text display, text wrapping, horizontal scrolling,
  and various formatting options.

  ## Responsibilities

  - Render text with proper formatting
  - Handle multi-line text display
  - Manage text wrapping and truncation
  - Implement horizontal and vertical scrolling
  - Control cursor visibility during rendering

  ## Features

  - **Text Wrapping**: Automatically wraps text across lines
  - **Horizontal Scrolling**: Scrolls long text horizontally with animation
  - **Vertical Scrolling**: Moves content up when reaching bottom of display
  - **Text Truncation**: Truncates text when scrolling is disabled
  - **Multi-line Support**: Handles text with newline characters
  """

  alias Elcdx.Driver.Hardware

  @doc """
  Main entry point for printing text with various options.

  ## Parameters

  - `state`: The driver state struct
  - `text`: Text to display (can contain newlines)
  - `opts`: Display options
    - `:show_cursor` - Show cursor during display (default: false)
    - `:scroll` - Enable scrolling for long text (default: true)

  ## Returns

  `:ok` on success, `{:error, reason}` on failure.
  """
  def print_text(state, text, opts) do
    show_cursor = Keyword.get(opts, :show_cursor, false)
    scroll = Keyword.get(opts, :scroll, true)

    with :ok <- Hardware.set_cursor_visibility(state, show_cursor) do
      render_text_content(state, text, scroll)
    end
  end

  # Private rendering functions

  defp render_text_content(state, text, scroll) do
    case String.split(text, "\n") do
      [single_line] ->
        print_at_current_position(state, single_line, scroll)
      multiple_lines ->
        print_multiline(state, multiple_lines, scroll)
    end
  end

  defp print_multiline(state, lines, scroll) do
    lines
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {line, index}, _acc ->
      result = print_line_at_position(state, line, index, scroll)

      case result do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp print_line_at_position(state, line, line_index, scroll) do
    if line_index >= state.lines do
      handle_overflow_line(state, line, scroll)
    else
      print_sentence_at_line(state, line, line_index, scroll)
    end
  end

  defp handle_overflow_line(state, line, scroll) do
    # For overflow lines, print on the last available line
    print_sentence_at_line(state, line, state.lines - 1, scroll)
  end

  defp print_sentence_at_line(state, sentence, line, scroll) do
    sentence_length = String.length(sentence)

    cond do
      sentence_length <= state.columns ->
        print_simple_sentence(state, sentence, line)
      scroll ->
        print_with_horizontal_scroll(state, sentence, line)
      true ->
        print_truncated_sentence(state, sentence, line)
    end
  end

  defp print_simple_sentence(state, sentence, line) do
    padded_sentence = String.pad_trailing(sentence, state.columns)

    with :ok <- Hardware.move_cursor(state, 0, line),
         :ok <- Hardware.print_line(state, padded_sentence) do
      :ok
    end
  end

  defp print_with_horizontal_scroll(state, sentence, line) do
    visible_part = String.slice(sentence, 0, state.columns - 1)

    with :ok <- Hardware.move_cursor(state, 0, line),
         :ok <- Hardware.print_line(state, visible_part) do
      Process.sleep(500)
      animate_horizontal_scroll(state, sentence, line)
    end
  end

  defp print_truncated_sentence(state, sentence, line) do
    truncated = String.slice(sentence, 0, state.columns)
    print_simple_sentence(state, truncated, line)
  end

  defp print_at_current_position(state, text, scroll) do
    text_length = String.length(text)
    remaining_space = state.columns - state.current_column

    cond do
      text_fits_on_current_line?(text_length, remaining_space) ->
        Hardware.print_line(state, text)

      scroll ->
        print_with_text_wrapping(state, text, remaining_space)

      true ->
        print_truncated_text(state, text, remaining_space)
    end
  end

  defp text_fits_on_current_line?(text_length, remaining_space) do
    text_length <= remaining_space
  end

  defp print_with_text_wrapping(state, text, remaining_space) do
    if remaining_space > 0 do
      print_text_across_lines(state, text, remaining_space)
    else
      move_to_next_line_and_print(state, text)
    end
  end

  defp print_text_across_lines(state, text, remaining_space) do
    {first_part, rest_part} = split_text_at_position(text, remaining_space)

    with :ok <- Hardware.print_line(state, first_part) do
      handle_text_continuation(state, rest_part)
    end
  end

  defp split_text_at_position(text, position) do
    first_part = String.slice(text, 0, position)
    rest_part = String.slice(text, position, String.length(text) - position)
    {first_part, rest_part}
  end

  defp handle_text_continuation(state, remaining_text) do
    if can_move_to_next_line?(state) do
      move_to_next_line_and_continue(state, remaining_text)
    else
      scroll_and_continue_on_last_line(state, remaining_text)
    end
  end

  defp can_move_to_next_line?(state) do
    state.current_line < state.lines - 1
  end

  defp move_to_next_line_and_continue(state, text) do
    next_line = state.current_line + 1

    with :ok <- Hardware.move_cursor(state, 0, next_line) do
      print_at_current_position(state, text, true)
    end
  end

  defp scroll_and_continue_on_last_line(state, text) do
    with :ok <- scroll_display_up(state),
         :ok <- Hardware.move_cursor(state, 0, state.lines - 1) do
      print_at_current_position(state, text, true)
    end
  end

  defp move_to_next_line_and_print(state, text) do
    if can_move_to_next_line?(state) do
      move_to_next_line_and_continue(state, text)
    else
      scroll_and_continue_on_last_line(state, text)
    end
  end

  defp print_truncated_text(state, text, remaining_space) do
    truncated = String.slice(text, 0, max(0, remaining_space))
    Hardware.print_line(state, truncated)
  end

  defp animate_horizontal_scroll(state, sentence, line) do
    max_scroll = String.length(sentence) - state.columns

    1..max_scroll
    |> Enum.reduce_while(:ok, fn i, _acc ->
      with :ok <- Hardware.move_cursor(state, 0, line) do
        Process.sleep(200)
        visible_part = String.slice(sentence, i, state.columns)

        case Hardware.print_line(state, visible_part) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      else
        error -> {:halt, error}
      end
    end)
  end

  defp scroll_display_up(state) do
    # Simple display scroll implementation
    # Clear both lines (for a 2-line display)
    with :ok <- Hardware.move_cursor(state, 0, 0),
         :ok <- Hardware.print_line(state, String.duplicate(" ", state.columns)),
         :ok <- Hardware.move_cursor(state, 0, 1),
         :ok <- Hardware.print_line(state, String.duplicate(" ", state.columns)) do
      :ok
    end
  end
end
