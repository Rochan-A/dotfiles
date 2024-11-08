vim.cmd [[ packadd packer.nvim ]]

return require("packer").startup(function()
    use "wbthomason/packer.nvim"    -- plugin manager (can manage itself)
    use "AndrewRadev/sideways.vim"  -- Move arguments sideways
    use "tpope/vim-eunuch"          -- basic commands on current file (Rename/Remove)
    use "romainl/vim-cool"          -- only highlight search matches when searching
    use "lukas-reineke/indent-blankline.nvim"

    use {
        'andymass/vim-matchup',
        setup = function()
            vim.g.matchup_matchparen_offscreen = { method = "popup" }
        end
    }

    use {
        "jpalardy/vim-slime",
        config = function()
            vim.g.slime_target = "tmux"
        end
    }

    -- python formatter
    use {
        "astral-sh/ruff-lsp",
        ft = "python",
    }

    -- nvim lsp configuration
    use {
        "neovim/nvim-lspconfig",
        ft = {"rust", "python", "c", "cpp", "lua", "ocaml", "zig", "yaml"},
        config = function()
            vim.diagnostic.config {
                signs = false,
                update_in_insert = false,
            }
            local on_attach = function(_, bufnr)
                local opts = { noremap = true, silent = true }
                local map = function(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
                map("n", "<leader>[", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
                map("n", "<leader>]", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
                map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
                map("n", "gk", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
                map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
                map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
                map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
                map("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
                map("n", "<leader>q", "<cmd>Telescope diagnostics<CR>", opts)
                map("n", "<leader>p", "<cmd>Telescope lsp_workspace_symbols<CR>", opts)
            end
            local lspconfig = require("lspconfig")
            local capabilities = require("cmp_nvim_lsp").default_capabilities(
                vim.lsp.protocol.make_client_capabilities()
            )
            -- $ go install golang.org/x/tools/gopls
            lspconfig.gopls.setup {
                on_attach = on_attach,
                capabilities = capabilities,
                settings = {
                    gopls = {
                        analyses = {
                            unusedparams = true
                        },
                        staticcheck = true
                    }
                }
            }
            -- from: https://github.com/golang/tools/blob/master/gopls/doc/vim.md#neovim-imports
            local go_import_callback = function()
                local wait_ms = 1000
                local params = vim.lsp.util.make_range_params()
                params.context = {only = {"source.organizeImports"}}
                local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, wait_ms)
                for _, res in pairs(result or {}) do
                    for _, r in pairs(res.result or {}) do
                        if r.edit then
                            vim.lsp.util.apply_workspace_edit(r.edit, "UTF-8")
                        else
                            vim.lsp.buf.execute_command(r.command)
                        end
                    end
                end
            end
            local augroup = vim.api.nvim_create_augroup("cacharle_gopls_group", {})
            vim.api.nvim_create_autocmd(
                "BufWritePre",
                { callback = go_import_callback, pattern = "*.go", group = augroup }
            )
            -- lspconfig.clangd.setup { on_attach = on_attach }
            lspconfig.rust_analyzer.setup { on_attach = on_attach }
            -- need python-lsp-server and pyls-flake8
            lspconfig.pylsp.setup {
                on_attach = on_attach,
                capabilities = capabilities,
                settings = {
                    pylsp = {
                        plugins = {
                            flake8 = {
                                ignore = {"E501", "E221", "W503", "E241", "E402"},
                                maxLineLength = 100,
                            },
                        },
                    },
                },
            }
            -- package lua-language-server on ArchLinux
            lspconfig.lua_ls.setup {
                on_attach = on_attach ,
                settings = {
                    Lua = {
                        runtime = {
                            -- Tell the language server which version of Lua you"re using (most likely LuaJIT in the case of Neovim)
                            version = "LuaJIT",
                            -- Setup your lua path
                            path = vim.split(package.path, ";"),
                        },
                        diagnostics = {
                            -- Get the language server to recognize the `vim` global
                            globals = {"vim", "use"},
                        },
                        workspace = {
                            -- Make the server aware of Neovim runtime files
                            library = {
                                [vim.fn.expand("$VIMRUNTIME/lua")] = true,
                                [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
                            },
                        },
                    }
                },
            }
            -- brew install haskell-language-server
            lspconfig.hls.setup { on_attach = on_attach }
            -- opam install ocaml-lsp-server
            lspconfig.ocamllsp.setup { on_attach = on_attach }
            lspconfig.clangd.setup { on_attach = on_attach }
            -- pacman -S zls
            lspconfig.zls.setup{}
            -- pacman -S yaml-language-server
            lspconfig.yamlls.setup {
                settings = {
                    yaml = {
                        -- schemas = {
                        --     ["https://raw.githubusercontent.com/instrumenta/kubernetes-json-schema/master/v1.17.0-standalone-strict/all.json"] = "/*.k8s.yaml",
                        -- }
                        schemas = {
                            kubernetes = "*.yaml",
                            ["http://json.schemastore.org/github-workflow"] = ".github/workflows/*",
                            ["http://json.schemastore.org/github-action"] = ".github/action.{yml,yaml}",
                            ["http://json.schemastore.org/ansible-stable-2.9"] = "roles/tasks/*.{yml,yaml}",
                            ["http://json.schemastore.org/kustomization"] = "kustomization.{yml,yaml}",
                            ["http://json.schemastore.org/ansible-playbook"] = "*play*.{yml,yaml}",
                            ["http://json.schemastore.org/chart"] = "Chart.{yml,yaml}",
                            ["https://json.schemastore.org/gitlab-ci"] = "*gitlab-ci*.{yml,yaml}",
                            ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "*docker-compose*.{yml,yaml}",
                            ["https://raw.githubusercontent.com/argoproj/argo-workflows/master/api/jsonschema/schema.json"] = "*flow*.{yml,yaml}",
                        },
                    }
                }
            }
            lspconfig.ols.setup{ on_attach = on_attach }
        end,
    }

    -- -- rust lsp (needs rust-analyser)
    -- use {
    --     "simrat39/rust-tools.nvim",
    --     requires = {"neovim/nvim-lspconfig"},
    --     ft = {"rust"},
    --     config = function()
    --         local on_attach = function(_, bufnr)
    --             local opts = { noremap = true, silent = true }
    --             local map = function(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    --             map("n", "<leader>[", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
    --             map("n", "<leader>]", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    --             map("n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
    --             map("n", "gk", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
    --             map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
    --             map("n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
    --             map("n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
    --             map("n", "<leader>q", "<cmd>Telescope diagnostics<CR>", opts)
    --             map("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
    --         end
    --         require("rust-tools").setup {
    --             server = {
    --                 on_attach = on_attach,
    --             }
    --         }
    --         vim.diagnostic.config {
    --             signs = false,
    --             update_in_insert = false,
    --         }
    --     end
    -- }

    use {
        "hrsh7th/nvim-cmp",
        requires = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-nvim-lsp-signature-help",
            "onsails/lspkind.nvim",
            "L3MON4D3/LuaSnip",
        },
        config = function()
            local lspkind = require("lspkind")
            local cmp = require("cmp")
            local luasnip = require("luasnip")
            cmp.setup {
                mapping = cmp.mapping.preset.insert({
                    -- ["<C-n>"] = cmp.mapping.select_next_item(),
                    -- ["<C-p>"] = cmp.mapping.select_prev_item(),
                    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"] = cmp.mapping.scroll_docs(4),
                    ["<Tab>"] = cmp.mapping.confirm({ select = true }),
                    ["<C-n>"] = cmp.mapping(function(fallback)
                        local has_words_before = function()
                          unpack = unpack or table.unpack
                          local line, col = unpack(vim.api.nvim_win_get_cursor(0))
                          return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
                        end
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_jumpable() then
                            luasnip.expand_or_jump()
                        elseif has_words_before() then
                            cmp.complete()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<C-p>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),
                -- order of the sources matter (first are higher priority)
                sources = {
                    { name = "luasnip" },
                    { name = "nvim_lsp" },
                    { name = "nvim_lsp_signature_help" },
                    { name = "path" },
                    { name = "buffer", keyword_length = 2 },
                },
                formatting = {
                    format = lspkind.cmp_format({
                        with_text = true,
                        menu = {
                            nvim_lsp = "[LSP]",
                            path = "[path]",
                            buffer = "[buf]",
                        }
                    })
                },
                window = {
                    documentation = cmp.config.window.bordered(),
                },
                experimental = {
                    ghost_text = true,
                },
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end
                }
            }
        end
    }

    -- comment text objects
    use {
        "numToStr/Comment.nvim",
        config = function()
            require("Comment").setup()
        end
    }

    -- gruvbox color scheme
    use {
        "ellisonleao/gruvbox.nvim",
        requires = {"rktjmp/lush.nvim"},
        config = function()
            vim.opt.termguicolors = true
            vim.opt.background = "dark"
            vim.cmd [[ colorscheme gruvbox ]]
            vim.g.gruvbox_italic = 1
            vim.g.gruvbox_bold = 1
            vim.g.gruvbox_termcolors = 256
            vim.g.gruvbox_contrast_dark = "medium"
            vim.g.gruvbox_contrast_light = "hard"
            vim.g.gruvbox_invert_selection = 0
        end
    }

    -- status line
    use {
        "nvim-lualine/lualine.nvim",
        requires = {"kyazdani42/nvim-web-devicons"},
        config = function()
            require("lualine").setup {
                options = {
                    -- theme = "tokyonight",
                    theme = "gruvbox",
                    -- theme = "nord",
                    icons_enabled = true,
                    section_separators = '',
                    component_separators = '',
                }
            }
        end
    }

    -- better syntax highlight for everything
    use {
        "nvim-treesitter/nvim-treesitter",
        run = ":TSUpdate",
        config = function()
            require("nvim-treesitter.configs").setup {
                ensure_installed = {
                    "bash",
                    "c",
                    "cpp",
                    "go",
                    "haskell",
                    "json",
                    "lua",
                    "make",
                    "markdown",
                    "python",
                    "rust",
                    "vim",
                    "yaml",
                },
                highlight = {
                    enable = true
                },
                matchup = {
                    enable = true,              -- mandatory, false will disable the whole extension
                    -- disable = { "c", "ruby" },  -- optional, list of language that will be disabled
                    -- [options]
                },
                -- indent = { enable = true },
                -- TODO: could be neat
                -- incremental_selection = {
                --     enable = true,
                --     keymaps = {
                --         init_selection = "gnn",
                --         node_incremental = "grn",
                --         scope_incremental = "grc",
                --         node_decremental = "grm",
                --     }
                -- }
            }
            vim.cmd [[ highlight link pythonTSKeywordOperator Keyword ]]
        end
    }

    -- fuzzy finder (replace fzf.vim or ctrlp.vim)
    use {
        "nvim-telescope/telescope.nvim",
        requires = {
            {"nvim-lua/plenary.nvim"},
            {"kyazdani42/nvim-web-devicons"},
            {"nvim-telescope/telescope-symbols.nvim"},
            {
                "nvim-telescope/telescope-fzf-native.nvim",
                run = "make",
                config = function() require("telescope").load_extension("fzf") end
            },
        },
        config = function()
            local actions = require("telescope.actions")
            require("telescope").setup {
                defaults = {
                    mappings = {
                        i = {
                            ["<C-j>"] = actions.move_selection_next,
                            ["<C-k>"] = actions.move_selection_previous,
                            ["<C-u>"] = actions.delete_buffer,
                            ["<esc>"] = actions.close,
                            ["kj"] = actions.close,
                        }
                    },
                },
            }
            local map = vim.api.nvim_set_keymap
            map('n', '<C-p>', '<CMD>lua require"telescope-config".project_files()<CR>', { noremap = true, silent = true })
            map("n", "<leader>H", "<cmd>Telescope help_tags<cr>", {})
            map("n", "<leader>;", "<cmd>Telescope commands<cr>", {})
            -- map("n", "<leader>p", "<cmd>Telescope tags<cr>", {})
            map("n", "<leader>g", "<cmd>Telescope live_grep<cr>", {})
            map("n", "<leader>G", "<cmd>Telescope grep_string<cr>", {})
        end
    }

    -- todos,fix,etc.. highlight and list
    use {
        "folke/todo-comments.nvim",
        requires = "nvim-lua/plenary.nvim",
        config = function()
            require("todo-comments").setup {
                signs = false
            }
        end
    }

    use {
        "lewis6991/gitsigns.nvim",
        tag = 'release',
        config = function()
            require("gitsigns").setup {
                signcolumn = false,
                numhl = true,

                on_attach = function(bufnr)
                    local opts = { silent = true, noremap = true, expr = true }
                    -- local map = function(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
                    local function map(mode, l, r)
                        opts.buffer = bufnr
                        vim.keymap.set(mode, l, r, opts)
                    end
                    local gs = package.loaded.gitsigns
                    map(
                        "n",
                        "]c",
                        function()
                            if vim.wo.diff then return "]c" end
                            vim.schedule(function() gs.next_hunk() end)
                            return "<Ignore>"
                        end
                    )
                    map(
                        "n",
                        "[c",
                        function()
                            if vim.wo.diff then return "[c" end
                            vim.schedule(function() gs.prev_hunk() end)
                            return "<Ignore>"
                        end
                    )
                    map(
                        "n",
                        "<leader>ga",
                        function()
                            vim.schedule(function() gs.stage_hunk() end)
                            return "<Ignore>"
                        end
                    )
                    map(
                        "n",
                        "<leader>gd",
                        function()
                            vim.schedule(function() gs.undo_stage_hunk() end)
                            return "<Ignore>"
                        end
                    )
                end
            }
        end
    }

end)

