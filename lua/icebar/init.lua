---@alias BufferState { buf_id: integer, active: boolean, filename: string, order: number, path: string, last_active: number }
---@alias FloatState { win_id: integer, buffer: integer }
---@alias ClickTarget { start: integer, stop: integer, action: "close", buf_id: integer }
---@alias WindowState { win_id: integer, buffers: table<string, BufferState|nil>, float: FloatState|nil, click_targets: ClickTarget[]|nil }
---@alias State { windows: table<string, WindowState|nil> }
local M = {}

---@type State
M._state = { windows = {} }
M._config = {
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
  underline = "#587b7b", -- color or nil
  tab_guifg = "#587b7b",
  tab_guibg = "#1d3337",
  bg_guibg = "#152528",
  current_file = "left",       -- left or right
  newest_other_file = "right", -- left or right
  space = "center",            -- left, right or center
  current_file_display = "path", -- path or name
  reorder_on_focus = true,
  focused_tab_guifg = "#d7ffff",
  focused_tab_guibg = "#2b4c52",
  focused_underline = nil, -- color or nil; falls back to underline
  path_toggle_keymap = nil,
  show_path_toggle_hint = true,
  show_close_button = false,
  close_button_symbol = "×",
}
M._active_counter = 0
M._path_only_mode = false

M._skip_filetypes = {}

function M.setup(user_config)
  if user_config ~= nil and user_config.current_file_focus ~= nil and user_config.current_file_display == nil then
    user_config.current_file_display = user_config.current_file_focus
  end
  M._config = vim.tbl_deep_extend("force", M._config, user_config or {})
  require("icebar.setup").setup(M._config)


  M._skip_filetypes = {}
  for _, ft in ipairs(M._config.skip_filetypes) do
    M._skip_filetypes[ft] = true
  end
end

local function _next_buffer_order(win_id)
  local w = tostring(win_id)
  local win = M._state.windows[w]
  if win == nil then
    return 0
  end

  local max_order = -1
  for _, buf in pairs(win.buffers) do
    if buf.order > max_order then
      max_order = buf.order
    end
  end

  return max_order + 1
end

function M.state()
  return M._state
end

local function _path_relative_to_cwd(path)
  local oil_path = vim.fn.fnamemodify(path, "%:p"):gsub("^oil://", "")
  return vim.fn.fnamemodify(oil_path, ":.")
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

  if M._skip_filetypes[filetype] then
    return false
  end

  return true
end


local function _is_normal_window(win_id)
  return vim.fn.win_gettype(win_id) == ""
end

local function _window_total_width(win_id)
  local width = vim.api.nvim_win_get_width(win_id)
  local info = vim.fn.getwininfo(win_id)
  if type(info) == "table" and info[1] ~= nil and type(info[1].textoff) == "number" then
    width = width + info[1].textoff
  end
  if width < 1 then
    width = 1
  end

  return width
end

local function _window_textoff(win_id)
  local info = vim.fn.getwininfo(win_id)
  if type(info) == "table" and info[1] ~= nil and type(info[1].textoff) == "number" then
    return info[1].textoff
  end

  return 0
end

local function _float_layout(win_id)
  local textoff = _window_textoff(win_id)
  local col = -textoff + M._config.float_col_offset
  local width = _window_total_width(win_id) - M._config.float_col_offset
  if width < 1 then
    width = 1
  end

  return {
    col = col,
    width = width,
  }
end

function M._create_float(win_id)
  local float_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {})
  local layout = _float_layout(win_id)

  local float_win = vim.api.nvim_open_win(float_buf, false, {
    relative = "win",
    win = win_id,
    anchor = "NW",
    row = M._config.float_row_offset,
    col = layout.col,
    width = layout.width,
    height = 1,
    focusable = true,
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

  vim.keymap.set("n", "<LeftMouse>", function()
    require("icebar").handle_float_click()
  end, { buffer = float_buf, noremap = true, silent = true, nowait = true })

  return { win_id = float_win, buffer = float_buf }
end

function M.handle_float_click()
  local mouse = vim.fn.getmousepos()
  local float_win_id = mouse.winid
  local col = mouse.column - 1

  if float_win_id == nil or col < 0 then
    return
  end

  for _, window in pairs(M._state.windows) do
    if window.float ~= nil and window.float.win_id == float_win_id then
      for _, target in ipairs(window.click_targets or {}) do
        if col >= target.start and col < target.stop then
          if target.action == "close" then
            M.close_buf(window.win_id, target.buf_id)
          end
          return
        end
      end
      return
    end
  end
end

function M.handle_float_focus(win_id)
  local target_win_id = win_id or vim.api.nvim_get_current_win()
  for _, window in pairs(M._state.windows) do
    if window.float ~= nil and window.float.win_id == target_win_id then
      M.handle_float_click()
      if vim.api.nvim_win_is_valid(window.win_id) then
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(window.win_id) then
            vim.api.nvim_set_current_win(window.win_id)
          end
        end)
      end
      return true
    end
  end

  return false
end

function M.register(win_id, buf_id)
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
      buffers = { [b] = { buf_id = buf_id, active = true, filename = filename, order = 0, path = full_name, last_active = 0 } },
      float = float,
      win_id = win_id
    }
  else
    local existing = M._state.windows[w].buffers[b]
    local order = _next_buffer_order(win_id)
    if existing ~= nil then
      order = existing.order
    end

    local last_active = 0
    if existing ~= nil then
      last_active = existing.last_active or 0
    end

    M._state.windows[w].buffers[b] = {
      buf_id = buf_id,
      active = true,
      filename = filename,
      order = order,
      path = full_name,
      last_active = last_active
    }
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
  local target_window = M._state.windows[w]
  if target_window == nil then
    return
  end

  for _, buf in pairs(target_window.buffers) do
    buf.active = false
  end

  if target_window.buffers[b] == nil then
    return
  end

  target_window.buffers[b].active = true
  M._active_counter = M._active_counter + 1
  target_window.buffers[b].last_active = M._active_counter

  if M._config.reorder_on_focus then
    target_window.buffers[b].order = 0

    local items = {}
    for key, value in pairs(target_window.buffers) do
      table.insert(items, { key = key, order = value.order })
    end

    table.sort(items, function(x, y)
      return x.order < y.order
    end)

    for i, item in ipairs(items) do
      target_window.buffers[item.key].order = i
    end
  end

  M.render()
end

function M.render()
  for _, window in pairs(M._state.windows) do
    window.click_targets = {}
    local bufs = {}
    for _, buf in pairs(window.buffers) do
      table.insert(bufs, {
        buf_id = buf.buf_id,
        order = buf.order,
        filename = buf.filename,
        path = buf.path,
        active = buf.active
      })
    end

    local current_file = ""
    local current_file_highlight = nil
    local active_buf_id = nil
    if #bufs > 0 then
      local current_index = 1
      for idx, buf in ipairs(bufs) do
        if buf.active then
          current_index = idx
          break
        end
      end

      local first = bufs[current_index]
      active_buf_id = first.buf_id
      if M._config.reorder_on_focus or M._path_only_mode then
        table.remove(bufs, current_index)
      end

      local cwd = vim.fn.getcwd()
      local cwd_basename = vim.fn.fnamemodify(cwd, ':t')

      local rel_path = _path_relative_to_cwd(first.path)

      if not rel_path:match("^[/~]") and rel_path ~= "" then
        rel_path = "/" .. rel_path
      end
      if rel_path == '' or rel_path == '.' then
        rel_path = ''
      end

      local is_modified = vim.api.nvim_get_option_value("modified", { buf = first.buf_id })
      local current_label = cwd_basename .. rel_path
      if M._config.current_file_display == "name" then
        current_label = first.filename
      elseif M._config.current_file_display ~= "path" then
        error("current_file_display must be 'path' or 'name'")
      end

      if M._path_only_mode then
        current_label = _path_relative_to_cwd(first.path)
      end

      if M._config.reorder_on_focus or M._path_only_mode then
        current_file = "  " .. current_label

        if is_modified then
          current_file = current_file .. " +"
        end

        if M._config.show_close_button then
          current_file = current_file .. " " .. M._config.close_button_symbol
        end

        current_file = current_file .. "  "
        current_file_highlight = "IceBarFocusedTab"
      end
    end

    if M._path_only_mode then
      bufs = {}
    end

    table.sort(bufs, function(x, y)
      if M._config.newest_other_file == "left" then
        return x.order > y.order
      elseif M._config.newest_other_file == "right" then
        return x.order < y.order
      else
        error("newest_other_file must be 'left' or 'right'")
      end
    end)

    local i = 0
    local other_filenames = ""
    local other_highlights = {}

    for _, buf in ipairs(bufs) do
      if i > M._config.max_tabs then break end

      if buf.filename ~= "" then -- This filters out temporary buffers such as oils buffers (without a name)
        local highlight_start = #other_filenames
        local tab_label = buf.filename
        local highlight_end = highlight_start + #tab_label + 4

        other_filenames = other_filenames .. "  " .. tab_label

        if vim.api.nvim_get_option_value("modified", { buf = buf.buf_id }) then
          other_filenames = other_filenames .. " +"
          highlight_end = highlight_end + 2
        end

        if M._config.show_close_button then
          other_filenames = other_filenames .. " " .. M._config.close_button_symbol
          highlight_end = highlight_end + #M._config.close_button_symbol + 1
        end

        other_filenames = other_filenames .. "   "
        local group = "IceBarTab"
        if active_buf_id ~= nil and buf.buf_id == active_buf_id then
          group = "IceBarFocusedTab"
        end

        table.insert(other_highlights, { start = highlight_start, stop = highlight_end, group = group, buf_id = buf.buf_id })
        i = i + 1
      end
    end

    local keymap_hint = ""
    if M._config.show_path_toggle_hint and M._config.path_toggle_keymap ~= nil and M._config.path_toggle_keymap ~= "" then
      keymap_hint = " [" .. M._config.path_toggle_keymap .. "] "
    end

    local highlights = {}
    local effective_padding_left = M._config.padding_left - _window_textoff(window.win_id)
    if effective_padding_left < 0 then
      effective_padding_left = 0
    end
    local buf_filenames = (" "):rep(effective_padding_left)

    local width = _window_total_width(window.win_id) - M._config.float_col_offset
    if width < 1 then
      width = 1
    end
    local space_len = width - effective_padding_left - #current_file - #other_filenames - #keymap_hint -
        M._config.padding_right
    if space_len < 0 then
      space_len = 0
    end
    local space = (" "):rep(space_len)

    if M._config.space == "left" then
      buf_filenames = buf_filenames .. space
    end

    if current_file ~= "" and M._config.current_file == "left" then
      local start_col = #buf_filenames
      buf_filenames = buf_filenames .. current_file
      local highlight_end = start_col + #current_file
      table.insert(highlights, { start = start_col, stop = highlight_end, group = current_file_highlight })
      if M._config.show_close_button and active_buf_id ~= nil then
        local close_button_span = " " .. M._config.close_button_symbol
        local close_start = highlight_end - 2 - #close_button_span
        local close_stop = close_start + #close_button_span
        table.insert(window.click_targets, {
          start = close_start,
          stop = close_stop,
          action = "close",
          buf_id = active_buf_id,
        })
      end
      buf_filenames = buf_filenames .. " "

      if M._config.space == "center" then
        buf_filenames = buf_filenames .. space
      end
    end


    local others_starting = #buf_filenames
    buf_filenames = buf_filenames .. other_filenames
    for _, h in ipairs(other_highlights) do
      table.insert(highlights, { start = others_starting + h.start, stop = others_starting + h.stop, group = h.group })
      if M._config.show_close_button then
        local close_button_span = " " .. M._config.close_button_symbol
        local close_stop = others_starting + h.stop - 2
        local close_start = close_stop - #close_button_span
        table.insert(window.click_targets, {
          start = close_start,
          stop = close_stop,
          action = "close",
          buf_id = h.buf_id,
        })
      end
    end


    if current_file ~= "" and M._config.current_file == "right" then
      if M._config.space == "center" then
        buf_filenames = buf_filenames .. space
      end

      local start_col = #buf_filenames
      buf_filenames = buf_filenames .. current_file
      local highlight_end = start_col + #current_file
      table.insert(highlights, { start = start_col, stop = highlight_end, group = current_file_highlight })
      if M._config.show_close_button and active_buf_id ~= nil then
        local close_button_span = " " .. M._config.close_button_symbol
        local close_start = highlight_end - 2 - #close_button_span
        local close_stop = close_start + #close_button_span
        table.insert(window.click_targets, {
          start = close_start,
          stop = close_stop,
          action = "close",
          buf_id = active_buf_id,
        })
      end
      buf_filenames = buf_filenames .. " "
    end

    -- if i > M._config.max_tabs then
    --   local start_col = #buf_filenames
    --   buf_filenames = buf_filenames .. "[ ... ]"
    --   table.insert(highlights, { start = start_col, stop = start_col + 7 })
    -- else
    --   buf_filenames = buf_filenames:sub(1, -2)
    -- end

    if M._config.space == "right" then
      buf_filenames = buf_filenames .. space
    end

    buf_filenames = buf_filenames .. keymap_hint
    buf_filenames = buf_filenames .. (" "):rep(M._config.padding_right)
    local missing_right = width - #buf_filenames
    if missing_right > 0 then
      buf_filenames = buf_filenames .. (" "):rep(missing_right)
    elseif missing_right < 0 then
      buf_filenames = buf_filenames:sub(1, width)
    end

    vim.api.nvim_buf_set_lines(window.float.buffer, 0, -1, false, { buf_filenames })
    local cfg = vim.api.nvim_win_get_config(window.float.win_id)
    local layout = _float_layout(window.win_id)
    cfg.col = layout.col
    cfg.width = layout.width

    vim.api.nvim_buf_add_highlight(window.float.buffer, -1, "IceBarBackground", 0, 0, -1)
    if vim.api.nvim_win_is_valid(window.float.win_id) then
      vim.api.nvim_win_set_config(window.float.win_id, cfg)
      for _, hl in ipairs(highlights) do
        local group = hl.group or "IceBarTab"
        vim.api.nvim_buf_add_highlight(window.float.buffer, -1, group, 0, hl.start, hl.stop)
      end
    end
  end
end

function M.toggle_path_mode()
  M._path_only_mode = not M._path_only_mode
  M.render()
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
    M.close_win(_win_id)
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
      -- when moving the first buffer to a new window, will keep split. Otherwise, collapse
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
  local most_recent_buf_id = nil

  ---@type BufferState?
  local most_recent_buf = nil

  for id, buf in pairs(M._state.windows[w].buffers) do
    if most_recent_buf == nil then
      most_recent_buf = buf
      most_recent_buf_id = id
    else
      local current_last_active = most_recent_buf.last_active or 0
      local candidate_last_active = buf.last_active or 0

      if candidate_last_active > current_last_active then
        most_recent_buf = buf
        most_recent_buf_id = id
      elseif candidate_last_active == current_last_active and buf.order < most_recent_buf.order then
        most_recent_buf = buf
        most_recent_buf_id = id
      end
    end
  end

  return most_recent_buf_id
end

return M
