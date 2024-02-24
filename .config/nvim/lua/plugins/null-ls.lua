return function()
	-- https://github.com/jay-babu/mason-null-ls.nvim#primary-source-of-truth-is-null-ls
	require("mason-null-ls").setup({
		ensure_installed = nil,
		automatic_installation = true,
		automatic_setup = false,
	})

	local null_ls = require("null-ls")
	local formatting = null_ls.builtins.formatting
	local diagnostics = null_ls.builtins.diagnostics
	local code_actions = null_ls.builtins.code_actions

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
			formatting.isort.with({
				extra_args = { "--use-parentheses", "--profile", "black" },
				filetypes = { "python" },
			}),

			diagnostics.write_good.with({ filetypes = { "markdown", "text" } }),

			formatting.black.with({ extra_args = { "-l", "80", "--fast" } }),
			formatting.stylua,

			code_actions.gitsigns,
			code_actions.refactoring,
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
end
