-- Decorate the current buffer with markers for functions and classes.
--
-- Neovim Treesitter Query
-- https://www.youtube.com/watch?v=86sgKa0jeO4&ab_channel=s1n7ax
--
-- Clear everything again in the current buffer

local M = {}

M.toggle_block_markers = function()
    local ns_id = vim.api.nvim_create_namespace("bmark")

    if #vim.api.nvim_buf_get_extmarks(0, ns_id, 0, -1, {}) > 0 then
        vim.api.nvim_buf_clear_namespace(0, ns_id, 0, -1)
        return
    end

    local language = "python"
    local bufnr = vim.fn.bufnr("%")

    local language_tree = vim.treesitter.get_parser(bufnr, language)
    local syntax_tree = language_tree:parse()
    local root = syntax_tree[1]:root()

    local query_template = "((%s) @capture (#offset! @capture))"
    local params_t = {
        func = {target = "function_definition", marker = string.rep("~", 100)},
        decofunc = {target = "decorated_definition", marker = string.rep("~", 100)},
        class = {target = "class_definition", marker = string.rep("#", 100)}
    }

    for _, params in pairs(params_t) do
        local query = vim.treesitter.parse_query(
            language, string.format(query_template, params.target)
        )

        for _, _, metadata in query:iter_matches(root, bufnr) do
            line_num = metadata[1].range[1] - 1

            -- make sure there is no text on that line already
            if #vim.filetype.getlines(bufnr, line_num + 1) == 0 then
                local opts = {
                    end_line = line_num,
                    id = line_num,
                    virt_text = {{params.marker, "Comment"}},
                    virt_text_pos = "overlay"
                }

                -- Add virtual line: https://jdhao.github.io/2021/09/09/nvim_use_virtual_text/
                local mark_id = vim.api.nvim_buf_set_extmark(0, ns_id, line_num, 0, opts)
            end
        end
    end
end

return M
