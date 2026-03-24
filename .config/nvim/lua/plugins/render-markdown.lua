return function()
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function()
			vim.opt_local.conceallevel = 2
			vim.opt_local.colorcolumn = ""
			vim.opt_local.wrap = true
			vim.opt_local.linebreak = true    -- break at word boundaries
			vim.opt_local.breakindent = true  -- wrapped lines preserve indentation
		end,
	})

	-- H1: saturated teal  — most prominent
	-- H2: blue (hue shift) — clearly distinct from H1
	-- H3: blue-grey        — step down
	-- H4–H6: fade rapidly to near-invisible
	local function set_heading_highlights()
		vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { bg = "#1b4e5e" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { bg = "#223355" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { bg = "#1a2e45" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg", { bg = "#152435" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg", { bg = "#101c28" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg", { bg = "#0d1620" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH1", { fg = "#a8e6e0", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH2", { fg = "#88aacc", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH3", { fg = "#6090b0" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH4", { fg = "#4a7090" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH5", { fg = "#365466" })
		vim.api.nvim_set_hl(0, "RenderMarkdownH6", { fg = "#284050" })
	end

	set_heading_highlights()
	vim.api.nvim_create_autocmd("ColorScheme", { callback = set_heading_highlights })

	require("render-markdown").setup({
		file_types = { "markdown" },

		heading = {
			enabled = true,
			sign = false,
			width = "full",
			-- Decreasing bar width + increasing indent = double visual cue for depth
			icons = { "█ ", "  ▊ ", "    ▌ ", "      ▍ ", "        ▎ ", "          ▏ " },
			backgrounds = {
				"RenderMarkdownH1Bg",
				"RenderMarkdownH2Bg",
				"RenderMarkdownH3Bg",
				"RenderMarkdownH4Bg",
				"RenderMarkdownH5Bg",
				"RenderMarkdownH6Bg",
			},
			foregrounds = {
				"RenderMarkdownH1",
				"RenderMarkdownH2",
				"RenderMarkdownH3",
				"RenderMarkdownH4",
				"RenderMarkdownH5",
				"RenderMarkdownH6",
			},
		},

		code = {
			enabled = true,
			sign = false,
			style = "full",
			border = "thin",
			left_pad = 2,
			right_pad = 2,
		},

		dash = {
			enabled = true,
			icon = "─",
			width = "full",
			highlight = "RenderMarkdownDash",
		},

		bullet = {
			enabled = true,
			icons = { "●", "○", "◆", "◇" },
		},

		checkbox = {
			enabled = true,
			unchecked = { icon = "󰄱 " },
			checked = { icon = "󰱒 " },
			custom = {
				todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
			},
		},

		quote = {
			enabled = true,
			icon = "┃",
		},

		pipe_table = {
			enabled = true,
			style = "full",
			cell = "trimmed",
		},

		callout = {
			note      = { raw = "[!NOTE]",      rendered = "󰋽 Note",      highlight = "RenderMarkdownInfo" },
			tip       = { raw = "[!TIP]",       rendered = "󰌶 Tip",       highlight = "RenderMarkdownSuccess" },
			important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
			warning   = { raw = "[!WARNING]",   rendered = "󰀪 Warning",   highlight = "RenderMarkdownWarn" },
			caution   = { raw = "[!CAUTION]",   rendered = "󰳦 Caution",   highlight = "RenderMarkdownError" },
			abstract  = { raw = "[!ABSTRACT]",  rendered = "󰨸 Abstract",  highlight = "RenderMarkdownInfo" },
			todo      = { raw = "[!TODO]",      rendered = "󰗡 Todo",      highlight = "RenderMarkdownInfo" },
			success   = { raw = "[!SUCCESS]",   rendered = "󰄬 Success",   highlight = "RenderMarkdownSuccess" },
			question  = { raw = "[!QUESTION]",  rendered = "󰘥 Question",  highlight = "RenderMarkdownWarn" },
			failure   = { raw = "[!FAILURE]",   rendered = "󰅖 Failure",   highlight = "RenderMarkdownError" },
			danger    = { raw = "[!DANGER]",    rendered = "󱐌 Danger",    highlight = "RenderMarkdownError" },
			bug       = { raw = "[!BUG]",       rendered = "󰨰 Bug",       highlight = "RenderMarkdownError" },
			example   = { raw = "[!EXAMPLE]",   rendered = "󰉹 Example",   highlight = "RenderMarkdownHint" },
			quote     = { raw = "[!QUOTE]",     rendered = "󱆨 Quote",     highlight = "RenderMarkdownQuote" },
		},

		link = {
			enabled = true,
			image = "󰥶 ",
			hyperlink = "󰌹 ",
			custom = {
				web = { pattern = "^http[s]?://", icon = "󰖟 " },
			},
		},
	})
end
