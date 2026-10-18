return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = LazyVim.dedup(vim.list_extend(opts.ensure_installed or {}, {
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
      }))
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers.basedpyright = vim.tbl_deep_extend("force", opts.servers.basedpyright or {}, {
        settings = {
          basedpyright = {
            disableOrganizeImports = true,
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              typeCheckingMode = "standard",
              useLibraryCodeForTypes = true,
            },
          },
        },
      })
      local driver_paths = {}
      for _, driver in ipairs({ "gcc", "g++", "clang", "clang++" }) do
        local driver_path = vim.fn.exepath(driver)
        if driver_path ~= "" then
          table.insert(driver_paths, vim.fs.normalize(driver_path))
        end
      end
      if #driver_paths > 0 then
        opts.servers.clangd.cmd = vim.deepcopy(opts.servers.clangd.cmd)
        table.insert(opts.servers.clangd.cmd, "--query-driver=" .. table.concat(driver_paths, ","))
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
        rust = { "rustfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
        cmake = { "cmake_format" },
        json = { "prettier" },
        jsonc = { "prettier" },
        yaml = { "prettier" },
      },
    },
  },
  {
    "mrcjkb/rustaceanvim",
    opts = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            check = { command = "clippy" },
          },
        },
      },
    },
    config = function(_, opts)
      if vim.fn.has("win32") == 1 then
        opts.dap = opts.dap or {}
        opts.dap.adapter = {
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb.exe",
            args = { "--port", "${port}" },
            detached = false,
          },
        }
      end
      vim.g.rustaceanvim = vim.tbl_deep_extend("force", vim.g.rustaceanvim or {}, opts)
    end,
  },
  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" },
      cmake_compile_commands_options = { action = "copy" },
    },
  },
  {
    "mfussenegger/nvim-dap-python",
    optional = true,
    config = function()
      local python = vim.fn.has("win32") == 1
          and vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/Scripts/python.exe"
        or "debugpy-adapter"
      require("dap-python").setup(python)
      require("dap-python").test_runner = "pytest"
    end,
  },
  {
    "nvim-neotest/neotest",
    init = function()
      if vim.fn.has("win32") == 1 then
        vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
          group = vim.api.nvim_create_augroup("NeotestWindowsPaths", { clear = true }),
          callback = function()
            vim.o.shellslash = false
          end,
        })
      end
    end,
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
          is_test_file = function(path)
            local filename = vim.fs.basename(path)
            return filename:match("^test_.*%.py$") ~= nil or filename:match("_test%.py$") ~= nil
          end,
        },
      },
    },
  },
}
