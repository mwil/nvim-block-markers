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
command! -nargs=0 BlockMarkerToggle lua require("nvim-block-markers").toggle_block_markers()
command! -nargs=0 BlockMarkerEnable lua require("nvim-block-markers").enable_block_markers()
command! -nargs=0 BlockMarkerDisable lua require("nvim-block-markers").disable_block_markers()
