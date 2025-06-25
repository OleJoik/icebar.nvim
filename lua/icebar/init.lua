---@alias BufferState { buf_id: integer, active: boolean, filename: string, order: number }
---@alias FloatState { win_id: integer, buffer: integer }
---@alias WindowState { buffers: table<string, BufferState|nil>, float: FloatState|nil }
---@alias State { windows: table<string, WindowState|nil> }
local M = {}

---@type State
M._state = { windows = {} }
M._config = {
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

function M.setup(user_config)
  M._config = vim.tbl_deep_extend("force", M._config, user_config or {})
  require("icebar.setup").setup(M._config)
end

function M.state()
  return M._state
end

function M.is_window_registered(win_id)
  local _win_id = win_id
  if _win_id == nil then
    _win_id = vim.api.nvim_get_current_win()
  end

  local w = tostring(_win_id)

  if M._state.windows[w] == nil then
    return false
  end

  return true
end

local function _is_normal_buffer(bufnr)
  if vim.bo[bufnr].buflisted == 0 then
    return false
  end

  -- Skip special buftypes (like terminal, quickfix, etc)
  local buftype = vim.bo[bufnr].buftype
  if buftype ~= "" then
    return false
  end

  local filetype = vim.bo[bufnr].filetype

  if M._config.skip_filetypes[filetype] then
    return false
  end

  return true
end


local function _is_normal_window(win_id)
  return vim.fn.win_gettype(win_id) == ""
end

function M._create_float(win_id)
  local float_buf = vim.api.nvim_create_buf(false, true) -- [listed=false, scratch=true]
  local parent_width = vim.api.nvim_win_get_width(win_id)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {})

  local float_win = vim.api.nvim_open_win(float_buf, false, {
    relative = "win",
    win = win_id,
    anchor = "NE",
    row = -M._config.float_row_offset,
    col = parent_width - M._config.float_col_offset,
    width = 1,
    height = 1,
    focusable = false,
    style = "minimal",
    border = "none"
  })

  vim.api.nvim_set_option_value("number", false, { win = float_win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = float_win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = float_win })
  vim.api.nvim_set_option_value("foldcolumn", "0", { win = float_win })
  vim.api.nvim_set_option_value("cursorline", false, { win = float_win })
  vim.api.nvim_set_option_value("cursorcolumn", false, { win = float_win })
  vim.api.nvim_set_option_value("spell", false, { win = float_win })
  vim.api.nvim_set_option_value("wrap", false, { win = float_win })
  return { win_id = float_win, buffer = float_buf }
end

function M.register(win_id, buf_id)
  if not M._config.enabled then
    return
  end

  if _is_normal_window(win_id) == false then
    return
  end


  if _is_normal_buffer(buf_id) == false then
    return
  end

  local w = tostring(win_id)
  local b = tostring(buf_id)


  local full_name = vim.api.nvim_buf_get_name(buf_id)
  local filename = vim.fn.fnamemodify(full_name, ":t")

  if M._state.windows[w] == nil then
    local float = M._create_float(win_id)
    M._state.windows[w] = {
      buffers = { [b] = { buf_id = buf_id, active = true, filename = filename, order = 0 } },
      float =
          float
    }
  else
    M._state.windows[w].buffers[b] = { buf_id = buf_id, active = true, filename = filename, order = 0 }
  end

  M._set_active(w, b)
end

function M.activate(win_id, buf_id)
  local w = tostring(win_id)
  local b = tostring(buf_id)

  if M._state.windows[w] == nil then
    return
  end

  if M._state.windows[w].buffers[b] == nil then
    return
  end

  M._set_active(w, b)
end

function M.close_win(win_id)
  local w = tostring(win_id)
  if M._state.windows[w] == nil then
    return
  end
  if M._state.windows[w].float ~= nil then
    vim.api.nvim_win_close(M._state.windows[w].float.win_id, true)
  end
  M._state.windows[w] = nil

  vim.api.nvim_win_close(win_id, false)
end

-- TODO: Assumes the window buffer is registered.. Will give index errors if not
function M._set_active(w, b)
  for _, win in pairs(M._state.windows) do
    for _, buf in pairs(win.buffers) do
      buf.active = false
    end
  end


  M._state.windows[w].buffers[b].active = true
  M._state.windows[w].buffers[b].order = 0

  local items = {}
  for key, value in pairs(M._state.windows[w].buffers) do
    table.insert(items, { key = key, order = value.order })
  end

  table.sort(items, function(x, y)
    return x.order < y.order
  end)

  for i, item in ipairs(items) do
    M._state.windows[w].buffers[item.key].order = i
  end

  M.render()
end

function M.update_float_position(win_id)
  local w = tostring(win_id)
  if M._state.windows[w] == nil then
    return
  end

  local parent_width = vim.api.nvim_win_get_width(win_id)
  local float_id = M._state.windows[w].float.win_id
  if float_id == nil then
    return
  end
  local cfg = vim.api.nvim_win_get_config(float_id)
  cfg.col = parent_width
  vim.api.nvim_win_set_config(M._state.windows[w].float.win_id, cfg)
end

function M.render()
  for _, window in pairs(M._state.windows) do
    local bufs = {}
    for _, buf in pairs(window.buffers) do
      if buf.order > 1 then
        table.insert(bufs, { buf_id = buf.buf_id, order = buf.order, filename = buf.filename })
      end
    end

    table.sort(bufs, function(x, y)
      return x.order < y.order
    end)

    local buf_filenames = ""


    local i = 1
    local max_tabs = 3
    local highlights = {}
    for _, buf in ipairs(bufs) do
      if i > max_tabs then break end
      local is_modified = vim.api.nvim_get_option_value("modified", { buf = buf.buf_id })
      local start_col = #buf_filenames
      local highlight_end = start_col + #buf.filename + 4

      buf_filenames = buf_filenames .. "[ " .. buf.filename

      if is_modified then
        buf_filenames = buf_filenames .. " +"
        highlight_end = highlight_end + 2
      end


      buf_filenames = buf_filenames .. " ] "
      table.insert(highlights, { start = start_col, stop = highlight_end })

      i = i + 1
    end


    if #bufs > max_tabs then
      local start_col = #buf_filenames
      buf_filenames = buf_filenames .. "[ ... ]"
      table.insert(highlights, { start = start_col, stop = start_col + start_col + 7 })
    else
      buf_filenames = buf_filenames:sub(1, -2)
    end

    vim.api.nvim_buf_set_lines(window.float.buffer, 0, -1, false, { buf_filenames })
    local cfg = vim.api.nvim_win_get_config(window.float.win_id)
    local column_width = string.len(buf_filenames)
    if column_width > 0 then
      cfg.width = vim.fn.strdisplaywidth(buf_filenames)
    else
      cfg.width = 1
    end

    if vim.api.nvim_win_is_valid(window.float.win_id) then
      vim.api.nvim_win_set_config(window.float.win_id, cfg)
      for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(window.float.buffer, -1, "WinBarNC", 0, hl.start, hl.stop)
      end
    end
  end
end

function M.buf_wipeout(buf_id)
  local b = tostring(buf_id)
  for _, window in pairs(M._state.windows) do
    window.buffers[b] = nil
  end

  M.render()
end

function M.close_buf(win_id, buf_id)
  local _win_id = win_id
  if _win_id == nil then
    _win_id = vim.api.nvim_get_current_win()
  end

  local _buf_id = buf_id
  if _buf_id == nil then
    _buf_id = vim.api.nvim_get_current_buf()
  end

  local w = tostring(_win_id)
  local b = tostring(_buf_id)

  if M._state.windows[w] == nil then
    return
  end

  if M._state.windows[w].buffers[b] == nil then
    return
  end

  M._state.windows[w].buffers[b] = nil

  local is_window_empty = true
  for _ in pairs(M._state.windows[w].buffers) do
    is_window_empty = false
    break
  end

  if is_window_empty then
    vim.cmd("q")
    return
  end


  local lowest_buf = M._find_next_active_buffer(_win_id)
  if lowest_buf ~= nil then
    M._set_active(w, lowest_buf)
    local new_float_buf_id_number_thing = tonumber(lowest_buf)
    if new_float_buf_id_number_thing ~= nil then
      vim.api.nvim_win_set_buf(_win_id, math.floor(new_float_buf_id_number_thing))
    end
  end
end

function M.move_current_buf(direction)
  local wincmd_key = "l"
  local splitcmd = "rightbelow vsplit"
  local oposite_dir_wincmd_key = "h"

  if direction == "right" then
    wincmd_key = "l"
    splitcmd = "rightbelow vsplit"
    oposite_dir_wincmd_key = "h"
  elseif direction == "left" then
    wincmd_key = "h"
    splitcmd = "leftabove vsplit"
    oposite_dir_wincmd_key = "l"
  elseif direction == "up" then
    wincmd_key = "k"
    splitcmd = "aboveleft split"
    oposite_dir_wincmd_key = "j"
  elseif direction == "down" then
    wincmd_key = "j"
    splitcmd = "belowright split"
    oposite_dir_wincmd_key = "k"
  else
    error("Direction " .. direction .. " not recognized")
  end

  local buf_id = vim.api.nvim_get_current_buf()
  local old_win = vim.api.nvim_get_current_win()
  vim.cmd("wincmd " .. wincmd_key)
  local new_win = vim.api.nvim_get_current_win()

  local should_close_window = false
  if new_win == old_win then
    vim.cmd(splitcmd)
    vim.cmd("wincmd " .. wincmd_key)
    new_win = vim.api.nvim_get_current_win()
  else
    if M.is_window_registered(new_win) then
      local buffers_in_new_win = M.buffers_in_window(new_win)
      local buffers_in_old_win = M.buffers_in_window(old_win)
      -- when moving the first buffer to a new window, will keep split
      if buffers_in_new_win ~= nil and buffers_in_new_win > 0 and buffers_in_old_win == 1 then
        should_close_window = true
      end
    elseif _is_normal_window(new_win) == false then
      vim.cmd("wincmd " .. oposite_dir_wincmd_key)
      vim.cmd(splitcmd)
      vim.cmd("wincmd " .. wincmd_key)
      new_win = vim.api.nvim_get_current_win()
    else
      vim.cmd("wincmd " .. oposite_dir_wincmd_key)
    end
  end

  M.register(new_win, buf_id)
  vim.api.nvim_win_set_buf(new_win, buf_id)

  local old_bufs_count = M.buffers_in_window(old_win)
  if old_bufs_count ~= nil and old_bufs_count > 1 then
    M.close_buf(old_win, buf_id)
  end

  if should_close_window then
    M.close_win(old_win)
  end
end

function M.buffers_in_window(win_id)
  local w = tostring(win_id)

  if M._state.windows[w] == nil then
    return nil
  end

  local count = 0
  for _ in pairs(M._state.windows[w].buffers) do
    count = count + 1
  end

  return count
end

function M.is_buffer_in_window(win_id, buf_id)
  local w = tostring(win_id)
  local b = tostring(buf_id)

  if M._state.windows[w] == nil then
    return false
  end

  if M._state.windows[w].buffers[b] == nil then
    return false
  end

  return true
end

function M.toggle_buffer_in_window()
  local win_id = vim.api.nvim_get_current_win()

  if not M.is_window_registered(win_id) then
    return
  end

  local w = tostring(win_id)

  if M._state.windows[w] == nil then
    return
  end

  for b, buf in pairs(M._state.windows[w].buffers) do
    if buf.order == 2 then
      local new_id = tonumber(b)
      if new_id ~= nil then
        vim.api.nvim_win_set_buf(win_id, math.floor(new_id))
      end

      M._set_active(w, b)
      break
    end
  end
end

function M._find_next_active_buffer(win_id)
  local w = tostring(win_id)

  if M._state.windows[w] == nil then
    return nil
  end

  ---@type string?
  local lowest_order_buf_id = nil

  ---@type BufferState?
  local lowest_buf = nil

  for id, buf in pairs(M._state.windows[w].buffers) do
    if lowest_buf == nil then
      lowest_buf = buf
      lowest_order_buf_id = id
    else
      if buf.order < lowest_buf.order then
        lowest_buf = buf
        lowest_order_buf_id = id
      end
    end
  end

  return lowest_order_buf_id
end

return M
