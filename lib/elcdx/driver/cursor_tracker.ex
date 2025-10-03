defmodule Elcdx.Driver.CursorTracker do
  @moduledoc """
  Handles cursor position tracking and calculations for the LCD display.

  This module manages the current cursor position and provides functions
  to update the position based on various operations like printing text,
  clearing the display, or moving the cursor manually.

  ## Responsibilities

  - Track current cursor position (column, line)
  - Calculate new positions after text printing
  - Handle scrolling vs non-scrolling position calculations
  - Ensure positions stay within display bounds
  """

  @doc """
  Resets the cursor position to the top-left corner (0, 0).

  ## Parameters

  - `state`: The driver state struct

  ## Returns

  Updated state with cursor position reset to (0, 0).
  """
  def reset_position(state) do
    %{state | current_column: 0, current_line: 0}
  end

  @doc """
  Sets the cursor to a specific position.

  ## Parameters

  - `state`: The driver state struct
  - `column`: Column position (0-based)
  - `line`: Line position (0-based)

  ## Returns

  Updated state with new cursor position.
  """
  def set_position(state, column, line) do
    %{state | current_column: column, current_line: line}
  end

  @doc """
  Updates cursor position after printing text.

  Calculates the new cursor position based on the printed text length
  and the current scrolling settings.

  ## Parameters

  - `state`: The driver state struct
  - `text`: The text that was printed
  - `opts`: Options including scroll setting

  ## Returns

  Updated state with new cursor position.
  """
  def update_after_print(state, text, opts) do
    scroll = Keyword.get(opts, :scroll, true)
    text_length = String.length(text)

    calculate_new_position(state, text_length, scroll)
  end

  # Private helper functions

  defp calculate_new_position(state, text_length, scroll) do
    total_position = state.current_column + text_length

    if scroll do
      calculate_with_scroll(state, total_position)
    else
      calculate_without_scroll(state, total_position)
    end
  end

  defp calculate_with_scroll(state, total_position) do
    new_column = rem(total_position, state.columns)
    line_offset = div(total_position, state.columns)
    new_line = min(state.current_line + line_offset, state.lines - 1)

    %{state | current_column: new_column, current_line: new_line}
  end

  defp calculate_without_scroll(state, total_position) do
    max_position = state.lines * state.columns - 1
    clamped_position = min(total_position, max_position)
    new_column = rem(clamped_position, state.columns)
    new_line = div(clamped_position, state.columns)

    %{state | current_column: new_column, current_line: new_line}
  end
end
