-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.autoformat = true
vim.g.lazyvim_python_lsp = "basedpyright"
vim.g.lazyvim_python_ruff = "ruff"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.cursorlineopt = "both"
vim.opt.signcolumn = "yes"
vim.opt.list = true
vim.opt.listchars = { tab = "» ", space = "·", trail = "·", nbsp = "␣", extends = "›", precedes = "‹" }
vim.opt.hidden = true
vim.opt.confirm = true
vim.opt.autoread = true
vim.opt.updatetime = 250
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.undofile = true
vim.opt.undolevels = 10000
vim.opt.swapfile = true
vim.opt.writebackup = true
vim.opt.backup = true
vim.opt.sessionoptions = { "buffers", "curdir", "folds", "help", "tabpages", "winsize", "winpos" }

for _, directory in ipairs({ "undo", "swap", "backup" }) do
  local path = vim.fn.stdpath("state") .. "/" .. directory
  vim.fn.mkdir(path, "p")
  vim.opt[directory == "undo" and "undodir" or directory == "swap" and "directory" or "backupdir"] = path .. "//"
end

if vim.fn.has("win32") == 1 then
  vim.cmd.language("ctype .UTF-8")
end

local python_candidates = {
  vim.env.NVIM_PYTHON3_HOST_PROG or "",
  vim.fn.stdpath("data") .. "/python-provider/" .. (vim.fn.has("win32") == 1 and "Scripts/python.exe" or "bin/python"),
}

if vim.fn.has("win32") == 1 and vim.env.LOCALAPPDATA then
  for _, pattern in ipairs({ "/Python/pythoncore-*/python.exe", "/Programs/Python/Python*/python.exe" }) do
    vim.list_extend(python_candidates, vim.fn.glob(vim.env.LOCALAPPDATA .. pattern, false, true))
  end
end

vim.list_extend(python_candidates, { vim.fn.exepath("python3"), vim.fn.exepath("python") })
for _, python in ipairs(python_candidates) do
  if python ~= "" and not python:lower():find("windowsapps", 1, true) and vim.fn.executable(python) == 1 then
    local available, result = pcall(function()
      return vim.system({ python, "-c", "import pynvim" }, { text = true }):wait(3000)
    end)
    if available and result.code == 0 then
      vim.g.python3_host_prog = python
      break
    end
  end
end
