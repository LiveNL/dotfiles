-- local M = {
-- 	"goolord/alpha-nvim",
-- 	enabled = true,
-- 	cond = vim.g.vscode == nil,
-- 	dependencies = { "nvim-tree/nvim-web-devicons" },
-- 	event = "VimEnter",
-- }

-- M.config = function()
return function()
	local headers = require("plugins.alpha-headers")
	local theme = require("alpha.themes.theta")
	local path_ok, plenary_path = pcall(require, "plenary.path")

	if not path_ok then
		return
	end

	math.randomseed(os.time())

	-- Header
	local function apply_gradient_hl(text)
		local gradient = require("plugins.utils").create_gradient("#DCA561", "#658594", #text)

		local lines = {}
		for i, line in ipairs(text) do
			local tbl = {
				type = "text",
				val = line,
				opts = {
					hl = "HeaderGradient" .. i,
					shrink_margin = false,
					position = "center",
				},
			}
			table.insert(lines, tbl)

			-- create hl group
			vim.api.nvim_set_hl(0, "HeaderGradient" .. i, { fg = gradient[i] })
		end

		return {
			type = "group",
			val = lines,
			opts = { position = "center" },
		}
	end

	local function get_header(headers)
		local header_text = headers[math.random(#headers)]
		return apply_gradient_hl(header_text)
	end

	-- Links / tools
	local dashboard = require("alpha.themes.dashboard")
	local links = {
		type = "group",
		val = {
			dashboard.button("l", "💤 Lazy", "<cmd>Lazy<CR>"),
			dashboard.button("m", "🧱 Mason", "<cmd>Mason<CR>"),
		},
		position = "center",
	}

	theme.config.layout = {
		{ type = "padding", val = 4 },
		get_header({
			headers.header_lines,
			headers.coolLines,
			headers.robustLines,
			headers.efficientLines,
		}),
		{ type = "padding", val = 1 },
		links,
	}

	require("alpha").setup(theme.config)
end

-- return M
