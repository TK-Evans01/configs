-- =============================================================================
-- Kickstart-derived Neovim config
--
-- Layout:
--   1. Leader + global flags
--   2. Editor options
--   3. Core keymaps
--   4. Autocommands
--   5. lazy.nvim bootstrap
--   6. Plugins (each block: purpose + keymaps in header comment)
--
-- Run :checkhealth if anything misbehaves. :Lazy to manage plugins.
-- =============================================================================

-- 1. Leader -------------------------------------------------------------------
-- Must be set before plugins load.
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

-- 2. Options ------------------------------------------------------------------
-- Indentation, UI, search, splits, undo. See `:help vim.o`.
vim.o.tabstop = 2
vim.o.softtabstop = 2
vim.o.shiftwidth = 2
vim.o.expandtab = true

vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = "yes"
vim.o.scrolloff = 10
vim.o.showmode = false
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.o.mouse = "a"
vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = "split"
vim.o.confirm = true

vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true

-- Folding (driven by nvim-ufo below).
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- OS clipboard sync, scheduled to avoid startup hit.
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- 3. Core keymaps -------------------------------------------------------------
-- Esc          clear search highlight
-- <leader>q    diagnostic loclist
-- <Esc><Esc>   exit terminal mode
-- -            open parent dir in Oil
-- <C-h/j/k/l>  window navigation
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("n", "-", "<cmd>Oil<CR>", { desc = "Open parent directory (Oil)" })
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Window left" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Window right" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Window up" })

-- 4. Autocommands -------------------------------------------------------------
-- Highlight yanked text briefly.
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight on yank",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function() vim.hl.on_yank() end,
})

-- Auto-reload buffers edited externally (Claude Code, git ops, etc).
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = vim.api.nvim_create_augroup("autoread-checktime", { clear = true }),
	pattern = "*",
	command = "if mode() !~ '\\v(c|r.?|!|t)' && getcmdwintype() == '' | checktime | endif",
})
-- Go: organizeImports via gopls codeAction on save (replaces goimports binary).
vim.api.nvim_create_autocmd("BufWritePre", {
	group = vim.api.nvim_create_augroup("go-organize-imports", { clear = true }),
	pattern = "*.go",
	callback = function()
		local params = vim.lsp.util.make_range_params(0, "utf-8")
		params.context = { only = { "source.organizeImports" } }
		local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
		for _, res in pairs(result or {}) do
			for _, action in pairs(res.result or {}) do
				if action.edit then
					vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
				end
			end
		end
	end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = vim.api.nvim_create_augroup("autoread-notify", { clear = true }),
	pattern = "*",
	command = 'echohl WarningMsg | echo "File changed on disk. Buffer reloaded." | echohl None',
})

-- 5. lazy.nvim bootstrap ------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local out = vim.fn.system({
		"git", "clone", "--filter=blob:none", "--branch=stable",
		"https://github.com/folke/lazy.nvim.git", lazypath,
	})
	if vim.v.shell_error ~= 0 then error("Error cloning lazy.nvim:\n" .. out) end
end
---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- 6. Plugins ------------------------------------------------------------------
require("lazy").setup({

	-- ---------------------------------------------------------------------------
	-- guess-indent: detect tabstop/shiftwidth per file
	-- ---------------------------------------------------------------------------
	"NMAC427/guess-indent.nvim",

	-- ---------------------------------------------------------------------------
	-- gitsigns: gutter signs + hunk ops
	-- ---------------------------------------------------------------------------
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},

	-- ---------------------------------------------------------------------------
	-- oil: edit the filesystem like a buffer
	-- Keys: -  open parent dir
	-- ---------------------------------------------------------------------------
	{
		"stevearc/oil.nvim",
		priority = 1000,
		opts = {
			default_file_explorer = true,
			columns = { "icon" },
			delete_to_trash = true,
			watch_for_changes = true,
			use_default_keymaps = true,
			view_options = {
				show_hidden = true,
				is_hidden_file = function(name, _) return name:match("^%.") ~= nil end,
				natural_order = "fast",
			},
		},
	},

	-- ---------------------------------------------------------------------------
	-- which-key: popup showing pending keybinds
	-- ---------------------------------------------------------------------------
	{
		"folke/which-key.nvim",
		event = "VimEnter",
		opts = {
			delay = 0,
			icons = { mappings = vim.g.have_nerd_font, keys = vim.g.have_nerd_font and {} or {} },
			spec = {
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>t", group = "[T]est" },
				{ "<leader>d", group = "[D]ebug" },
				{ "<leader>T", group = "[T]erminal" },
				{ "<leader>r", group = "[R]eplace (project)" },
				{ "<leader>g", group = "[G]it" },
				{ "<leader>x", group = "Trouble (diagnostics)" },
				{ "<leader>h", group = "[H]arpoon" },
				{ "<leader>u", group = "[U]I toggles" },
			},
		},
	},

	-- ---------------------------------------------------------------------------
	-- telescope: fuzzy finder
	-- Keys (under <leader>):
	--   sf  files          sg  live grep         sw  word under cursor
	--   sh  help tags      sk  keymaps           sd  diagnostics
	--   ss  builtins       s.  recent files      sr  resume last search
	--   sn  nvim config    s/  grep open bufs    /   fuzzy in current buf
	--   <leader><leader>   buffers
	-- ---------------------------------------------------------------------------
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function() return vim.fn.executable("make") == 1 end,
			},
			"nvim-telescope/telescope-ui-select.nvim",
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
		},
		config = function()
			require("telescope").setup({
				extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() } },
			})
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")

			local b = require("telescope.builtin")
			vim.keymap.set("n", "<leader>sh", b.help_tags, { desc = "[S]earch [H]elp" })
			vim.keymap.set("n", "<leader>sk", b.keymaps, { desc = "[S]earch [K]eymaps" })
			vim.keymap.set("n", "<leader>sf", b.find_files, { desc = "[S]earch [F]iles" })
			vim.keymap.set("n", "<leader>ss", b.builtin, { desc = "[S]earch [S]elect" })
			vim.keymap.set("n", "<leader>sw", b.grep_string, { desc = "[S]earch [W]ord" })
			vim.keymap.set("n", "<leader>sg", b.live_grep, { desc = "[S]earch [G]rep" })
			vim.keymap.set("n", "<leader>sd", b.diagnostics, { desc = "[S]earch [D]iagnostics" })
			vim.keymap.set("n", "<leader>sr", b.resume, { desc = "[S]earch [R]esume" })
			vim.keymap.set("n", "<leader>s.", b.oldfiles, { desc = "[S]earch recent files" })
			vim.keymap.set("n", "<leader><leader>", b.buffers, { desc = "Find buffers" })
			vim.keymap.set("n", "<leader>/", function()
				b.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					winblend = 10, previewer = false,
				}))
			end, { desc = "Fuzzy in current buffer" })
			vim.keymap.set("n", "<leader>s/", function()
				b.live_grep({ grep_open_files = true, prompt_title = "Live Grep in Open Files" })
			end, { desc = "[S]earch [/] in open files" })
			vim.keymap.set("n", "<leader>sn", function()
				b.find_files({ cwd = vim.fn.stdpath("config") })
			end, { desc = "[S]earch [N]eovim files" })
		end,
	},

	-- ---------------------------------------------------------------------------
	-- LSP stack: lazydev (lua-for-nvim), lspconfig, mason
	-- Buffer keys on LspAttach:
	--   grn  rename   gra  code action   grr  references   gri  implementations
	--   grd  definition   grD  declaration   grt  type def
	--   gO   doc symbols  gW   workspace symbols
	--   <leader>ti  toggle inlay hints (if supported)
	-- ---------------------------------------------------------------------------
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } },
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			{ "j-hui/fidget.nvim", opts = {} },
			"saghen/blink.cmp",
		},
		config = function()
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event)
					local map = function(keys, func, desc, mode)
						vim.keymap.set(mode or "n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
					end
					map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
					map("gra", vim.lsp.buf.code_action, "[G]oto Code [A]ction", { "n", "x" })
					map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
					map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
					map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
					map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
					map("gO", require("telescope.builtin").lsp_document_symbols, "Document Symbols")
					map("gW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Workspace Symbols")
					map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Def")

					local function supports(client, method, bufnr)
						if vim.fn.has("nvim-0.11") == 1 then return client:supports_method(method, bufnr) end
						return client.supports_method(method, { bufnr = bufnr })
					end

					local client = vim.lsp.get_client_by_id(event.data.client_id)
					if client and supports(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
						local hl = vim.api.nvim_create_augroup("kickstart-lsp-highlight", { clear = false })
						vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
							buffer = event.buf, group = hl, callback = vim.lsp.buf.document_highlight,
						})
						vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
							buffer = event.buf, group = hl, callback = vim.lsp.buf.clear_references,
						})
						vim.api.nvim_create_autocmd("LspDetach", {
							group = vim.api.nvim_create_augroup("kickstart-lsp-detach", { clear = true }),
							callback = function(e2)
								vim.lsp.buf.clear_references()
								vim.api.nvim_clear_autocmds({ group = "kickstart-lsp-highlight", buffer = e2.buf })
							end,
						})
					end

					if client and supports(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
						map("<leader>uh", function()
							vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
						end, "[U]I toggle inlay [H]ints")
					end
				end,
			})

			vim.diagnostic.config({
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
				underline = { severity = vim.diagnostic.severity.ERROR },
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
				} or {},
				virtual_text = { source = "if_many", spacing = 2 },
			})

			-- nvim-ufo wants extra fold capabilities; merged into LSP capabilities.
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			capabilities.textDocument.foldingRange = { dynamicRegistration = false, lineFoldingOnly = true }

			-- Servers to install + configure. Add entries here for new languages.
			-- NOTE: rust_analyzer intentionally absent — rustaceanvim owns it.
			local servers = {
				clangd = {},
				gopls = {},
				pyright = {},
				ts_ls = {},
				lua_ls = {
					settings = { Lua = { completion = { callSnippet = "Replace" } } },
				},
			}

			local ensure_installed = vim.tbl_keys(servers)
			vim.list_extend(ensure_installed, {
				"stylua",
				-- formatters
				"prettierd", "ruff", "gofumpt",
				-- linters
				"eslint_d", "golangci-lint",
				-- DAP adapters (Mason installs these; nvim-dap configs below wire them up)
				"delve", "debugpy", "js-debug-adapter", "codelldb",
				-- rustfmt + clippy come with the rust toolchain (rustup)
			})
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			require("mason-lspconfig").setup({
				ensure_installed = {},
				automatic_installation = false,
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},

	-- ---------------------------------------------------------------------------
	-- conform: formatter runner; format-on-save
	-- Keys: <leader>f  format buffer
	-- ---------------------------------------------------------------------------
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		keys = {
			{
				"<leader>f",
				function() require("conform").format({ async = true, lsp_format = "fallback" }) end,
				mode = "",
				desc = "[F]ormat buffer",
			},
		},
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				local disable = { c = true, cpp = true }
				if disable[vim.bo[bufnr].filetype] then return nil end
				return { timeout_ms = 500, lsp_format = "fallback" }
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_format" },
				go = { "gofumpt" }, -- gopls handles organizeImports via on-save codeAction below
				rust = { "rustfmt", lsp_format = "fallback" },
				typescript = { "prettierd", "prettier", stop_after_first = true },
				typescriptreact = { "prettierd", "prettier", stop_after_first = true },
				javascript = { "prettierd", "prettier", stop_after_first = true },
				javascriptreact = { "prettierd", "prettier", stop_after_first = true },
			},
		},
	},

	-- ---------------------------------------------------------------------------
	-- nvim-lint: standalone linter runner (formatters live in conform)
	-- Lints on read/write/insert-leave. Add per-ft linters in `linters_by_ft`.
	-- ---------------------------------------------------------------------------
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			require("lint").linters_by_ft = {
				python = { "ruff" },
				go = { "golangcilint" },
				typescript = { "eslint_d" },
				typescriptreact = { "eslint_d" },
				javascript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				-- rust: handled by rust-analyzer + clippy via LSP
			}
			vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
				group = vim.api.nvim_create_augroup("nvim-lint", { clear = true }),
				callback = function() require("lint").try_lint() end,
			})
		end,
	},

	-- ---------------------------------------------------------------------------
	-- blink.cmp: completion engine + LuaSnip
	-- Keys (insert):  <c-y> accept   <c-space> menu/docs   <c-n>/<c-p> nav
	--                 <c-k> sig help   <c-e> hide
	-- ---------------------------------------------------------------------------
	{
		"saghen/blink.cmp",
		event = "VimEnter",
		version = "1.*",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				version = "2.*",
				build = (function()
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then return end
					return "make install_jsregexp"
				end)(),
				opts = {},
			},
			"folke/lazydev.nvim",
		},
		--- @module 'blink.cmp'
		--- @type blink.cmp.Config
		opts = {
			keymap = { preset = "default" },
			appearance = { nerd_font_variant = "mono" },
			completion = { documentation = { auto_show = false, auto_show_delay_ms = 500 } },
			sources = {
				default = { "lsp", "path", "snippets", "lazydev" },
				providers = { lazydev = { module = "lazydev.integrations.blink", score_offset = 100 } },
			},
			snippets = { preset = "luasnip" },
			fuzzy = {
				implementation = "lua",
				prebuilt_binaries = { download = false }, -- silence "fuzzy lib not downloaded" warn
			},
			signature = { enabled = true },
		},
	},

	-- ---------------------------------------------------------------------------
	-- gruvbox: colorscheme (loaded last among themes so it wins)
	-- ---------------------------------------------------------------------------
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup()
			vim.cmd.colorscheme("gruvbox")
		end,
	},

	-- ---------------------------------------------------------------------------
	-- todo-comments: highlight TODO/FIXME/NOTE in comments
	-- ---------------------------------------------------------------------------
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = { signs = false },
	},

	-- ---------------------------------------------------------------------------
	-- mini.nvim: collection of small modules
	--   ai         — better text objects.  va)  yinq  ci'
	--   surround   — gsaiw)  gsd'  gsr)'   (gs prefix to free `s` for flash)
	--   pairs      — auto bracket/quote pairing (replaces nvim-autopairs)
	--   bracketed  — ]b/[b buffer, ]d/[d diagnostic, ]q/[q quickfix, etc.
	--   statusline — minimal statusline
	-- ---------------------------------------------------------------------------
	{
		"echasnovski/mini.nvim",
		config = function()
			require("mini.ai").setup({ n_lines = 500 })
			-- Prefix `gs` (not `s`) so flash.nvim's `s` jump still works.
			-- gsa<motion>X  add  |  gsd  delete  |  gsr  replace  |  gsf/gsF find
			require("mini.surround").setup({
				mappings = {
					add = "gsa", delete = "gsd", replace = "gsr",
					find = "gsf", find_left = "gsF",
					highlight = "gsh", update_n_lines = "gsn",
				},
			})
			require("mini.pairs").setup()
			require("mini.bracketed").setup()
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = vim.g.have_nerd_font })
			---@diagnostic disable-next-line: duplicate-set-field
			statusline.section_location = function() return "%2l:%-2v" end
		end,
	},

	-- ---------------------------------------------------------------------------
	-- treesitter (main branch rewrite): parsers + queries only.
	-- Highlight/indent wired via core Neovim APIs in FileType autocmd below.
	-- Requires gcc/clang + git on PATH for parser compile.
	-- ---------------------------------------------------------------------------
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = function()
			require("nvim-treesitter").update()
		end,
		config = function()
			local parsers = {
				"bash", "c", "diff", "html", "lua", "luadoc",
				"markdown", "markdown_inline", "query", "vim", "vimdoc",
				"typescript", "tsx", "javascript", "jsdoc",
				"python", "go", "gomod", "gosum", "rust",
				"json", "jsonc", "yaml", "toml", "dockerfile", "gitignore", "gitcommit",
			}
			local installed = require("nvim-treesitter").get_installed("parsers")
			local missing = vim.tbl_filter(function(p)
				return not vim.tbl_contains(installed, p)
			end, parsers)
			if #missing > 0 then
				require("nvim-treesitter").install(missing)
			end

			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("ts-highlight", { clear = true }),
				callback = function(args)
					local ft = vim.bo[args.buf].filetype
					local lang = vim.treesitter.language.get_lang(ft)
					if lang and vim.treesitter.language.add(lang) then
						vim.treesitter.start(args.buf, lang)
						-- indent via treesitter (skip ruby)
						if ft ~= "ruby" then
							vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
						end
					end
				end,
			})
		end,
	},

	-- ---------------------------------------------------------------------------
	-- treesitter-textobjects (main branch): select/move by function, class, etc.
	-- Keys:  vif/vaf  inside/around function    vic/vac  inside/around class
	--        ]f / [f  next/prev function start  ]c / [c  next/prev class start
	-- ---------------------------------------------------------------------------
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		event = "VeryLazy",
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = { lookahead = true },
				move = { set_jumps = true },
			})

			local select = require("nvim-treesitter-textobjects.select")
			local move = require("nvim-treesitter-textobjects.move")

			local sel_map = {
				["af"] = "@function.outer", ["if"] = "@function.inner",
				["ac"] = "@class.outer",    ["ic"] = "@class.inner",
				["aa"] = "@parameter.outer", ["ia"] = "@parameter.inner",
			}
			for lhs, query in pairs(sel_map) do
				vim.keymap.set({ "x", "o" }, lhs, function()
					select.select_textobject(query, "textobjects")
				end, { desc = "Select " .. query })
			end

			vim.keymap.set({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function start" })
			vim.keymap.set({ "n", "x", "o" }, "]c", function() move.goto_next_start("@class.outer", "textobjects") end, { desc = "Next class start" })
			vim.keymap.set({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Prev function start" })
			vim.keymap.set({ "n", "x", "o" }, "[c", function() move.goto_previous_start("@class.outer", "textobjects") end, { desc = "Prev class start" })
		end,
	},

	-- ---------------------------------------------------------------------------
	-- treesitter-context: sticky header showing current function/class
	-- ---------------------------------------------------------------------------
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = "BufReadPost",
		opts = { max_lines = 3 },
	},

	-- ---------------------------------------------------------------------------
	-- nvim-ufo: real folding via LSP/treesitter
	-- Keys:  zR  open all   zM  close all   zo/zc  fold under cursor
	-- ---------------------------------------------------------------------------
	{
		"kevinhwang91/nvim-ufo",
		dependencies = { "kevinhwang91/promise-async" },
		event = "BufReadPost",
		config = function()
			require("ufo").setup({
				provider_selector = function() return { "treesitter", "indent" } end,
			})
			vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
			vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
		end,
	},

	-- ---------------------------------------------------------------------------
	-- trouble: pretty diagnostics, refs, quickfix, todo lists
	-- Keys (under <leader>x):
	--   xx  diagnostics (buf)   xX  diagnostics (workspace)
	--   xs  symbols             xl  LSP refs/defs        xq  quickfix   xL  loclist
	-- ---------------------------------------------------------------------------
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		opts = {},
		keys = {
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (buffer)" },
			{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Diagnostics (workspace)" },
			{ "<leader>xs", "<cmd>Trouble symbols toggle focus=false<cr>", desc = "Symbols" },
			{ "<leader>xl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP refs/defs" },
			{ "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix" },
			{ "<leader>xL", "<cmd>Trouble loclist toggle<cr>", desc = "Loclist" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- harpoon (v2): pin a small set of files; jump by index
	-- Keys:  <leader>ha  add file       <leader>he  toggle menu
	--        <leader>1..4  jump to slot 1..4
	-- ---------------------------------------------------------------------------
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local h = require("harpoon")
			h:setup()
			vim.keymap.set("n", "<leader>ha", function() h:list():add() end, { desc = "[H]arpoon [A]dd" })
			vim.keymap.set("n", "<leader>he", function() h.ui:toggle_quick_menu(h:list()) end, { desc = "[H]arpoon m[E]nu" })
			for i = 1, 4 do
				vim.keymap.set("n", "<leader>" .. i, function() h:list():select(i) end, { desc = "Harpoon " .. i })
			end
		end,
	},

	-- ---------------------------------------------------------------------------
	-- undotree: visualize undo history
	-- Keys:  <leader>uu  toggle
	-- ---------------------------------------------------------------------------
	{
		"mbbill/undotree",
		cmd = "UndotreeToggle",
		keys = {
			{ "<leader>uu", "<cmd>UndotreeToggle<cr>", desc = "[U]ndotree toggle" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- render-markdown: nicer markdown rendering inside the buffer
	-- ---------------------------------------------------------------------------
	{
		"MeanderingProgrammer/render-markdown.nvim",
		dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
		ft = { "markdown" },
		opts = {},
	},

	-- ---------------------------------------------------------------------------
	-- taboo: rename tabs (`:TabooRename foo`)
	-- ---------------------------------------------------------------------------
	{
		"gcmt/taboo.vim",
		init = function()
			vim.g.taboo_tab_format = " %N: %f%m "
			vim.g.taboo_renamed_tab_format = " %N: %l%m "
		end,
	},

	-- ---------------------------------------------------------------------------
	-- flash: jump anywhere visible with s{char}{char}
	-- Keys:  s  jump    S  treesitter jump    r (op-pending)  remote
	-- ---------------------------------------------------------------------------
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{ "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
			{ "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
			{ "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- spectre: project-wide find/replace UI
	-- Keys:  <leader>rr  open    <leader>rw  open with word under cursor
	-- ---------------------------------------------------------------------------
	{
		"nvim-pack/nvim-spectre",
		dependencies = { "nvim-lua/plenary.nvim" },
		keys = {
			{ "<leader>rr", function() require("spectre").open() end, desc = "[R]eplace open" },
			{ "<leader>rw", function() require("spectre").open_visual({ select_word = true }) end, desc = "[R]eplace [W]ord" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- diffview: full diff/merge/file-history viewer
	-- Keys:  <leader>gd  diff    <leader>gh  file history    <leader>gc  close
	-- ---------------------------------------------------------------------------
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
		keys = {
			{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "[G]it [D]iffview" },
			{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "[G]it file [H]istory" },
			{ "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "[G]it diffview [C]lose" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- toggleterm: floating/split terminals
	-- Keys:  <c-\>  toggle    <leader>Tf  float    <leader>Tt  horizontal
	--        <leader>Tg  lazygit float
	-- (capital T to leave <leader>t* free for neotest)
	-- ---------------------------------------------------------------------------
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		opts = {
			open_mapping = [[<c-\>]],
			direction = "float",
			float_opts = { border = "curved" },
		},
		keys = {
			{ "<leader>Tf", "<cmd>ToggleTerm direction=float<cr>", desc = "[T]erm [F]loat" },
			{ "<leader>Tt", "<cmd>ToggleTerm direction=horizontal size=15<cr>", desc = "[T]erm horizon[T]al" },
			{ "<leader>Tg", "<cmd>TermExec cmd=lazygit direction=float<cr>", desc = "[T]erm lazy[G]it" },
		},
	},

	-- ---------------------------------------------------------------------------
	-- rustaceanvim: full Rust experience (rust-analyzer + DAP + neotest adapter)
	-- Replaces the rust_analyzer entry in lspconfig. DO NOT also use neotest-rust.
	-- Keys (filetype rust):  <leader>cR  rustacean code-action menu (runnables/etc.)
	-- ---------------------------------------------------------------------------
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = { "rust" },
		init = function()
			vim.g.rustaceanvim = {
				server = {
					default_settings = {
						["rust-analyzer"] = {
							cargo = { allFeatures = true },
							check = { command = "clippy" },
						},
					},
				},
			}
		end,
	},

	-- ---------------------------------------------------------------------------
	-- nvim-dap: Debug Adapter Protocol client + UI + virtual text
	-- Keys (under <leader>d):
	--   db  toggle breakpoint     dB  conditional breakpoint
	--   dc  continue / start      dC  run to cursor
	--   di  step into             do  step over            dO  step out
	--   dr  open REPL             dl  run last
	--   du  toggle UI             dt  terminate
	--   K   (in debug) hover value via dap-ui
	-- ---------------------------------------------------------------------------
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"nvim-neotest/nvim-nio",
			{ "rcarriga/nvim-dap-ui", opts = {} },
			{ "theHamsta/nvim-dap-virtual-text", opts = {} },
			{
				"jay-babu/mason-nvim-dap.nvim",
				dependencies = "mason-org/mason.nvim",
				opts = {
					automatic_installation = true,
					handlers = {}, -- default handlers; per-language plugins override below
					ensure_installed = { "delve", "python", "js", "codelldb" },
				},
			},
			-- per-language helpers
			{ "leoluz/nvim-dap-go", opts = {} },
			{
				"mfussenegger/nvim-dap-python",
				config = function()
					local mason = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
					require("dap-python").setup(mason)
				end,
			},
			{
				"mxsdev/nvim-dap-vscode-js",
				config = function()
					require("dap-vscode-js").setup({
						debugger_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter",
						debugger_cmd = { "js-debug-adapter" },
						adapters = {
							"pwa-node", "pwa-chrome", "pwa-msedge",
							"node-terminal", "pwa-extensionHost",
						},
					})
					for _, lang in ipairs({ "typescript", "javascript", "typescriptreact", "javascriptreact" }) do
						require("dap").configurations[lang] = {
							{
								type = "pwa-node", request = "launch", name = "Launch file",
								program = "${file}", cwd = "${workspaceFolder}",
							},
							{
								type = "pwa-node", request = "attach", name = "Attach",
								processId = require("dap.utils").pick_process,
								cwd = "${workspaceFolder}",
							},
							{
								type = "pwa-node", request = "launch", name = "Debug Jest test",
								runtimeExecutable = "node",
								runtimeArgs = { "./node_modules/jest/bin/jest.js", "--runInBand" },
								rootPath = "${workspaceFolder}", cwd = "${workspaceFolder}",
								console = "integratedTerminal", internalConsoleOptions = "neverOpen",
							},
							{
								type = "pwa-node", request = "launch", name = "Debug Vitest test",
								runtimeExecutable = "node",
								runtimeArgs = { "./node_modules/vitest/vitest.mjs", "run" },
								rootPath = "${workspaceFolder}", cwd = "${workspaceFolder}",
								console = "integratedTerminal", internalConsoleOptions = "neverOpen",
							},
						}
					end
				end,
			},
		},
		keys = {
			{ "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "[D]ebug [B]reakpoint" },
			{ "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Cond: ")) end, desc = "[D]ebug cond [B]reakpoint" },
			{ "<leader>dc", function() require("dap").continue() end, desc = "[D]ebug [C]ontinue" },
			{ "<leader>dC", function() require("dap").run_to_cursor() end, desc = "[D]ebug run to [C]ursor" },
			{ "<leader>di", function() require("dap").step_into() end, desc = "[D]ebug step [I]nto" },
			{ "<leader>do", function() require("dap").step_over() end, desc = "[D]ebug step [O]ver" },
			{ "<leader>dO", function() require("dap").step_out() end, desc = "[D]ebug step [O]ut" },
			{ "<leader>dr", function() require("dap").repl.toggle() end, desc = "[D]ebug [R]EPL" },
			{ "<leader>dl", function() require("dap").run_last() end, desc = "[D]ebug run [L]ast" },
			{ "<leader>du", function() require("dapui").toggle() end, desc = "[D]ebug toggle [U]I" },
			{ "<leader>dt", function() require("dap").terminate() end, desc = "[D]ebug [T]erminate" },
		},
		config = function()
			local dap, dapui = require("dap"), require("dapui")
			dap.listeners.before.attach.dapui_config = function() dapui.open() end
			dap.listeners.before.launch.dapui_config = function() dapui.open() end
			dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
			dap.listeners.before.event_exited.dapui_config = function() dapui.close() end

			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapStopped",    { text = "→", texthl = "DiagnosticWarn" })
		end,
	},

	-- ---------------------------------------------------------------------------
	-- neotest: unified test runner
	-- Adapters: jest, vitest, playwright, python (pytest), go (rust via rustaceanvim)
	-- Keys (under <leader>t):
	--   tn  nearest      tf  file        tl  last        tw  watch file
	--   ts  summary      to  output      tO  output panel
	--   td  debug nearest (uses nvim-dap)              tS  stop
	-- ---------------------------------------------------------------------------
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			"antoinemadec/FixCursorHold.nvim",
			"nvim-treesitter/nvim-treesitter",
			"mfussenegger/nvim-dap",
			-- adapters
			"nvim-neotest/neotest-jest",
			"marilari88/neotest-vitest",
			"thenbe/neotest-playwright",
			"nvim-neotest/neotest-python",
			"nvim-neotest/neotest-go",
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-jest")({
						-- auto-detect package manager from lockfile
						jestCommand = function()
							local cwd = vim.fn.getcwd()
							if vim.fn.filereadable(cwd .. "/pnpm-lock.yaml") == 1 then return "pnpm test --" end
							if vim.fn.filereadable(cwd .. "/yarn.lock") == 1 then return "yarn test --" end
							if vim.fn.filereadable(cwd .. "/bun.lockb") == 1 then return "bun test --" end
							return "npm test --"
						end,
						env = { CI = true },
					}),
					require("neotest-vitest"),
					require("neotest-playwright").adapter({
						options = {
							persist_project_selection = true,
							enable_dynamic_test_discovery = true,
						},
					}),
					require("neotest-python")({ dap = { justMyCode = false } }),
					require("neotest-go"),
					-- rust adapter is auto-registered by rustaceanvim:
					vim.g.rustaceanvim and require("rustaceanvim.neotest") or nil,
				},
				status = { virtual_text = true },
				output = { open_on_run = true },
			})
		end,
		keys = {
			{ "<leader>tn", function() require("neotest").run.run() end, desc = "[T]est [N]earest" },
			{ "<leader>tf", function() require("neotest").run.run(vim.fn.expand("%")) end, desc = "[T]est [F]ile" },
			{ "<leader>tl", function() require("neotest").run.run_last() end, desc = "[T]est [L]ast" },
			{ "<leader>tw", function() require("neotest").watch.toggle(vim.fn.expand("%")) end, desc = "[T]est [W]atch file" },
			{ "<leader>ts", function() require("neotest").summary.toggle() end, desc = "[T]est [S]ummary" },
			{ "<leader>to", function() require("neotest").output.open({ enter = true, auto_close = true }) end, desc = "[T]est [O]utput" },
			{ "<leader>tO", function() require("neotest").output_panel.toggle() end, desc = "[T]est [O]utput panel" },
			{ "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, desc = "[T]est [D]ebug nearest" },
			{ "<leader>tS", function() require("neotest").run.stop() end, desc = "[T]est [S]top" },
		},
	},

}, {
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘", config = "🛠", event = "📅", ft = "📂", init = "⚙",
			keys = "🗝", plugin = "🔌", runtime = "💻", require = "🌙",
			source = "📄", start = "🚀", task = "📌", lazy = "💤 ",
		},
	},
})

-- vim: ts=2 sts=2 sw=2 et
