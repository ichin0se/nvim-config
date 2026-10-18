-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local development_group = vim.api.nvim_create_augroup("DevelopmentWorkspace", { clear = true })
pcall(vim.api.nvim_del_augroup_by_name, "lazyvim_checktime")

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermLeave", "TermClose" }, {
  group = development_group,
  callback = function()
    if vim.fn.getcmdwintype() ~= "" or vim.fn.mode():find("^[ciR!]") then
      return
    end
    for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
      if
        vim.api.nvim_buf_is_loaded(buffer)
        and vim.bo[buffer].buftype == ""
        and not vim.bo[buffer].modified
        and vim.api.nvim_buf_get_name(buffer) ~= ""
      then
        pcall(vim.cmd, "silent! checktime " .. buffer)
      end
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = development_group,
  pattern = "python",
  callback = function()
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.tabstop = 4
  end,
})
