-- Decorate the current buffer with markers for functions and classes.
--
-- Neovim Treesitter Query
-- https://www.youtube.com/watch?v=86sgKa0jeO4&ab_channel=s1n7ax
--
-- Clear everything again in the current buffer
local api = vim.api
local fn = vim.fn
local ts = vim.treesitter

local M = {}

function M:enable_block_markers()
    self:refresh_block_markers()

    api.nvim_create_autocmd({ "InsertLeave" },
        { callback = M.refresh_block_markers, pattern = { "*.py" } })
end

function M:add_block_markers()
    local ns_id = api.nvim_create_namespace("bmark")

    local language = "python"
    local bufnr = fn.bufnr("%")

    local language_tree = ts.get_parser(bufnr, language)
    local syntax_tree = language_tree:parse()
    local root = syntax_tree[1]:root()

    local query_template = "((%s) @capture (#offset! @capture))"
    local params_t = {
        func = { target = "function_definition", marker = string.rep("~", 100) },
        decofunc = { target = "decorated_definition", marker = string.rep("~", 100) },
        class = { target = "class_definition", marker = string.rep("#", 100) }
    }

    for _, params in pairs(params_t) do
        local query = ts.query.parse(language, string.format(query_template, params.target))

        for _, _, metadata in query:iter_matches(root, bufnr) do
            local line_num = metadata[1].range[1] - 1

            -- make sure there is no text on that line already
            if #vim.fn.getbufoneline(bufnr, line_num + 1) == 0 then
                local opts = {
                    end_line = line_num,
                    id = line_num,
                    virt_text = { { params.marker, "Comment" } },
                    virt_text_pos = "overlay"
                }

                -- Add virtual line: https://jdhao.github.io/2021/09/09/nvim_use_virtual_text/
                local mark_id = api.nvim_buf_set_extmark(0, ns_id, line_num, 0, opts)
            end
        end
    end
end

function M:clear_block_markers(ns_id)
    api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
end

function M:refresh_block_markers()
    local ns_id = api.nvim_create_namespace("bmark")

    M:clear_block_markers(ns_id)
    M:add_block_markers()
end

function M:disable_block_markers()
    local ns_id = api.nvim_create_namespace("bmark")

    if #api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {}) > 0 then
        self:clear_block_markers(ns_id)

        return true
    end

    return false
end

function M:toggle_block_markers()
    local disabled = self:disable_block_markers()

    if not disabled then
        self:enable_block_markers()
    end
end

return M
