# icebar

A plugin with a bar for managing which buffers belong in which window.

Written on vacation in Iceland, thus icebar.

## Known limitations

- Buggy with netrw

## Install

Lazy:

```lua
{ "OleJoik/icebar.nvim", opts = { enabled = true } }
```

## Default configuration

```lua
{
  enabled = false,
  skip_filetypes = {
    ["NvimTree"] = true,
    ["neo-tree"] = true,
    ["toggleterm"] = true,
    ["alpha"] = true,
    ["lazy"] = true,
    ["Outline"] = true,
    ["fugitive"] = true,
    ["qf"] = true,
    ["help"] = true,
  },
  float_row_offset = 1,
  float_col_offset = 2,
}
```

## Suggested mappings

```lua
local opts = { noremap = true, silent = true }

function move_buf(direction)
  require("icebar").move_current_buf(direction)
end

vim.keymap.set("n", "<leader>h", function() move_buf("left") end, opts)
vim.keymap.set("n", "<leader>j", function() move_buf("down") end, opts)
vim.keymap.set("n", "<leader>k", function() move_buf("up") end, opts)
vim.keymap.set("n", "<leader>l", function() move_buf("right") end, opts)

vim.keymap.set("n", "<Tab>", function() require("icebar").toggle_buffer_in_window() end, opts)
vim.keymap.set("n", "<C-x>", function() require("icebar").close_buf() end, opts)
```

## Development

To run neovim in a clean slate
```
nvim --clean -u local/nvim.lua .
```
