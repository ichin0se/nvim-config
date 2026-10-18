return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "AI / Codex" },
      },
    },
  },
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>gD", false },
      {
        "<leader>gU",
        function()
          require("config.devtools").gitui()
        end,
        desc = "GitUI (Root Dir)",
      },
      {
        "<leader>aa",
        function()
          require("config.devtools").codex()
        end,
        desc = "Toggle Codex (Root Dir)",
      },
      {
        "<leader>ar",
        function()
          require("config.devtools").codex_resume()
        end,
        desc = "Resume Codex (Root Dir)",
      },
      {
        "<leader>af",
        function()
          require("config.devtools").copy_file_path()
        end,
        desc = "Copy File Path for Codex",
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles", "DiffviewFocusFiles" },
    opts = {},
    keys = {
      {
        "<leader>gD",
        function()
          require("config.devtools").diffview()
        end,
        desc = "Diffview (Root Dir)",
      },
      {
        "<leader>gH",
        function()
          require("config.devtools").file_history()
        end,
        desc = "Diffview File History",
      },
      { "<leader>gC", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    },
  },
  {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = { "nvim-lua/plenary.nvim", "folke/snacks.nvim" },
    opts = {
      picker = "snacks",
      enable_builtin = true,
    },
    keys = {
      { "<leader>gO", "<cmd>Octo<cr>", desc = "GitHub Issues / Pull Requests" },
    },
  },
}
