" Title:        Add Block Markers
" Description:  A plugin to add visual guide for Python blocks.
" Last Change:  21 September 2022
" Maintainer:   Matthias Wilhelm

" Prevents the plugin from being loaded multiple times. If the loaded
" variable exists, do nothing more. Otherwise, assign the loaded
" variable and continue running this instance of the plugin.
if exists("g:loaded_addblockmarkers")
    finish
endif
let g:loaded_addblockmarkers = 1

" Exposes the plugin's functions for use as commands in Neovim.
command! -nargs=0 BlockMarkers lua require("nvim-block-markers").add_block_markers()
