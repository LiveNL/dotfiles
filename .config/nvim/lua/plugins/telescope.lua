-- Telescope
-- https://github.com/nvim-telescope/telescope.nvim

return function()
	-- You dont need to set any of these options. These are the default ones. Only
	-- the loading is important
	require("telescope").setup({
		defaults = {
			vimgrep_arguments = {
				"rg",
				"--hidden",
				"--color=never",
				"--no-heading",
				"--with-filename",
				"--line-number",
				"--column",
				"--smart-case",
			},
		},
		pickers = {
			find_files = {
				hidden = true,
				file_ignore_patterns = {
					".git/",
					".cache",
					"%.o",
					"%.a",
					"%.out",
					"%.class",
					"%.pdf",
					"%.mkv",
					"%.mp4",
					"%.zip",
				},
			},
		},
		extensions = {
			fzf = {
				fuzzy = true, -- false will only do exact matching
				override_generic_sorter = true, -- override the generic sorter
				override_file_sorter = true, -- override the file sorter
				case_mode = "smart_case", -- or "ignore_case" or "respect_case"
				-- the default case_mode is "smart_case"
			},
		},
	})

	-- To get extensions loaded and working with telescope, you need to call
	-- load_extension, somewhere after setup function:

	-- FZF sorter for telescope written in c
	require("telescope").load_extension("fzf")
	require("telescope").load_extension("ui-select")
	require("telescope").load_extension("project")
end
