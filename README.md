# Elcdx

[![Hex.pm](https://img.shields.io/hexpm/v/elcdx.svg)](https://hex.pm/packages/elcdx)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/elcdx)

**Elixir library for communicating with Lextronic's ELCD module via UART.**

This library provides a simple and efficient interface for controlling Lextronic's LCD display modules that use their ELCD protocol. It supports text display, cursor control, screen management, and scrolling functionality.

## Installation

Add `elcdx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elcdx, "~> 1.0"},
    {:circuits_uart, "~> 1.4"}
  ]
end
```

## Quick Start

```elixir
# Start the LCD connection (/dev/ttyS0 is the Rpi UART, change for your device)
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0")

# Clear the display
Elcdx.clear(lcd)

# Display text
Elcdx.print(lcd, "Hello, World!")

# Move to second line and display more text
Elcdx.move(lcd, 0, 1)
Elcdx.print(lcd, "Line 2 text")

# Enable scrolling for long text
Elcdx.print(lcd, "This is a very long message that will scroll", scroll: true)

# Show cursor
Elcdx.print(lcd, "Cursor visible", show_cursor: true)

# Clean up
Elcdx.stop(lcd)
```

## Configuration

### LCD Sizes

```elixir
# 16x2 LCD (default)
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0")

# 20x4 LCD
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0", lines: 4, columns: 20)

# Custom size
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0", lines: 2, columns: 40)
```

### UART Settings

```elixir
# Full configuration
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0",
  speed: 19200,
  lines: 4,
  columns: 20
)
```

## API Reference

### Connection Management

- `start_link(device, opts \\ [])` - Start LCD connection
- `stop(lcd)` - Stop LCD connection

### Display Control

- `clear(lcd)` - Clear the display
- `move(lcd, column, line)` - Move cursor to position
- `print(lcd, text, opts \\ [])` - Display text

### Cursor Control

- `cursor_on(lcd)` - Show cursor
- `cursor_off(lcd)` - Hide cursor

### Print Options

- `:show_cursor` - Show/hide cursor during text display (default: `false`)
- `:scroll` - Enable scrolling for long text (default: `true`)

## Hardware Setup

### ELCDX Module Connections

```
ELCDX Module    Arduino/Device/Rpi
VCC      <->      5V
GND      <->      GND
RX       <->      TX (UART)
```

### Supported Devices

- USB-to-Serial converters (FT232, CH340, CP2102)
- Arduino boards with UART
- Raspberry Pi UART pins
- Any device with UART capability

## Protocol Details

The ELCDX modules use a simple UART protocol:

| Command | Hex Value | Description |
|---------|-----------|-------------|
| Initialize | `0xA0` | Initialize display |
| Clear | `0xA3 0x01` | Clear display |
| Cursor Off | `0xA3 0x0C` | Hide cursor |
| Cursor On | `0xA3 0x0E` | Show cursor |
| Move | `0xA1 X Y` | Move cursor to (X,Y) |
| Print | `0xA2 text 0x00` | Print text line |

## Error Handling

All functions return either `:ok` or `{:error, reason}`:

```elixir
case Elcdx.print(lcd, "Hello") do
  :ok ->
    IO.puts("Text displayed successfully")
  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

Common error scenarios:
- UART device not found
- Permission denied
- Hardware not responding
- Invalid parameters

## Examples

### Basic Text Display

```elixir
{:ok, lcd} = Elcdx.start_link("/dev/ttyS0")

Elcdx.clear(lcd)
Elcdx.print(lcd, "Temperature: 25°C")
Elcdx.move(lcd, 0, 1)
Elcdx.print(lcd, "Humidity: 60%")
```

### Setup

```bash
git clone https://github.com/Spin42/elcdx.git
cd elcdx
mix deps.get
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass (`mix test`)
6. Run code quality checks (`mix format && mix credo && mix dialyzer`)
7. Commit your changes (`git commit -m 'Add amazing feature'`)
8. Push to the branch (`git push origin feature/amazing-feature`)
9. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.

## Support

- 📖 [Documentation](https://hexdocs.pm/elcdx)
- 🐛 [Report Issues](https://github.com/Spin42/elcdx/issues)

## Acknowledgments

- [Circuits.UART](https://github.com/elixir-circuits/circuits_uart) for UART communication
- [ELCD module documentation from Lextronic](https://www.lextronic.fr/lextronic_doc/ELCD.pdf)
