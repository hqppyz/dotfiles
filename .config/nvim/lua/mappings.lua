-- require 'lspconfig'.pyright.setup{}
-- require 'lspconfig'.clangds.setup{}

local keymap = vim.api.nvim_set_keymap

local opts = {
	noremap = true,
	silent = true
}

-- Normal
-- Windows navigation
keymap('n', '<C-Left>', '<C-w>h', opts);
keymap('n', '<C-Down>', '<C-w>j', opts);
keymap('n', '<C-Up>', '<C-w>k', opts);
keymap('n', '<C-Right>', '<C-w>l', opts);

-- Line moving
keymap('n', '<C-S-Up>', '<cmd>echo "c s up"<CR>', opts);

-- TODO
-- Mouse back => <C-o>
-- Mouse forward => <C-i>
keymap('n', '<X1Mouse>', '<cmd>echo "left"<CR>', opts);
keymap('n', '<X2Mouse>', '<cmd>echo "right"<CR>', opts);



