" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Character under the cursor or empty string if there is no character under the
" cursor.
"
" Return value:
" Character under the cursor or empty string.

function lib#diapp_curbuf#CharUnderCursor()

    return matchstr(getline('.'), '\%' . col('.') . 'c.')

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
