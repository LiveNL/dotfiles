-- https://github.com/folke/which-key.nvim

-- https://github.com/nvzone/menu?tab=readme-ov-file
vim.keymap.set("n", "<C-j>", function()
  require("menu").open("default")
end, {})


return function()
	local wk = require("which-key")
	local conceallevel = vim.o.conceallevel > 0 and vim.o.conceallevel or 3

	-- Custom toggle functions to replace LazyVim utilities
	local function toggle_option(option)
		if option == "conceallevel" then
			local current = vim.o.conceallevel
			vim.opt.conceallevel = current == 0 and conceallevel or 0
		else
			vim.opt[option] = not vim.opt[option]:get()
		end
	end

	local function toggle_diagnostics()
		local current_config = vim.diagnostic.config()
		if current_config and current_config.virtual_text == false and current_config.signs == false then
			vim.diagnostic.config({ virtual_text = true, signs = true })
		else
			vim.diagnostic.config({ virtual_text = false, signs = false })
		end
	end

	local function toggle_number()
		if vim.opt.relativenumber:get() then
			vim.opt.relativenumber = false
		else
			vim.opt.relativenumber = true
		end
	end

	local function toggle_inlay_hints()
		local bufnr = vim.api.nvim_get_current_buf()
		if vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }) then
			vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
		else
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		end
	end

	wk.setup({
		plugins = { spelling = true },
		opts = {
			replace = {
				["<leader>"] = "COMMA",
			},
		},
	})

	local keys = {
		{ "=", ":nohlsearch<CR>", desc = "Clear search" },
		{ "+", "<C-w>+", desc = "Increase buffer size" },
		{ "-", "<C-w>-", desc = "Decrease buffer size" },
		{ "<C-n>", ":NvimTreeToggle<CR>", desc = "NvimTreeToggle" },

		{ "<C-t>", group = "Tests" },
		{ "<C-t>O", "<cmd>Neotest output<CR>", desc = "Neotest show output" },
		{ "<C-t>a", "<cmd>Neotest run tests<CR>", desc = "Neotest run all" },
		{ "<C-t>j", "<cmd>Neotest run file<CR>", desc = "Neotest run file" },
		{ "<C-t>l", "<cmd>Neotest attach<CR>", desc = "Neotest attatch to test console" },
		{ "<C-t>o", "<cmd>Neotest output-panel<CR>", desc = "Neotest show output panel" },
		{ "<C-t>s", "<cmd>Neotest summary<CR>", desc = "Neotest show summary" },

		{ "gD", "<cmd>Glance definitions<cr>", desc = "Glance definitions" },
		{ "gM", "<cmd>Glance implementations<cr>", desc = "Glance implementations" },
		{ "gR", "<cmd>Glance references<cr>", desc = "Glance references" },
		{ "gY", "<cmd>Glance type_definitions<cr>", desc = "Glance type definitions" },

		{ "h", group = "helpers" },
		{
			"hd",
			function()
				local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
				local seen = {}
				local duplicates = {}

				for _, line in ipairs(lines) do
					if seen[line] then
						duplicates[line] = (duplicates[line] or 1) + 1
					end
					seen[line] = true
				end

				for line, count in pairs(duplicates) do
					print(line .. " [" .. count .. " times]")
				end
			end,
			desc = "Finds duplicate lines within a file",
		},

		{ "hj", "<cmd>FormatJson<cr>", desc = "Format json" },

		{ "hc", "<cmd>PickColor<cr>", desc = "Pick Color" },

		{ "<leader>b", group = "debuggers" },
		{ "<leader>bi", "idebugger; <cr>", desc = "Debugger" },
		{ "<leader>bo", "iimport pdb; pdb.set_trace(); <cr>", desc = "Pdb" },
		{ "<leader>bp", 'irequire"pry";binding.pry; <esc>:w<cr>', desc = "Pry" },

		{ "<leader>d", ":echom (strftime('%H:%M:%S'))<CR>", desc = "Time" },

		{ "<leader>f", group = "Telescope functions" },
		{ "<leader>fc", "<cmd>Telescope commands<cr>", desc = "Find commands" },
		{ "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Find diagnostics issues" },
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
		{ "<leader>fgb", "<cmd>Telescope git_branches<cr>", desc = "Find git branches" },
		{ "<leader>fgc", "<cmd>Telescope git_commits<cr>", desc = "Find git commits" },
		{ "<leader>fgo", "<cmd>Telescope git_stash<cr>", desc = "Find git stash" },
		{ "<leader>fgr", "<cmd>Telescope git_bcommits<cr>", desc = "Find git bcommits" },
		{ "<leader>fgs", "<cmd>Telescope git_status<cr>", desc = "Find git status" },
		{ "<leader>fh", "<cmd>Telescope command history<cr>", desc = "Find command history" },
		{ "<leader>fl", "<cmd>Telescope live_grep<cr>", desc = "Find live grep" },
		{ "<leader>fw", "<cmd>Telescope grep_string<cr>", desc = "Find grep string" },

		{ "<leader>k", ":!black -q -<CR>", group = "black", mode = "v" },

		{ "<leader>l", group = "lazygit" },
		{ "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
		{ "<leader>ll", "<cmd>Lazy<cr>", desc = "Lazy" },

		{ "<leader>m", group = "git merge conflict" },
		{ "<leader>m0", "<cmd>GitConflictChooseNone<cr>", desc = "git merge conflict, choose none" },
		{
			"<leader>m<left>",
			"<cmd>GitConflictPrevConflict<cr>",
			desc = "git merge conflict: move to next conflict",
		},
		{
			"<leader>m<right>",
			"<cmd>GitConflictNextConflict<cr>",
			desc = "git merge conflict: move to previous conflict",
		},
		{ "<leader>mb", "<cmd>GitConflictChooseBoth<cr>", desc = "git merge conflict, choose both" },
		{ "<leader>mo", "<cmd>GitConflictChooseOurs<cr>", desc = "git merge conflict, choose ours" },
		{ "<leader>mt", "<cmd>GitConflictChooseTheirs<cr>", desc = "git merge conflict, choose theirs" },

		{ "<leader>s", group = "buffers" },
		{ "<leader>s<down>", ":below sp <CR>:lua MiniStarter.open()<CR>", desc = "New buffer bottom" },
		{ "<leader>s<left>", ":topleft vnew <CR>:lua MiniStarter.open()<CR>", desc = "New buffer left" },
		{ "<leader>s<right>", ":botright vnew <CR>:lua MiniStarter.open()<CR>", desc = "New buffer right" },
		{ "<leader>s<up>", ":above sp <CR>:lua MiniStarter.open()<CR>", desc = "New buffer top" },

		{ "<leader>t", group = "tabs" },
		{ "<leader>t<down>", ":tabclose<cr>", desc = "Close Tab" },
		{ "<leader>t<left>", ":tabprevious<cr>", desc = "Previous Tab" },
		{ "<leader>t<right>", ":tabnext<cr>", desc = "Next Tab" },
		{ "<leader>t<up>", ":tabnew<cr>", desc = "New Tab" },

		{ "<leader>u", group = "toggles" },
		{
			"<leader>uF",
			function()
				-- Toggle auto format for buffer (placeholder)
			end,
			desc = "Toggle auto format (buffer)",
		},

		{
			"<leader>uL",
			function()
				toggle_option("relativenumber")
			end,
			desc = "Toggle Relative Line Numbers",
		},
		{
			"<leader>uT",
			function()
				if vim.b.ts_highlight then
					vim.treesitter.stop()
				else
					vim.treesitter.start()
				end
			end,
			desc = "Toggle Treesitter Highlight",
		},

		{
			"<leader>uc",
			function()
				toggle_option("conceallevel")
			end,
			desc = "Toggle Conceal",
		},

		{
			"<leader>ud",
			function()
				toggle_diagnostics()
			end,
			desc = "Toggle Diagnostics",
		},

		{
			"<leader>uf",
			function()
				-- Toggle auto format globally (placeholder)
			end,
			desc = "Toggle auto format (global)",
		},

		{
			"<leader>uh",
			function()
				toggle_inlay_hints()
			end,
			desc = "Toggle Inlay Hints",
		},

		{
			"<leader>ul",
			function()
				toggle_number()
			end,
			desc = "Toggle Line Numbers",
		},

		{
			"<leader>us",
			function()
				toggle_option("spell")
			end,
			desc = "Toggle Spelling",
		},

		{
			"<leader>uw",
			function()
				toggle_option("wrap")
			end,
			desc = "Toggle Word Wrap",
		},
	}

	wk.add(keys)
end
