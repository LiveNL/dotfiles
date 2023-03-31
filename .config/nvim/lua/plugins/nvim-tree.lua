-- Setup with some options
require("nvim-tree").setup({
  sort_by = "case_sensitive",
  hijack_directories = { enable = false },
  view = {
    adaptive_size = true,
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
      },
    },
  },
  renderer = {
    group_empty = true,
  },
  filters = {
    dotfiles = true,
  },
})
