-- VIM
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.winbar = "%f"
vim.opt.splitbelow = true
vim.opt.splitright = true

-- Mouse
vim.opt.mouse = "a"
vim.opt.mousemodel = "popup"

vim.cmd[[
	aunmenu PopUp
	vnoremenu PopUp.Cut                         "+x
	vnoremenu PopUp.Copy                        "+y
	anoremenu PopUp.Paste                       "+gP
	vnoremenu PopUp.Paste                       "+P
	vnoremenu PopUp.Delete                      "_x
	nnoremenu PopUp.Select\ All                 ggVG
	vnoremenu PopUp.Select\ All                 gg0oG$
	inoremenu PopUp.Select\ All                 <C-Home><C-O>VG
]]

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

-- Catppuccin
require('catppuccin').setup()
vim.g.catppuccin_flavour = "mocha" -- latte, frappe, macchiato, mocha
vim.cmd[[colorscheme catppuccin]]

