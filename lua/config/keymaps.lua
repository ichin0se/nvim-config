-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Split Vertically" })
vim.keymap.set("n", "<leader>ws", "<C-w>s", { desc = "Split Horizontally" })
vim.keymap.set("n", "<leader>we", "<C-w>=", { desc = "Equalize Windows" })
vim.keymap.set("n", "<leader>wc", "<C-w>c", { desc = "Close Window" })

local function open_build_terminal()
  local terminal_info = vim.b.snacks_terminal
  local directory = terminal_info and terminal_info.cwd or LazyVim.root()
  local terminal = Snacks.terminal.get(nil, {
    cwd = directory,
    count = 1,
    win = { position = "bottom", height = 0.3 },
  })
  if terminal then
    terminal:show():focus()
  end
end

vim.keymap.set("n", "<leader>wt", open_build_terminal, { desc = "Build / Run Terminal (Bottom Split)" })
vim.api.nvim_create_user_command("BuildTerminal", open_build_terminal, { desc = "Open Build / Run Terminal" })

vim.keymap.set("n", "<leader>qW", function()
  require("persistence").save()
  vim.notify("Session saved", vim.log.levels.INFO)
end, { desc = "Save Session" })
vim.keymap.set("n", "<leader>uW", function()
  vim.o.list = not vim.o.list
end, { desc = "Toggle Whitespace" })

vim.api.nvim_create_user_command("DevGuide", function()
  vim.cmd.edit(vim.fn.stdpath("config") .. "/README.md")
end, { desc = "Open Development Guide" })
vim.keymap.set("n", "<leader>hD", "<cmd>DevGuide<cr>", { desc = "Development Guide" })
vim.api.nvim_create_user_command("Format", function()
  LazyVim.format({ force = true })
end, { desc = "Format Current Buffer" })
