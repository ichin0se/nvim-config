return {
  {
    "folke/snacks.nvim",
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
          if vim.fn.has("win32") == 1 and Snacks.config.image.enabled == false then
            Snacks.image.meta.health = false
          end
        end,
      })
    end,
    opts = {
      image = { enabled = false },
      explorer = { enabled = true },
      indent = { enabled = true },
      picker = {
        sources = {
          explorer = { hidden = true, ignored = false },
        },
      },
    },
  },
}
