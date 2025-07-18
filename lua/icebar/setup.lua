local M = {}

function M.setup(cfg)
  local tab_hl_cmd = "highlight IceBarTab guifg=" .. cfg.tab_guifg .. " guibg=" .. cfg.tab_guibg .. " gui=bold"
  local tab_bg_cmd = "highlight IceBarBackground guifg=" .. cfg.tab_guibg .. " guibg=" .. cfg.bg_guibg .. " gui=bold"


  if cfg.underline ~= nil then
    tab_hl_cmd = tab_hl_cmd .. ",underline guisp=" .. cfg.underline
    tab_bg_cmd = tab_bg_cmd .. ",underline guisp=" .. cfg.underline
  end

  vim.cmd(tab_hl_cmd)
  vim.cmd(tab_bg_cmd)


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
