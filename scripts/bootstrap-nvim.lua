local config = require("lazy.core.config")
config.options.checker.enabled = false
local lock = vim.json.decode(table.concat(vim.fn.readfile(vim.fn.stdpath("config") .. "/lazy-lock.json"), "\n"))
require("lazy").restore({ wait = true })
for name, entry in pairs(lock) do
  local plugin = assert(config.plugins[name], "Locked plugin is missing from the specification: " .. name)
  local commit = vim.trim(vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }))
  assert(vim.v.shell_error == 0 and commit == entry.commit, "Plugin did not restore to the locked commit: " .. name)
end

local packages = {
  "lua-language-server",
  "stylua",
  "shfmt",
  "tree-sitter-cli",
  "basedpyright",
  "ruff",
  "clangd",
  "clang-format",
  "debugpy",
  "codelldb",
  "neocmakelsp",
  "cmakelang",
  "cmakelint",
  "prettier",
  "json-lsp",
  "yaml-language-server",
  "marksman",
  "markdownlint-cli2",
  "markdown-toc",
}
local mason_options = LazyVim.opts("mason.nvim")
vim.list_extend(packages, mason_options.ensure_installed or {})
mason_options.ensure_installed = {}
require("lazy").load({ plugins = { "mason.nvim" } })
local registry = require("mason-registry")
local refreshed = false
registry.refresh(function()
  refreshed = true
end)
assert(
  vim.wait(300000, function()
    return refreshed
  end, 100),
  "Timed out refreshing the Mason registry"
)
packages = LazyVim.dedup(packages)
assert(
  vim.wait(600000, function()
    return vim.iter(packages):all(function(name)
      return not registry.get_package(name):is_installing()
    end)
  end, 200),
  "Timed out waiting for existing Mason installations"
)
local missing = vim.tbl_filter(function(name)
  return not registry.get_package(name):is_installed()
end, packages)
if #missing > 0 then
  vim.cmd("MasonInstall " .. table.concat(missing, " "))
end
for _, name in ipairs(packages) do
  assert(registry.get_package(name):is_installed(), "Mason package missing: " .. name)
end

local treesitter_options = LazyVim.opts("nvim-treesitter")
local languages = vim.deepcopy(treesitter_options.ensure_installed or {})
treesitter_options.ensure_installed = {}
require("lazy").load({ plugins = { "nvim-treesitter" } })
if vim.fn.has("win32") == 1 and not vim.env.CC and vim.fn.executable("gcc") == 1 then
  vim.env.CC = "gcc"
end
assert(require("nvim-treesitter").install(languages):wait(600000), "Treesitter parser installation failed")
assert(require("nvim-treesitter").update(languages):wait(600000), "Treesitter parser revisions did not update")
local installed = require("nvim-treesitter").get_installed("parsers")
for _, language in ipairs(languages) do
  assert(vim.tbl_contains(installed, language), "Treesitter parser missing: " .. language)
end

if config.plugins["markdown-preview.nvim"] then
  require("lazy").load({ plugins = { "markdown-preview.nvim" } })
  vim.fn["mkdp#util#install_sync"](1)
  local manifest =
    vim.json.decode(table.concat(vim.fn.readfile(config.plugins["markdown-preview.nvim"].dir .. "/package.json"), "\n"))
  local version = vim.trim(vim.fn["mkdp#util#pre_build_version"]()):gsub("^v", "")
  assert(version == manifest.version, "Markdown preview binary is missing or has the wrong version")
end
print(("Bootstrap verified: %d Mason packages, %d Treesitter parsers"):format(#packages, #languages))
vim.cmd("qa!")
