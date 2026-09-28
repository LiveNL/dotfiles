local M = {}

-- Functional wrapper for mapping custom keybindings
M.map = function(mode, lhs, rhs, opts)
	local options = { noremap = true, silent = true }
	if opts then
		options = vim.tbl_extend("force", options, opts)
	end
	vim.keymap.set(mode, lhs, rhs, options)
end

-- move or create split in direction
local opposite_keys = { h = "l", l = "h", j = "k", k = "j" }

local function split_exists_direction(winnr, direction)
	vim.cmd("wincmd " .. direction)
	if winnr == vim.api.nvim_get_current_win() then
		return false
	else
		vim.cmd("wincmd " .. opposite_keys[direction])
		return true
	end
end

M.move_create_split = function(direction)
	local winnr = vim.api.nvim_get_current_win()

	if split_exists_direction(winnr, direction) == false then
		if direction == "h" or direction == "l" then
			vim.cmd("wincmd v")
			vim.cmd("wincmd " .. direction)
		elseif direction == "j" or direction == "k" then
			vim.cmd("wincmd s")
			vim.cmd("wincmd " .. direction)
		end
	else
		vim.cmd("wincmd " .. direction)
	end
end

-- Get colour of the mode
local colours = require("plugins.colours")
M.get_mode_colour = function()
	local mode = vim.api.nvim_get_mode()["mode"]

	if mode == "n" then
		return colours.normal
	elseif mode == "i" then
		return colours.insert
	elseif mode == "v" then
		return colours.visual
	elseif mode == "V" then
		return colours.visual
	elseif mode == "s" then
		return colours.visual
	elseif mode == "R" then
		return colours.replace
	elseif mode == "c" then
		return colours.command
	else
		return colours.textLight
	end
end

-- open toggleterm with lazygit
M.toggle_lazygit = function()
	local Terminal = require("toggleterm.terminal").Terminal
	local lazygit = Terminal:new({
		cmd = "lazygit",
		hidden = true,
		on_open = function(term)
			vim.cmd("startinsert!")
		end,
		close_on_exit = true,
		direction = "float",
		float_opts = {
			border = "single",
		},
	})
	lazygit:toggle()
end

-- Search the tree the open file lives in, not the one nvim was started in.
--  Asking git from the buffer's own directory also covers worktrees, where
--  .git is a file and finddir would walk straight past it.
M.project_root = function()
	local dir = vim.fn.expand("%:p:h")
	if dir == "" then
		dir = vim.fn.getcwd()
	end

	local root = vim.fn.systemlist({ "git", "-C", dir, "rev-parse", "--show-toplevel" })[1]
	if vim.v.shell_error ~= 0 or root == nil or root == "" then
		return nil
	end

	return root
end

-- Jump between the worktrees of the repo you are in. Picking one sets the
--  tab's directory, so the finder, grep and lsp all follow it from then on.
M.switch_worktree = function()
	local dir = vim.fn.expand("%:p:h")
	if dir == "" then
		dir = vim.fn.getcwd()
	end

	local lines = vim.fn.systemlist({ "git", "-C", dir, "worktree", "list", "--porcelain" })
	if vim.v.shell_error ~= 0 then
		vim.notify("Not inside a git repository", vim.log.levels.WARN)
		return
	end

	local worktrees = {}
	for _, line in ipairs(lines) do
		local path = line:match("^worktree (.+)$")
		if path and vim.fn.isdirectory(path) == 1 then
			table.insert(worktrees, path)
		end
	end

	if #worktrees < 2 then
		vim.notify("This repository has only one worktree", vim.log.levels.INFO)
		return
	end

	vim.ui.select(worktrees, { prompt = "Worktree" }, function(choice)
		if choice == nil then
			return
		end

		local ok, err = pcall(vim.cmd, "tcd " .. vim.fn.fnameescape(choice))
		if not ok then
			vim.notify(tostring(err), vim.log.levels.ERROR)
			return
		end

		vim.notify("cwd: " .. choice)
	end)
end

M.find_files_from_project_root = function()
	local root = M.project_root()

	require("telescope.builtin").find_files(root and { cwd = root } or {})
end

M.live_grep_from_project_root = function()
	local root = M.project_root()

	require("telescope.builtin").live_grep(root and { cwd = root } or {})
end

-- luasnip: insert visual selection into dynamic node
M.get_visual = function(parent)
	local ls = require("luasnip")
	local sn = ls.snippet_node
	local i = ls.insert_node

	print("Creating snippet from visual selection...")
	if #parent.snippet.env.SELECT_RAW > 0 then
		return sn(nil, i(1, parent.snippet.env.SELECT_RAW))
	else
		return sn(nil, i(1, ""))
	end
end

-- luasnip: return the regex capture group for regex-based triggers
M.get_capture_group = function(group)
	local ls = require("luasnip")
	local f = ls.function_node

	return f(function(_, snip)
		return snip.captures[group]
	end)
end

-- check if string is in table
M.is_string_in_table = function(str, tbl)
	for _, value in pairs(tbl) do
		if value == str then
			return true
		end
	end
	return false
end

-- get all keys from a table
M.get_table_keys = function(tab)
	local keyset = {}
	for k, v in pairs(tab) do
		keyset[#keyset + 1] = k
	end
	return keyset
end

-- UI select menu
M.UI_select = function(item_map)
	local options = M.get_table_keys(item_map)
	return vim.ui.select(options, { prompt = "Select option" }, function(item, idx)
		for option, cmd in pairs(item_map) do
			if option == item then
				load(cmd)()
			end
		end
	end)
end

-- check if cwd is a git repo
M.is_git_repo = function()
	local path = vim.loop.cwd() .. "/.git"
	local ok, _ = vim.loop.fs_stat(path)
	if not ok then
		return false
	else
		return true
	end
end

-- find file's root directory based on a list of patterns
Root_cache = {}
M.find_root = function(buf_id, patterns)
	local path = vim.api.nvim_buf_get_name(buf_id)
	if path == "" then
		return
	end
	path = vim.fs.dirname(path)

	-- Try using cache
	local res = Root_cache[path]
	if res ~= nil then
		return res
	end

	-- Find root
	local root_file = vim.fs.find(patterns, { path = path, upward = true })[1]
	if root_file == nil then
		return
	end

	-- Use absolute path and cache result
	res = vim.fn.fnamemodify(vim.fs.dirname(root_file), ":p")
	Root_cache[path] = res

	return res
end

-- start REPL
M.StartREPL = function(repl)
	vim.cmd("vsplit")
	vim.cmd("terminal " .. repl)
	vim.opt_local.number = false
	local term_id = vim.b.terminal_job_id
	vim.cmd("wincmd p")
	vim.b.slime_config = { jobid = term_id }
end

-- string padding
M.pad_string = function(str, len, align)
	local str_len = #str
	if str_len >= len then
		return str
	end

	local pad_len = len - str_len
	local pad = string.rep(" ", pad_len)

	if align == "left" then
		return str .. pad
	elseif align == "right" then
		return pad .. str
	elseif align == "center" then
		local left_pad = math.floor(pad_len / 2)
		local right_pad = pad_len - left_pad
		return string.rep(" ", left_pad) .. str .. string.rep(" ", right_pad)
	end
end

-- create colour gradient from hex values
M.create_gradient = function(start, finish, steps)
	local r1, g1, b1 =
		tonumber("0x" .. start:sub(2, 3)), tonumber("0x" .. start:sub(4, 5)), tonumber("0x" .. start:sub(6, 7))
	local r2, g2, b2 =
		tonumber("0x" .. finish:sub(2, 3)), tonumber("0x" .. finish:sub(4, 5)), tonumber("0x" .. finish:sub(6, 7))

	local r_step = (r2 - r1) / steps
	local g_step = (g2 - g1) / steps
	local b_step = (b2 - b1) / steps

	local gradient = {}
	for i = 1, steps do
		local r = math.floor(r1 + r_step * i)
		local g = math.floor(g1 + g_step * i)
		local b = math.floor(b1 + b_step * i)
		table.insert(gradient, string.format("#%02x%02x%02x", r, g, b))
	end

	return gradient
end

return M
