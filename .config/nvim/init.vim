lua << EOF
vim.g.loaded = 1
vim.g.loaded_newtrwPlugin = 1

require('plugins')
require('settings')
require('mappings')
require('lsp')

print('Greetings, children.')
EOF

