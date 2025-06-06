local headers = require("plugins.alpha-headers")
math.randomseed(os.time())

-- Header
local function apply_gradient_hl(text)
	local gradient = require("plugins.utils").create_gradient("#DCA561", "#658594", #text)

	local lines = {}
	for i, line in ipairs(text) do
		local colored_line = string.format("%s", line)
		vim.api.nvim_set_hl(0, "HeaderGradient" .. i, { fg = gradient[i] })
		table.insert(lines, colored_line)
	end

	return lines
end

local function get_header(header_options)
	local header_text = header_options[math.random(#header_options)]
	return apply_gradient_hl(header_text)
end

local header = get_header({
	headers.header_lines,
	headers.coolLines,
	headers.robustLines,
	headers.efficientLines,
})

require("mini.starter").setup({
	-- Whether to open starter buffer on VimEnter. Not opened if Neovim was
	-- started with intent to show something else.
	autoopen = true,

	-- Whether to evaluate action of single active item
	evaluate_single = false,

	-- Items to be displayed. Should be an array with the following elements:
	-- - Item: table with <action>, <name>, and <section> keys.
	-- - Function: should return one of these three categories.
	-- - Array: elements of these three types (i.e. item, array, function).
	-- If `nil` (default), default items will be used (see |mini.starter|).
	items = nil,

	-- Header to be displayed before items. Converted to single string via
	-- `tostring` (use `\n` to display several lines). If function, it is
	-- evaluated first. If `nil` (default), polite greeting will be used.
	header = table.concat(header, "\n"),

	-- Footer to be displayed after items. Converted to single string via
	-- `tostring` (use `\n` to display several lines). If function, it is
	-- evaluated first. If `nil` (default), default usage help will be shown.
	footer = nil,

	-- Array  of functions to be applied consecutively to initial content.
	-- Each function should take and return content for 'Starter' buffer (see
	-- |mini.starter| and |MiniStarter.content| for more details).
	content_hooks = nil,

	-- Characters to update query. Each character will have special buffer
	-- mapping overriding your global ones. Be careful to not add `:` as it
	-- allows you to go into command mode.
	query_updaters = "abcdefghijklmnopqrstuvwxyz0123456789_-.",

	-- Whether to disable showing non-error feedback
	silent = false,
})

vim.api.nvim_create_autocmd("User", {
	pattern = "MiniStarterOpened",
	callback = function()
		local starter_bufnr = vim.api.nvim_get_current_buf()

		vim.defer_fn(function()
			require("nvim-tree.api").tree.open()
			-- Return focus to ministarter
			vim.defer_fn(function()
				for _, win in ipairs(vim.api.nvim_list_wins()) do
					if vim.api.nvim_win_get_buf(win) == starter_bufnr then
						vim.api.nvim_set_current_win(win)
						break
					end
				end
			end, 50)
		end, 10)

		-- Fix :Ex command in ministarter
		vim.api.nvim_buf_create_user_command(starter_bufnr, "Ex", function(opts)
			if opts.args and opts.args ~= "" then
				vim.cmd("Explore " .. opts.args)
			else
				vim.cmd("Explore .")
			end
		end, { nargs = "?" })
	end,
})
