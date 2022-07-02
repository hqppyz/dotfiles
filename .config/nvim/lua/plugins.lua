-- Install packer if not available
local fn = vim.fn
local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
if fn.empty(fn.glob(install_path)) > 0 then
  packer_bootstrap = fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
end

return require('packer').startup{
	function()
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

		require('telescope').setup()
		require('telescope').load_extension('fzf')

		-- Treesitter
		use {
			'nvim-treesitter/nvim-treesitter',
			run = ':TSUpdate'
		}
		use 'p00f/nvim-ts-rainbow'

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
	end,
	config = {
		display = {
			open_fn = require('packer.util').float
		}
	}
}

