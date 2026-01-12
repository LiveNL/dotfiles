return function()
  require("mason").setup()
  require("mason-lspconfig").setup({
    ensure_installed = {
      "eslint",
      "ts_ls",
      "svelte",
      "basedpyright",
      "jsonls",
      "ruff",
      "lua_ls",
    },
    automatic_installation = true,
    automatic_enable = false,
  })

  local function get_python_path(workspace)
    if vim.env.VIRTUAL_ENV then
      return vim.env.VIRTUAL_ENV .. "/bin/python"
    end

    for _, pattern in ipairs({ "*", ".*" }) do
      local match = vim.fn.glob(workspace .. "/" .. pattern .. "/pyvenv.cfg") or ""
      if match ~= "" and match ~= nil then
        return vim.fn.fnamemodify(match, ":h") .. "/bin/python"
      end
    end

    return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
  end

  local on_attach = function(client, bufnr)
    if client.server_capabilities.inlayHintProvider then
      if vim.lsp.inlay_hint and type(vim.lsp.inlay_hint) == "table" and vim.lsp.inlay_hint.enable then
        vim.lsp.inlay_hint.enable(true)
      end
    end
    vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })

    local bufopts = { noremap = true, silent = true, buffer = bufnr }

    bufopts.desc = "Go to declaration"
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)

    bufopts.desc = ""
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
    vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)
    vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
    vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
    vim.keymap.set("n", "<space>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, bufopts)

    bufopts.desc = "type definition"
    vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, bufopts)

    bufopts.desc = "rename"
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)

    bufopts.desc = "code_action"
    vim.keymap.set("n", "<leader>C", vim.lsp.buf.code_action, bufopts)

    bufopts.desc = "references"
    vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)

    bufopts.desc = "format normal"
    vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, bufopts)

    bufopts.desc = "format visual"
    vim.keymap.set("v", "<leader>F", vim.lsp.buf.format, bufopts)
  end

  local capabilities = require("cmp_nvim_lsp").default_capabilities()

  vim.lsp.config("basedpyright", {
    root_markers = { "pyproject.toml", "setup.py", "setup.cfg", ".git" },
    settings = {
      basedpyright = {
        analysis = {
          autoSearchPaths = false,
          diagnosticMode = "openFilesOnly",
          useLibraryCodeForTypes = true,
          diagnosticSeverityOverrides = {
            reportUnusedCallResult = false
          },
        },
      },
      python = {
        analysis = {},
      }
    },
    before_init = function(_, config)
      local python_path = get_python_path(config.root_dir)
      config.settings.python.pythonPath = python_path
      vim.notify("Python: " .. python_path .. " | Root: " .. config.root_dir)
    end,
  })

  vim.lsp.config("svelte", {
    filetypes = { "svelte", "html", "css" },
    on_attach = function(client, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr })
        end,
      })
    end,
    settings = {
      svelte = {
        format = {
          enable = true,
        },
      },
    },
  })

  vim.lsp.config("ts_ls", {
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      client.server_capabilities.documentFormattingProvider = false
      on_attach(client, bufnr)
    end,
    settings = {
      typescript = {
        format = {
          enable = false
        }
      },
      javascript = {
        format = {
          enable = false
        }
      }
    }
  })

  vim.lsp.config("eslint", {
    on_attach = function(client, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.cmd("EslintFixAll")
        end,
      })

      on_attach(client, bufnr)
    end,
    settings = {
      useESLintClass = false,
      experimental = {
        useFlatConfig = true
      },
      workingDirectories = { { mode = "auto" } },
      validate = "on",
      packageManager = "npm",
      codeActionOnSave = {
        enable = true,
        mode = "all"
      },
      format = true
    }
  })

  vim.lsp.config("ruff", {
    on_attach = function(client, bufnr)
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.code_action({
            context = { only = { "source.organizeImports" } },
            apply = true,
          })
        end,
      })
      on_attach(client, bufnr)
    end,
    init_options = {
      settings = {
        args = {},
      },
    },
  })

  vim.lsp.config("jsonls", {
    settings = {
      json = {
        schemas = require("schemastore").json.schemas(),
        validate = { enable = true },
      },
    },
    on_attach = function(client, bufnr)
      vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", { buf = bufnr })
    end,
  })

  vim.lsp.config("lua_ls", {
    on_attach = on_attach,
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        diagnostics = {
          globals = { "vim" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = false,
        },
        telemetry = {
          enable = false,
        },
      },
    },
  })

  vim.lsp.enable({
    "basedpyright",
    "svelte",
    "ts_ls",
    "eslint",
    "ruff",
    "jsonls",
    "lua_ls",
  })

  vim.fn.sign_define("DiagnosticSignError", { text = "E", texthl = "DiagnosticSignError" })
  vim.fn.sign_define("DiagnosticSignWarn", { text = "W", texthl = "DiagnosticSignWarn" })
  vim.fn.sign_define("DiagnosticSignHint", { text = "H", texthl = "DiagnosticSignHint" })
  vim.fn.sign_define("DiagnosticSignInfo", { text = "I", texthl = "DiagnosticSignInfo" })

  vim.diagnostic.config({
    virtual_text = false,
    severity_sort = true,
    float = {
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
    signs = true,
    underline = true,
    update_in_insert = false,
  })

  vim.o.updatetime = 300
  vim.api.nvim_create_autocmd({ "CursorHold" }, {
    callback = function()
      vim.diagnostic.open_float(nil, { focus = false, scope = "cursor" })
    end,
  })
end
