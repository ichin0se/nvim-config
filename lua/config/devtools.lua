local M = {}

local function project_root()
  local terminal = vim.b.snacks_terminal
  return terminal and terminal.cwd or LazyVim.root()
end

local function toggle_terminal(command, title)
  local executable = vim.fn.exepath(command[1])
  if executable == "" then
    vim.notify(command[1] .. " is not installed or is not on PATH", vim.log.levels.WARN, { title = title })
    return
  end
  local arguments = vim.deepcopy(command)
  arguments[1] = executable
  Snacks.terminal.toggle(arguments, {
    cwd = project_root(),
    count = 1,
    win = { position = "float", width = 0.9, height = 0.9, title = title },
  })
end

local function current_file()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.bo.buftype ~= "" then
    vim.notify("Open a file first", vim.log.levels.WARN, { title = "Development Tools" })
    return
  end
  return path
end

function M.codex()
  toggle_terminal({ "codex" }, "Codex")
end

function M.codex_resume()
  toggle_terminal({ "codex", "resume" }, "Codex Resume")
end

function M.copy_file_path()
  local path = current_file()
  if path then
    vim.fn.setreg("+", path)
    vim.notify("File path copied to clipboard", vim.log.levels.INFO, { title = "Codex" })
  end
end

function M.gitui()
  toggle_terminal({ "gitui" }, "GitUI")
end

function M.diffview()
  require("diffview").open({ "-C" .. project_root() })
end

function M.file_history()
  local path = current_file()
  if path then
    require("diffview").file_history(nil, { "-C" .. project_root(), path })
  end
end

return M
