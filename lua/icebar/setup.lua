local M = {}
M._registered_path_toggle_keymap = nil
M._augroup = vim.api.nvim_create_augroup("IceBarSetup", { clear = true })

local function _apply_highlights(cfg)
  local tab = {
    fg = cfg.tab_guifg,
    bg = cfg.tab_guibg,
    bold = true,
  }
  local focused = {
    fg = cfg.focused_tab_guifg,
    bg = cfg.focused_tab_guibg,
    bold = true,
  }
  local background = {
    fg = cfg.tab_guibg,
    bg = cfg.bg_guibg,
    bold = true,
  }

  if cfg.underline ~= nil then
    tab.underline = true
    tab.sp = cfg.underline
    background.underline = true
    background.sp = cfg.underline
  end
  if cfg.focused_underline ~= nil then
    focused.underline = true
    focused.sp = cfg.focused_underline
  elseif cfg.underline ~= nil then
    focused.underline = true
    focused.sp = cfg.underline
  end

  vim.api.nvim_set_hl(0, "IceBarTab", tab)
  vim.api.nvim_set_hl(0, "IceBarFocusedTab", focused)
  vim.api.nvim_set_hl(0, "IceBarBackground", background)
end

function M.setup(cfg)
  _apply_highlights(cfg)

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = M._augroup,
    callback = function()
      _apply_highlights(cfg)
      require("icebar").render()
    end,
  })


  vim.api.nvim_create_user_command("IceBar", function()
    print(vim.inspect(require("icebar").state()))
  end, {})

  vim.api.nvim_create_user_command("IceBarCloseBuf", function()
    local win_id = vim.api.nvim_get_current_win()
    local buf_id = vim.api.nvim_get_current_buf()
    require("icebar").close_buf(win_id, buf_id)
  end, {})

  vim.api.nvim_create_user_command("IceBarRender", function()
    require("icebar").render()
  end, {})

  vim.api.nvim_create_user_command("IceBarMoveCurrentBufRight", function()
    require("icebar").move_current_buf("right")
  end, {})

  vim.api.nvim_create_user_command("IceBarTogglePathMode", function()
    require("icebar").toggle_path_mode()
  end, {})

  if M._registered_path_toggle_keymap ~= nil and M._registered_path_toggle_keymap ~= cfg.path_toggle_keymap then
    pcall(vim.keymap.del, "n", M._registered_path_toggle_keymap)
    M._registered_path_toggle_keymap = nil
  end

  if cfg.path_toggle_keymap ~= nil and cfg.path_toggle_keymap ~= "" then
    vim.keymap.set("n", cfg.path_toggle_keymap, function()
      require("icebar").toggle_path_mode()
    end, { noremap = true, silent = true, desc = "IceBar: toggle path mode" })
    M._registered_path_toggle_keymap = cfg.path_toggle_keymap
  end

  vim.api.nvim_create_autocmd({ "VimEnter", "BufWinEnter" }, {
    callback = function()
      if vim.bo.buftype == "" then
        -- Winbar set with autocommand to avoid settings it for neotree, terminals, etc
        vim.wo.winbar = " "
      end
    end,
  })

  -- BufWinEnter doesnt trigger on :split, therefore also WinNew:
  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
    callback = function()
      local win_id = vim.api.nvim_get_current_win()
      local buf_id = vim.api.nvim_get_current_buf()
      require("icebar").register(win_id, buf_id)
    end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    callback = function(args)
      require("icebar").buf_wipeout(args.buf)
    end,
  })


  vim.api.nvim_create_autocmd({ "WinEnter" }, {
    callback = function()
      local win_id = vim.api.nvim_get_current_win()
      local buf_id = vim.api.nvim_get_current_buf()
      require("icebar").activate(win_id, buf_id)
    end,
  })


  vim.api.nvim_create_autocmd({ "BufModifiedSet" }, {
    callback = function()
      require("icebar").render()
    end,
  })


  vim.api.nvim_create_autocmd({ "WinClosed" }, {
    callback = function(args)
      local closing_winid_str = args.file
      local closing_winid = tonumber(closing_winid_str)
      require("icebar").close_win(closing_winid)
    end,
  })


  vim.api.nvim_create_autocmd({ "WinResized", "BufEnter" }, {
    callback = function()
      require("icebar").render()
      -- local windows = vim.v.event.windows or {}
      -- for _, winid in ipairs(windows) do
      --   require("icebar").update_float_position(winid)
      -- end
    end,
  })
end

return M
