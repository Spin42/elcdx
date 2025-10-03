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

  Since we only support single-line printing without wrapping, the cursor
  position calculation is simplified. The cursor moves forward by the length
  of the printed text, but stays within the current line bounds.

  ## Parameters

  - `state`: The driver state struct
  - `text`: The text that was printed (newlines are ignored)
  - `opts`: Options (scroll setting is considered but doesn't affect position)

  ## Returns

  Updated state with new cursor position.

  ## Behavior

  - Cursor advances by text length within current line
  - Never moves to next line automatically
  - Stops at end of current line if text is truncated
  - Position reflects actual printed characters only
  """
  def update_after_print(state, text, opts) do
    # Remove newlines since we treat text as single-line
    clean_text = String.replace(text, ~r/\r?\n/, " ")
    text_length = String.length(clean_text)
    scroll = Keyword.get(opts, :scroll, true)

    calculate_new_position(state, text_length, scroll)
  end

  # Private helper functions

  defp calculate_new_position(state, text_length, scroll) do
    remaining_space = state.columns - state.current_column

    cond do
      # Text fits completely in remaining space
      text_length <= remaining_space ->
        %{state | current_column: state.current_column + text_length}

      # Text is longer but scrolling is enabled - cursor moves to end of line
      scroll ->
        %{state | current_column: state.columns - 1}

      # Text is longer and scrolling is disabled - cursor moves by truncated length
      true ->
        printed_length = min(text_length, remaining_space)
        %{state | current_column: state.current_column + printed_length}
    end
  end
end
