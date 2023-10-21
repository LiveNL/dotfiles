local null_ls = require("null-ls")
local formatting = null_ls.builtins.formatting
local diagnostics = null_ls.builtins.diagnostics
local code_actions = null_ls.builtins.code_actions
local completion = null_ls.builtins.completion

-- print capabilities: lua print(vim.inspect(vim.lsp.buf_get_clients()[1].server_capabilities))
-- https://github.com/craftzdog/dotfiles-public/blob/c0048102745c55069b096a30042554132b877c89/.config/nvim/plugin/null-ls.rc.lua#L15

local status, null_ls = pcall(require, "null-ls")
if not status then
	return
end

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

local lsp_formatting = function(bufnr)
	vim.lsp.buf.format({
		filter = function(client)
			return client.name == "null-ls"
		end,
		bufnr = bufnr,
	})
end

-- NOTE: THE ORDER IS IPMORTANT: ISORT BEFORE BLACK
null_ls.setup({
	sources = {
		formatting.prettierd.with({
			condition = function(utils)
				return not utils.root_has_file({
					".eslintrc.json",
					".eslintrc",
					".eslintrc.js",
					"frontend/.eslintrc.json",
					"frontend/.xo-config.json",
				})
			end,
		}),
		formatting.isort.with({ extra_args = { "--use-parentheses", "--profile", "black", filetypes = { "python" } } }),
		diagnostics.flake8,
		diagnostics.xo.with({
			prefer_local = "node_modules/.bin",
			extra_filetypes = { "svelte" },
		}),
		diagnostics.write_good.with({ filetypes = { "markdown", "text" } }),
		formatting.autoflake.with({ extra_args = { "--remove-all-unused-imports", "--remove-unused-variables" } }),
		formatting.black.with({ extra_args = { "-l", "80", "--fast" } }),
		formatting.eslint_d.with({
			condition = function(utils)
				return utils.root_has_file({
					".eslintrc.json",
					".eslintrc",
					".eslintrc.js",
					"frontend/.eslintrc.json",
					"frontend/.xo-config.json",
				})
			end,
		}),
		formatting.stylua,
		code_actions.shellcheck,
		code_actions.gitsigns,
		code_actions.refactoring,
		code_actions.xo,
		-- disabled in favor of xo:
		-- diagnostics.eslint,
		-- diagnostics.eslint_d.with({
		-- 	diagnostics_format = "[eslint] #{m}\n(#{c})",
		-- }),
	},
	debug = false,
	on_attach = function(client, bufnr)
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					lsp_formatting(bufnr)
				end,
			})
		end
	end,
})

vim.api.nvim_create_user_command("DisableLspFormatting", function()
	vim.api.nvim_clear_autocmds({ group = augroup, buffer = 0 })
end, { nargs = 0 })

-- https://github.com/jay-babu/mason-null-ls.nvim#primary-source-of-truth-is-null-ls
require("mason-null-ls").setup({
	ensure_installed = nil,
	automatic_installation = true,
	automatic_setup = false,
})

require("fidget").setup({})
