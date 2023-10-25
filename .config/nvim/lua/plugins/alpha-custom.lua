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

	-- MRU
	local function get_mru(max_shown)
		local tbl = {
			{
				type = "text",
				val = "Recent Files",
				opts = { hl = "SpecialComment", position = "center" },
			},
		}

		local mru_list = theme.mru(1, "", max_shown)
		for _, file in ipairs(mru_list.val) do
			table.insert(tbl, file)
		end

		return { type = "group", val = tbl, opts = {} }
	end

	-- Info section
	local function get_info()
		local datetime = os.date(" %A %B %d")
		local version = vim.version()
		local nvim_version_info = "ⓥ " .. version.major .. "." .. version.minor .. "." .. version.patch
		local lazy_stats = require("lazy").stats()
		local os = "OS: " .. vim.loop.os_uname().sysname
		local startup_time = "Startup: " .. lazy_stats.startuptime .. " sec"
		local total_plugins = " " .. lazy_stats.loaded .. "/" .. lazy_stats.count .. " packages"
		local info_string = datetime
			.. "  |  "
			.. total_plugins
			.. "  |  "
			.. nvim_version_info
			.. " | "
			.. startup_time
			.. " | "
			.. os

		return {
			type = "text",
			val = info_string,
			opts = {
				hl = "Delimiter",
				position = "center",
			},
		}
	end

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
		{ type = "padding", val = 2 },
		get_mru(7),
		{ type = "padding", val = 3 },
		get_info(),
	}

	require("alpha").setup(theme.config)
end
