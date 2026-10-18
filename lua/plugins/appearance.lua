return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "dark",
      },
      on_highlights = function(highlights, colors)
        highlights.LineNr = { fg = colors.dark5 }
        highlights.LineNrAbove = { fg = colors.dark5 }
        highlights.LineNrBelow = { fg = colors.dark5 }
        highlights.CursorLineNr = { fg = colors.cyan, bg = colors.bg_highlight, bold = true }
        highlights.CursorLineSign = { bg = colors.bg_highlight }
        highlights.WinSeparator = { fg = colors.blue, bg = "NONE" }
        highlights.Whitespace = { fg = colors.comment }
      end,
    },
  },
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        always_show_bufferline = true,
        separator_style = "thin",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options.component_separators = { left = "│", right = "│" }
      opts.options.section_separators = { left = "", right = "" }
      opts.options.globalstatus = true
      opts.sections.lualine_b = { "branch" }
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local client_names = {}
          for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
            if not vim.tbl_contains(client_names, client.name) then
              client_names[#client_names + 1] = client.name
            end
          end
          table.sort(client_names)
          return #client_names > 0 and ("LSP " .. table.concat(client_names, ", ")) or ""
        end,
        cond = function()
          return vim.o.columns > 110
        end,
        color = { fg = "#7dcfff" },
      })
      table.insert(opts.sections.lualine_x, {
        "encoding",
        cond = function()
          return vim.o.columns > 140
        end,
      })
      table.insert(opts.sections.lualine_x, {
        "fileformat",
        symbols = { unix = "LF", dos = "CRLF", mac = "CR" },
        cond = function()
          return vim.o.columns > 140
        end,
      })
    end,
  },
}
