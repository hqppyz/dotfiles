-- Install packer if not available
local packer_path = vim.fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if vim.fn.empty(vim.fn.glob(packer_path)) > 0 then
	print('!!! NEW INSTALLATION DETECTED !!!')
	print('Packer will now be installed.')
	print('You will need to restart neovim.')
	print('After it restarts, you will need to run :PackerSync a few times.\n\n\n')
	packer_bootstrap = vim.fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', packer_path})
	return
end

local is_installed = function(package)
	local test, module = pcall(require, package)
	return test
end

local packer = require('packer')

packer.init{
	config = {
		display = {
			open_fn = require('packer.util').float
		}
	}
}

return packer.startup{function()
	use {
		'wbthomason/packer.nvim',
		opt = false
	}

	-- Telescope
	use {
		'nvim-telescope/telescope.nvim',
		requires = {
			{'nvim-lua/plenary.nvim'}
		}
	}
	use {
		'nvim-telescope/telescope-fzf-native.nvim',
		requires = {
			{'nvim-telescope/telescope.nvim'}
		},
		run = 'make'
	}

	-- Treesitter
	if is_installed('nvim-treesitter/nvim-treesitter') then
		use {
			'nvim-treesitter/nvim-treesitter',
			run = ':TSUpdate'
		}
	else
		use 'nvim-treesitter/nvim-treesitter'
	end
	use {
		'p00f/nvim-ts-rainbow',
		requires = {
			{'nvim-treesitter/nvim-treesitter'}
		}
	}

	-- LSP
	use 'neovim/nvim-lspconfig'

	-- Catppuccin
	use {
		'catppuccin/nvim',
		as = 'catppuccin'
	}

	-- Horizontal Scrollinga
	use 'sebastiansam55/hscroll'
end}

