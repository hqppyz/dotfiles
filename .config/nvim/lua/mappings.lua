local keymap = vim.api.nvim_set_keymap;

function opts(extra)
	local result = {
		noremap = true,
		--silent = true
	}

	if type(extra) == 'table' then
		for k, v in pairs(extra) do
			result[k] = v
		end
	end

	return result
end

-- Normal
-- Windows navigation
keymap('n', '<C-Left>', '<C-w>h', opts());
keymap('n', '<C-Down>', '<C-w>j', opts());
keymap('n', '<C-Up>', '<C-w>k', opts());
keymap('n', '<C-Right>', '<C-w>l', opts());

-- Line moving
keymap('n', '<C-S-Up>', '<cmd>echo "c s up"<CR>', opts());

-- TODO
-- Mouse back => <C-o>
-- Mouse forward => <C-i>
-- keymap('n', '<X1Mouse>', '<cmd>echo "left"<CR>', opts);
-- keymap('n', '<X2Mouse>', '<cmd>echo "right"<CR>', opts);

-- Search
-- Bugfix:
--  1. https://vi.stackexchange.com/questions/14056/remapping-tab-key-to-autocomplete-in-commandline-mode-in-vim)
vim.cmd[[
	set wildcharm=<Tab>
]]

keymap('c', '<Tab>', [[ getcmdtype() =~ '^[/?]$' ? '<CR>n' : '<Tab>' ]], opts{expr = true});
keymap('n', '<Tab>', 'n', opts());
keymap('c', '<S-Tab>', [[ getcmdtype() =~ '^[/?]$' ? '<CR>N' : '<S-Tab>' ]], opts{expr = true});
keymap('n', '<S-Tab>', 'N', opts());

