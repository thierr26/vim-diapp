" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Return the number of the buffer containing a file or zero if the file is not
" opened in a buffer.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" Number of the buffer containing the file or zero if the file is not opened in
" a buffer.

function lib#diapp_vimbuf#FileExists(file_name)

    let l:ret = 0
    let l:buf_dic_list = getbufinfo()

    " Absolute path to the file.
    let l:f = fnamemodify(a:file_name, ':p')

    for d in l:buf_dic_list
        if d['name'] ==# l:f
            let l:ret = d['bufnr']
            break " Early loop exit.
        endif
    endfor

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
