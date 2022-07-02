-- VIM
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.winbar = "%f"

-- Telescope
require('telescope').setup()
require('telescope').load_extension('fzf')

-- Treesitter
require('nvim-treesitter.configs').setup{
	ensure_installed = "all",
	sync_installl = false,
	highlight = {
		enable = true
	},
	indent = {
		enable = true
	},
	rainbow = {
		enable = true
	}
}

