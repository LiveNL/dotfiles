return function()
	local lsp = require("lspconfig")
	local util = require("lspconfig/util")
	local path = util.path

	local lsp_flags = {
		-- This is the default in Nvim 0.7+
		debounce_text_changes = 150,
	}

	-- Use an on_attach function to only map the following keys
	-- after the language server attaches to the current buffer
	local on_attach = function(client, bufnr)
		if client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint(bufnr, true)
		end
		-- Enable completion triggered by <c-x><c-o>
		vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

		-- Mappings.
		-- See `:help vim.lsp.*` for documentation on any of the below functions
		local bufopts = { noremap = true, silent = true, buffer = bufnr }
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, bufopts)
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, bufopts)
		vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts)
		vim.keymap.set("n", "gi", vim.lsp.buf.implementation, bufopts)
		vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, bufopts)
		vim.keymap.set("n", "<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
		vim.keymap.set("n", "<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
		vim.keymap.set("n", "<space>wl", function()
			print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
		end, bufopts)
		vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, bufopts)
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts)
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts)
		vim.keymap.set("n", "gr", vim.lsp.buf.references, bufopts)
		vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, bufopts)
		vim.keymap.set("v", "<leader>F", vim.lsp.buf.format, bufopts)
	end

	local function get_python_path(workspace)
		-- Use activated virtualenv.
		if vim.env.VIRTUAL_ENV then
			return path.join(vim.env.VIRTUAL_ENV, "bin", "python")
		end

		-- Find and use virtualenv in workspace directory.
		for _, pattern in ipairs({ "*", ".*" }) do
			local match = vim.fn.glob(path.join(workspace, pattern, "pyvenv.cfg"))
			if match ~= "" then
				return path.join(path.dirname(match), "bin", "python")
			end
		end

		-- Fallback to system Python.
		return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
	end

	-- All language servers:
	-- https://github.com/neovim/nvim-lspconfig
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md

	-- (Optional) Configure lua language server for neovim
	lsp.pyright.setup({
		on_attach = on_attach,
		flags = lsp_flags,
		settings = {
			python = {
				executionEnvironments = {
					autoSearchPaths = false,
					root = ".",
				},
				analysis = {
					autoSearchPaths = false,
					root = ".",
					extraPaths = ".",
				},
			},
		},
	})

	-- https://www.flake8rules.com/rules/
	lsp.pylsp.setup({
		on_attach = on_attach,
		flags = lsp_flag,
		settings = {
			-- configure plugins in pylsp
			pylsp = {
				plugins = {
					pyflakes = { enabled = false },
					mccabe = {
						enabled = true,
						threshold = 4,
					},
					pylint = {
						enabled = true,
						args = {
							"--ignore=E221,E201,E202,E272,E251,W503,E712,E711",
							"--disable=C0116,C0115,C0114,C0121",
						},
					},
					pycodestyle = {
						ignore = { "E221", "E201", "E202", "E272", "E251", "W503", "E241", "E712", "E711" },
						enabled = true,
					},
				},
			},
		},
		-- before_init = function(_, config)
		-- 	config.settings.python.pythonPath = get_python_path(".")
		-- end,
	})

	lsp.svelte.setup({
		-- Add filetypes for the server to run and share info between files
		filetypes = { "typescript", "javascript", "svelte", "html", "css" },
	})

	lsp.ruff_lsp.setup({
		on_attach = on_attach,
		init_options = {
			settings = {
				-- Any extra CLI arguments for `ruff` go here.
				args = {},
			},
		},
	})
end
