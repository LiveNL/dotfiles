return function()
	-- Setup with some options
	require("nvim-tree").setup({
		sort_by = "case_sensitive",
		hijack_directories = { enable = false },
		disable_netrw = false,
		hijack_netrw = false,
		view = {
			adaptive_size = true,
		},
		renderer = {
			group_empty = true,
		},
		filters = {
			dotfiles = false,
			git_ignored = false,
		},
		on_attach = function(bufnr)
			local api = require("nvim-tree.api")

			-- Default mappings
			api.config.mappings.default_on_attach(bufnr)

			-- Custom mappings
			local opts = { buffer = bufnr, noremap = true, silent = true, nowait = true }
			vim.keymap.set('n', 'u', api.tree.change_root_to_parent, opts)
		end,
	})
end
