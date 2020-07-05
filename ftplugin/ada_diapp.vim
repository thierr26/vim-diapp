" Exit if a file type plugin has already been loaded for this buffer or if
" "compatible" mode is set.
if exists ("b:did_ftplugin") || &cp
   finish
endif

" Don't load another file type plugin for this buffer.
let b:did_ftplugin = 1

" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

let b:undo_ftplugin = "setlocal textwidth< "
            \ . "tabstop< "
            \ . "expandtab< "
            \ . "shiftwidth< "
            \ . "softtabstop< "
            \ . "softtabstop< "

" -----------------------------------------------------------------------------

" Set maximum text width.
setlocal textwidth=79

" Set width of a tabulation character.
setlocal tabstop=3

" Use spaces (not tabulation characters) when tabulation key is hit in insert
" mode.
setlocal expandtab

" Set the number of columns the text is shifted on reindent operations (<<,
" >>).
setlocal shiftwidth=3

" Set the number of columns used when hitting tabulation in insert mode.
setlocal softtabstop=3

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
