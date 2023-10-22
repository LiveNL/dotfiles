return function()
	-- Nvim supports the Language Server Protocol (LSP),
	-- which means it acts as a client to LSP servers and includes a Lua framework
	-- vim.lsp for building enhanced LSP tools.
	--
	-- LSP facilitates features like go-to-definition, find-references, hover,
	-- completion, rename, format, refactor, etc., using semantic whole-project
	-- analysis (unlike ctags).
	--
	-- All language servers:
	-- https://github.com/neovim/nvim-lspconfig
	-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/server_configurations.md
	local lsp = require("lspconfig")
	local util = require("lspconfig/util")
	local path = util.path
	local lsp_zero = require("lsp-zero")

	lsp_zero.preset("recommended")

	local lsp_flags = {
		-- This is the default in Nvim 0.7+
		debounce_text_changes = 150,
	}

	-- (Optional) Configure lua language server for neovim
	lsp_zero.setup()

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

	lsp.svelte.setup({
		-- Add filetypes for the server to run and share info between files
		filetypes = { "typescript", "javascript", "svelte", "html", "css" },
	})

	require("mason-lspconfig").setup({
		ensure_installed = {},
		handlers = {
			lsp_zero.default_setup,
			lua_ls = function()
				-- (Optional) Configure lua language server for neovim
				local lua_opts = lsp_zero.nvim_lua_ls()
				require("lspconfig").lua_ls.setup(lua_opts)
			end,
		},
	})

	-- Mappings.
	-- See `:help vim.diagnostic.*` for documentation on any of the below functions
	local opts = { noremap = true, silent = true }
	vim.keymap.set("n", "<space>e", vim.diagnostic.open_float, opts)
	vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
	vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
	vim.keymap.set("n", "<space>q", vim.diagnostic.setloclist, opts)

	vim.diagnostic.config({
		virtual_text = false,
	})

	-- Show line diagnostics automatically in hover window
	vim.o.updatetime = 300
	vim.cmd([[autocmd CursorHold,CursorHoldI * lua vim.diagnostic.open_float(nil, {focus=false})]])

	local signs = { Error = "E", Warn = "W", Hint = "H", Info = "I" }
	for type, icon in pairs(signs) do
		local hl = "DiagnosticSign" .. type
		vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
	end

	-- Use an on_attach function to only map the following keys
	-- after the language server attaches to the current buffer
	local on_attach = function(client, bufnr)
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
		return exepath("python3") or exepath("python") or "python"
	end

	-- https://www.flake8rules.com/rules/
	require("lspconfig").pylsp.setup({
		on_attach = on_attach,
		flags = {
			lsp_flags,
		},
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
		before_init = function(_, config)
			config.settings.python.pythonPath = get_python_path(".")
		end,
	})

	--[[ SIGNCOLUMN Diagnostic settings ]]
	-- https://www.reddit.com/r/neovim/comments/mvhfw7/can_built_in_lsp_diagnostics_be_limited_to_show_a/
	-- https://neovim.io/doc/user/diagnostic.html

	-- Create a custom namespace. This will aggregate signs from all other
	-- namespaces and only show the one with the highest severity on a
	-- given line
	local ns = vim.api.nvim_create_namespace("my_namespace")

	-- Get a reference to the original signs handler
	local orig_signs_handler = vim.diagnostic.handlers.signs

	-- Override the built-in signs handler
	vim.diagnostic.handlers.signs = {
		show = function(_, bufnr, _, opts)
			-- Get all diagnostics from the whole buffer rather than just the
			-- diagnostics passed to the handler
			local diagnostics = vim.diagnostic.get(bufnr)

			-- Find the "worst" diagnostic per line
			local max_severity_per_line = {}
			for _, d in pairs(diagnostics) do
				local m = max_severity_per_line[d.lnum]
				if not m or d.severity < m.severity then
					max_severity_per_line[d.lnum] = d
				end
			end

			-- Pass the filtered diagnostics (with our custom namespace) to
			-- the original handler
			local filtered_diagnostics = vim.tbl_values(max_severity_per_line)
			orig_signs_handler.show(ns, bufnr, filtered_diagnostics, opts)
		end,
		hide = function(_, bufnr)
			orig_signs_handler.hide(ns, bufnr)
		end,
	}
end
