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

-- Default configuration
local default_config = {
    auto_enable = true,     -- Auto-enable for Python files
    events = {              -- Which events trigger refresh
        "TextChanged", "TextChangedI", "BufWritePost", "InsertLeave"
    }
}

M.config = vim.deepcopy(default_config)

-- Setup function for lazy.nvim opts support
function M.setup(opts)
    opts = opts or {}
    -- Basic validation
    if opts.auto_enable ~= nil and type(opts.auto_enable) ~= "boolean" then
        vim.notify("[nvim-block-markers] Invalid value for 'auto_enable': expected boolean", vim.log.levels.WARN)
        opts.auto_enable = nil
    end
    if opts.events ~= nil and type(opts.events) ~= "table" then
        vim.notify("[nvim-block-markers] Invalid value for 'events': expected table", vim.log.levels.WARN)
        opts.events = nil
    end
    M.config = vim.tbl_deep_extend("force", default_config, opts)
    return M.config
end

-- Buffer state tracking
local buffer_states = {}
local autocommand_group = nil

-- Helper function to get buffer-specific namespace
local function get_namespace(bufnr)
    return api.nvim_create_namespace("nvim_block_markers_buffer_" .. bufnr)
end

-- Helper function to check if buffer is Python
local function is_python_buffer(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    
    -- Check if buffer is valid
    if not api.nvim_buf_is_valid(bufnr) then
        return false
    end
    
    local filetype = vim.bo[bufnr].filetype
    local filename = api.nvim_buf_get_name(bufnr)
    
    -- Check filetype first
    if filetype == 'python' then
        return true
    end
    -- Check for .py, .pyw, .pyi extensions
    if filename:match('%.py$') or filename:match('%.pyw$') or filename:match('%.pyi$') then
        return true
    end
    -- Check for extensionless files with Python shebang
    if filename ~= "" and not filename:match('%.%w+$') then
        local first_line = api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ""
        if first_line:match('^#!.*/python[0-9.]*') then
            return true
        end
    end
    return false
end

-- Setup autocommands (called once on plugin load)
function M:setup()
    if autocommand_group then
        return -- Already set up
    end
    
    autocommand_group = api.nvim_create_augroup("nvim_block_markers", { clear = true })
    
    -- Auto-enable for Python buffers (by file pattern)
    api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
        group = autocommand_group,
        pattern = {"*.py"},
        callback = function()
            local bufnr = api.nvim_get_current_buf()
            if M.config.auto_enable and is_python_buffer(bufnr) then
                M:enable_block_markers(bufnr)
            end
        end
    })
    
    -- Auto-enable for Python buffers (by filetype)
    api.nvim_create_autocmd("FileType", {
        group = autocommand_group,
        pattern = "python",
        callback = function()
            local bufnr = api.nvim_get_current_buf()
            if M.config.auto_enable then
                M:enable_block_markers(bufnr)
            end
        end
    })
    
    -- Refresh on text changes (buffer-specific, no pattern needed)
    api.nvim_create_autocmd(M.config.events, {
        group = autocommand_group,
        callback = function()
            local bufnr = api.nvim_get_current_buf()
            if buffer_states[bufnr] and is_python_buffer(bufnr) then
                M:refresh_block_markers(bufnr)
            end
        end
    })
    
    -- Clean up on buffer delete
    api.nvim_create_autocmd({"BufDelete", "BufWipeout"}, {
        group = autocommand_group,
        callback = function(args)
            buffer_states[args.buf] = nil
        end
    })
end

function M:enable_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    
    if not is_python_buffer(bufnr) then
        return false
    end
    
    buffer_states[bufnr] = true
    self:refresh_block_markers(bufnr)
    return true
end

function M:add_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    
    -- Validate buffer
    if not api.nvim_buf_is_valid(bufnr) then
        return
    end
    
    local ns_id = get_namespace(bufnr)

    local language = "python"
    
    -- Error handling for treesitter
    local ok, language_tree = pcall(ts.get_parser, bufnr, language)
    if not ok or not language_tree then
        return -- Treesitter parser not available
    end
    
    local syntax_tree = language_tree:parse()
    local root = syntax_tree[1]:root()

    local query_template = "(%s) @capture"
    local params_t = {
        func = {target = "function_definition", marker = string.rep("~", 100)},
        decofunc = {target = "decorated_definition", marker = string.rep("~", 100)},
        class = {target = "class_definition", marker = string.rep("#", 100)}
    }

    for _, params in pairs(params_t) do
        local query = vim.treesitter.query.parse(language, string.format(query_template, params.target))

        for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
            local start_row, _, _, _ = node:range()
            local line_num = start_row

            -- make sure there is no text on that line already
            local line_content = api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1] or ""
            if line_content:match("^%s*$") then
                local opts = {
                    end_line = line_num,
                    id = line_num,
                    virt_text = {{params.marker, "Comment"}},
                    virt_text_pos = "overlay"
                }

                -- Add virtual line: https://jdhao.github.io/2021/09/09/nvim_use_virtual_text/
                local mark_id = api.nvim_buf_set_extmark(bufnr, ns_id, line_num, 0, opts)
            end
        end
    end
end

function M:clear_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local ns_id = get_namespace(bufnr)
    api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

function M:refresh_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    
    if not buffer_states[bufnr] then
        return
    end
    
    self:clear_block_markers(bufnr)
    self:add_block_markers(bufnr)
end

function M:disable_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    local ns_id = get_namespace(bufnr)

    if #api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {}) > 0 then
        self:clear_block_markers(bufnr)
        buffer_states[bufnr] = false
        return true
    end

    buffer_states[bufnr] = false
    return false
end

function M:toggle_block_markers(bufnr)
    bufnr = bufnr or api.nvim_get_current_buf()
    
    if buffer_states[bufnr] then
        self:disable_block_markers(bufnr)
    else
        self:enable_block_markers(bufnr)
    end
end

-- Initialize the plugin
M.setup()

return M