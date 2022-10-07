vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }

vim.opt.shortmess:append 'c'

-- local lspkind = require 'lspkind'
local cmp = require 'cmp'

cmp.setup {
	['<Tab>'] = function(fallback)
		if cmp.visible() then
			cmp.select_next_item()
		else
			fallback()
		end
	end,
	['<S-Tab>'] = function(fallback)
		if cmp.visible() then
			cmp.select_prev_item()
		else
			fallback()
		end
	end,
	['<CR>'] = cmp.mapping(
		cmp.mapping.confirm{
			behavior = cmp.ConfirmBehavior.Insert,
			select = true
		},
		{ 'i', 'c' }
	),
	['<c-space>'] = cmp.mapping{
		i = cmp.mapping.complete(),
		c = function(fallback)
			if cmp.visible() then
				if not cmp.complete{ select = true } then
					return
				end
			else
				cmp.complete()
			end
		end
	},
	sources = {
--		{ name = 'gh_issues' },
		{ name = 'nvim_lua' },
		{ name = 'nvim_lsp' },
		{ name = 'path' },
		{ name = 'luasnip' },
		{ name = 'buffer', keyword_length = 5 },
	},
	--formatting = { TODO lspkind
	--},
	snippet = {
		expand = function(args)
			require('luasnip').lsp_expand(args.body)
		end
	},
	view = {
		entries = 'native'
	},
	experimental = {
		ghost_text = true
	},
	{ name = 'buffer' }
}

