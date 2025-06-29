# icebar

A different take on a tab/bar plugin. I want the tabs to be window local. A bar is created for each window, managing which buffers belong in which window. 

Also some opinionated utilities for creating and closing splits, and easy "moving" of buffers between windows.

Written on vacation in Iceland, thus icebar.

## Limitations

- Will override your winbar. Thus, can't be used with plugins like...
    - dropbar.nvim
    - nvim-navic
    - barbeque.nvim
- Generally buggy behaviour with netrw

## Alternatives

- barbar.nvim
- tabby.nvim
- mini.tabline

## Install

Lazy:

```lua
{ "OleJoik/icebar.nvim", opts = {} }
```

## Default configuration

```lua
{
  skip_filetypes = {
    "NvimTree",
    "neo-tree",
    "toggleterm",
    "alpha",
    "lazy",
    "Outline",
    "fugitive",
    "qf",
    "help",
  },
  float_row_offset = -1,
  float_col_offset = 2,
  padding_left = 10,
  padding_right = 2,
  max_tabs = 3,
  underline = "#587b7b",
  tab_guifg = "#587b7b",
  tab_guibg = "#1d3337",
  bg_guibg = "#152528",
  current_file = "left",       -- left or right
  newest_other_file = "right", -- left or right
  space = "center",            -- left, right or center
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
