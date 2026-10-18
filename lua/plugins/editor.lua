return {
  {
    "folke/persistence.nvim",
    event = "VimEnter",
    opts = { need = 1, branch = true },
    config = function(_, opts)
      local persistence = require("persistence")
      persistence.setup(opts)
      if vim.fn.argc(-1) == 0 then
        vim.schedule(function()
          if not vim.bo.modified and (vim.api.nvim_buf_get_name(0) == "" or vim.bo.filetype == "snacks_dashboard") then
            persistence.load()
          end
        end)
      end
    end,
  },
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        preset = "enter",
        ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        ["<C-e>"] = { "hide", "fallback" },
      },
      completion = {
        list = { selection = { preselect = false, auto_insert = false } },
        menu = { auto_show = true, border = "rounded" },
        documentation = { auto_show = true, auto_show_delay_ms = 200, window = { border = "rounded" } },
      },
      signature = { enabled = true, window = { border = "rounded" } },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = { max_lines = 3, multiline_threshold = 2 },
  },
}
