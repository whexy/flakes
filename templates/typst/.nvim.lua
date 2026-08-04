local function get_tailnet_ip()
	local handle = io.popen("tailscale ip -4 2>/dev/null")
	if not handle then
		return "127.0.0.1"
	end

	local ip = handle:read("*l")
	handle:close()
	return ip or "127.0.0.1"
end

-- Keep Tinymist pinned to the project entrypoint from every Typst buffer.
vim.lsp.config("tinymist", {
	on_attach = function(client, bufnr)
		local main = vim.fs.joinpath(client.root_dir, "src", "main.typ")
		client:exec_cmd({
			title = "pin",
			command = "tinymist.pinMain",
			arguments = { main },
		}, { bufnr = bufnr })
	end,
})

require("typst-preview").setup({
	host = get_tailnet_ip(),
	-- jobstart() only captures stderr, so send the URL back over Neovim RPC.
	open_cmd = [[nvim --server "$NVIM" --remote-expr "nvim_notify('Typst preview: %s', 2, {})"]],
	invert_colors = "auto",
	dependencies_bin = {
		-- Use the Nix-provided Tinymist rather than the plugin's bundled binary.
		["tinymist"] = "tinymist",
	},
})

-- Use the Nix-wrapped treefmt as the project formatter.
local conform = require("conform")
for _, ft in ipairs({ "typst", "nix", "lua" }) do
	conform.formatters_by_ft[ft] = { "treefmt" }
end
conform.formatters.treefmt = vim.tbl_deep_extend("force", conform.formatters.treefmt or {}, {
	-- treefmt-nix does not generate treefmt.toml, so locate the flake instead.
	cwd = require("conform.util").root_file({ "flake.nix" }),
})

-- Search DBLP and insert BibTeX citations with <leader>p.
vim.pack.add({ "https://github.com/whexy/dblp.nvim" })
vim.keymap.set("n", "<leader>p", function()
	require("dblp").search_and_insert()
end, { desc = "Search DBLP and insert BibTeX", noremap = true, silent = true })
