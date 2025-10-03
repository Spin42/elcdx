# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-10-03

### Added
- Updated documentation

## [0.1.0] - 2025-10-03

### Added
- Initial release of Elcdx library
- Complete UART communication driver for ELCDX LCD modules
- Support for multiple LCD sizes (16x2, 20x4, custom)
- Text display with automatic line wrapping
- Cursor control (show/hide, positioning)
- Screen management (clear, move cursor)
- Scrolling text functionality for long messages
- Robust error handling with proper return values
- GenServer-based asynchronous operation
- Comprehensive documentation with examples
- Hardware-in-the-loop testing support
- Type specifications for all public functions

### Features
- **Connection Management**: Start/stop LCD connections with configurable UART settings
- **Display Control**: Clear display, move cursor, print text with various options
- **Text Rendering**: Support for multiline text, scrolling, and cursor visibility
- **Error Handling**: All functions return `:ok` or `{:error, reason}` tuples
- **Documentation**: Complete API documentation with examples and protocol details

### Protocol Support
- Initialize display (`0xA0`)
- Clear display (`0xA3 0x01`)
- Cursor control (`0xA3 0x0C`/`0x0E`)
- Cursor positioning (`0xA1 X Y`)
- Text output (`0xA2 text 0x00`)

### Dependencies
- `circuits_uart ~> 1.4` for UART communication
- `ex_doc ~> 0.29` for documentation generation (dev only)
