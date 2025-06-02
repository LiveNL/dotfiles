return function()
  local lsp = require("lspconfig")
  local util = require("lspconfig/util")
  local path = util.path

  require("mason").setup()
  require("mason-lspconfig").setup({
    ensure_installed = {
      "eslint",
      "ts_ls",
      "svelte",
      "basedpyright",
      "jsonls",
      "ruff",
    },
    automatic_installation = true,
  })

  local lsp_flags = {
    debounce_text_changes = 150,
  }

  local on_attach = function(client, bufnr)
    if client.server_capabilities.inlayHintProvider then
      if vim.lsp.inlay_hint and type(vim.lsp.inlay_hint) == "function" then
        vim.lsp.inlay_hint(bufnr, true)
      elseif vim.lsp.inlay_hint and type(vim.lsp.inlay_hint) == "table" and vim.lsp.inlay_hint.enable then
        vim.lsp.inlay_hint.enable(true)
      end
    end
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

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

  local function get_python_path(workspace)
    if vim.env.VIRTUAL_ENV then
      return path.join(vim.env.VIRTUAL_ENV, "bin", "python")
    end

    for _, pattern in ipairs({ "*", ".*" }) do
      local match = vim.fn.glob(path.join(workspace, pattern, "pyvenv.cfg")) or ""
      if match ~= "" and match ~= nil then
        return path.join(path.dirname(match), "bin", "python")
      end
    end

    return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
  end

  lsp.basedpyright.setup({
    root_dir = util.root_pattern("src", ".git", "pyproject.toml", "setup.py", "setup.cfg"),
    settings = {
      basedpyright = {
        analysis = {
          autoSearchPaths = true,
          diagnosticMode = "openFilesOnly",
          useLibraryCodeForTypes = true,
          diagnosticSeverityOverrides = {
            reportUnusedCallResult = false
          },

        },
      },
      python = {
        analysis = {
        },
      }
    },
    before_init = function(_, config)
      local python_path = get_python_path()
      config.settings.python.pythonPath = python_path
      vim.notify(python_path)
    end,
  })


  lsp.svelte.setup({
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

  local capabilities = require("cmp_nvim_lsp").default_capabilities()
  
  lsp.ts_ls.setup({
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

  lsp.eslint.setup({
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

  lsp.ruff.setup({
    on_attach = on_attach,
    init_options = {
      settings = {
        args = {},
      },
    },
  })

  lsp.jsonls.setup({
    settings = {
      json = {
        schemas = require("schemastore").json.schemas(),
        validate = { enable = true },
      },
    },
    on_attach = function(client, bufnr)
      local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
      end
      buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
    end,
  })
end
