# nvim-block-markers

A Neovim plugin that automatically adds visual markers for Python code blocks using virtual text. Provides clear visual separation between functions, classes, and decorated definitions with customizable markers.

## Features

- **Automatic Detection**: Automatically enables markers when opening Python files
- **Real-time Updates**: Markers update instantly as you edit code
- **Smart Markers**:
  - `~~~` for function definitions and decorated functions  
  - `###` for class definitions
- **Buffer Management**: Independent state per buffer with automatic cleanup
- **Configurable**: Disable auto-enable and customize trigger events
- **Zero Interference**: Uses virtual text overlay - doesn't modify your files

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "mwil/nvim-block-markers",
  ft = "python",  -- Load only for Python files
  -- Default configuration works out of the box
  -- Optional: customize with opts = { auto_enable = false, events = {...} }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "mwil/nvim-block-markers",
  ft = "python",
  config = function()
    -- Plugin auto-initializes, no setup required
  end,
}
```

### Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/mwil/nvim-block-markers.git ~/.local/share/nvim/site/pack/plugins/start/nvim-block-markers
   ```

2. Restart Neovim

## Requirements

- Neovim ≥ 0.8.0
- Treesitter with Python parser installed:
  ```vim
  :TSInstall python
  ```

## Usage

### Automatic Mode (Default)

The plugin works automatically:

1. **Open any Python file** (`.py` extension or `filetype=python`)
2. **Markers appear automatically** above functions and classes
3. **Edit your code** - markers update in real-time
4. **Switch between buffers** - each maintains independent state

### Manual Commands

Even with auto-mode enabled, you can still control markers manually:

```vim
:BlockMarkerToggle   " Toggle markers on/off for current buffer
:BlockMarkerEnable   " Enable markers for current buffer  
:BlockMarkerDisable  " Disable markers for current buffer
```

## Configuration

### Basic Configuration

#### With Lazy.nvim (Recommended)

```lua
{
  "mwil/nvim-block-markers",
  ft = "python",
  opts = {
    auto_enable = false,  -- Disable automatic mode (manual only)
    events = {            -- Customize refresh events
      "BufWritePost",     -- Only refresh on file save
      "InsertLeave"       -- And when leaving insert mode
    }
  }
}
```

Or using the `config` function:

```lua
{
  "mwil/nvim-block-markers", 
  ft = "python",
  config = function()
    require("nvim-block-markers").setup({
      auto_enable = false,
      events = { "BufWritePost", "InsertLeave" }
    })
  end
}
```

#### Manual Configuration

```lua
-- Access the plugin's configuration after loading
local block_markers = require("nvim-block-markers")

-- Disable automatic enabling (manual mode only)
block_markers.config.auto_enable = false

-- Customize which events trigger marker refresh
block_markers.config.events = {
  "TextChanged",    -- After text changes in Normal mode
  "TextChangedI",   -- After text changes in Insert mode  
  "BufWritePost",   -- After saving the file
  "InsertLeave"     -- When leaving Insert mode
}
```

### Advanced Configuration

```lua
-- Example: Only enable auto-mode for specific projects
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*/my-python-project/*",
  callback = function()
    require("nvim-block-markers").config.auto_enable = true
  end
})

-- Example: Disable auto-mode in certain directories
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*/external-libs/*",
  callback = function()
    require("nvim-block-markers").config.auto_enable = false
  end
})
```

### Keybindings

Add custom keybindings for quick access:

```lua
-- In your init.lua or ftplugin/python.lua
vim.keymap.set("n", "<leader>bt", ":BlockMarkerToggle<CR>", { desc = "Toggle block markers" })
vim.keymap.set("n", "<leader>be", ":BlockMarkerEnable<CR>", { desc = "Enable block markers" })
vim.keymap.set("n", "<leader>bd", ":BlockMarkerDisable<CR>", { desc = "Disable block markers" })
```

## How It Works

The plugin uses Neovim's Treesitter to parse Python code and identify:

- **Function definitions** (`def function_name():`)
- **Decorated functions** (`@decorator def function_name():`)  
- **Class definitions** (`class ClassName:`)

For each detected block, it adds virtual text markers above the definition line (only if the line is empty) using Neovim's extmark API.

### Marker Types

| Code Structure | Marker | Example |
|----------------|--------|---------|
| Function | `~~~...` (100 tildes) | Above `def my_function():` |
| Decorated Function | `~~~...` (100 tildes) | Above `@decorator def func():` |
| Class | `###...` (100 hashes) | Above `class MyClass:` |

## Troubleshooting

### Markers Not Appearing

1. **Check Treesitter**: Ensure Python parser is installed
   ```vim
   :TSInstall python
   :checkhealth treesitter
   ```

2. **Check filetype**: Verify the buffer is detected as Python
   ```vim
   :set filetype?
   ```

3. **Check plugin state**: See if auto-enable is active
   ```vim
   :lua print(require("nvim-block-markers").config.auto_enable)
   ```

### Markers Not Updating

- **Manual refresh**: Use `:BlockMarkerToggle` twice to refresh
- **Check events**: The plugin refreshes on `TextChanged`, `TextChangedI`, `BufWritePost`, and `InsertLeave`
- **File-specific issue**: Try `:edit` to reload the buffer

### Performance Issues

If you experience slowdowns with large files:

```lua
-- Reduce refresh events for better performance
require("nvim-block-markers").config.events = {
  "BufWritePost",  -- Only refresh on save
  "InsertLeave"    -- And when leaving insert mode
}
```

## API Reference

### Configuration

```lua
require("nvim-block-markers").config = {
  auto_enable = true,     -- Auto-enable for Python files
  events = {              -- Events that trigger refresh
    "TextChanged",
    "TextChangedI", 
    "BufWritePost",
    "InsertLeave"
  }
}
```

### Functions

```lua
local markers = require("nvim-block-markers")

-- Enable markers for specific buffer (or current if not specified)
markers:enable_block_markers(bufnr)

-- Disable markers for specific buffer
markers:disable_block_markers(bufnr)

-- Toggle markers for specific buffer  
markers:toggle_block_markers(bufnr)

-- Manually refresh markers (useful after configuration changes)
markers:refresh_block_markers(bufnr)
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test with Python files
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by various code visualization tools
- Built with Neovim's powerful Treesitter and extmark APIs
- Thanks to the Neovim community for excellent documentation