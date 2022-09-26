local available, _ = pcall(require, 'lspconfig')
if not available then
	-- LSP not available
	return
end

