# icebar

A plugin with a bar for managing which buffers belong in which window.

Written on vacation in Iceland, thus icebar.

## Install

Lazy:

```
{ "OleJoik/icebar.nvim", opts = { enabled = true } }
```

## Default configuration

```
{
  enabled = false,
  skip_filetypes = {
    ["oil"] = true,
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
