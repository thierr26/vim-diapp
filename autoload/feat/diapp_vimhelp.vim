" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Determine whether the currently edited file is a .txt file or not.
"
" Return value:
" Truthy value if the currently edited file is a .txt file, otherwise falsy
" value.

function s:IsTxtFile()

    return expand('%') =~? "\.txt$"

endfunction

" -----------------------------------------------------------------------------

" Return Vim help file modeline (if any, and as a list of 'setlocal' commands)
" from the currently edited file. Options present in the modeline but not in
" the following list are ignored:
"
" - 'textwidth' (or 'tw'),
"
" - 'tabstop' (or 'ts'),
"
" - 'softtabstop' (or 'sts'),
"
" - 'expandtab' (or 'et', 'noexpandtab', 'noet'),
"
" - 'rightleft' (or 'rl', 'norightleft', 'norl'),
"
" - 'ft'
"
" Return value:
" List of 'setlocal commands' (possibly empty).

function s:VimHelpModeline()

    if !s:IsTxtFile()
        " Currently edited file is not a .txt file, so it's not a Vim help
        " file.

        return [] " Early return.
    endif

    " We get there only if the currently edited file is a .txt file.

    " Modeline found on the last line of the currently edited file or empty
    " string.
    let l:modeline = lib#diapp_vimmodeline#Modeline(-1)

    if l:modeline !~? ':\s*ft=help\s*:'
        " Currently edited file has no modeline or a modeline that does not
        " specify help file type, so it's not a Vim help file.

        return [] " Early return.
    endif

    " We get there only if the currently edited file is a Vim help file.

    " Remove the " vim:" part from the modeline.
    let l:pat = lib#diapp_vimmodeline#OptPat()
    let l:modeline = substitute(l:modeline, l:pat, '', '')

    let l:enabled_opt = ['textwidth',
                \ 'tw',
                \ 'tabstop',
                \ 'ts',
                \ 'softtabstop',
                \ 'sts',
                \ 'expandtab',
                \ 'et',
                \ 'noexpandtab',
                \ 'noet',
                \ 'rightleft',
                \ 'rl',
                \ 'norightleft',
                \ 'norl']

    " Initializing 'l:ret' with '['']' makes sure the returned value won't be
    " empty.
    let l:ret = ['']

    while !empty(l:modeline)

        let l:opt = substitute(l:modeline, '\(' . l:pat . '\).*$', '\1', '')

        for o in l:enabled_opt
            if l:opt =~? '\s*' . o . '\(=[^=]\+\)\?\s*:$'
                let l:ret = l:ret + ['setlocal '
                            \ . substitute(l:opt, '\s*:\s*$', '', '')]
                break " Early loop exit.
            endif
        endfor

        let l:modeline = strpart(l:modeline, strlen(l:opt))

    endwhile

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the edited file is such that the feature state
" dictionary should be updated on a 'BufEnter' or 'FileType' event, return a
" falsy value otherwise.
"
" Return value:
" 0 or 1.

function feat#diapp_vimhelp#CannotSkipUpdate()

    return s:IsTxtFile()

endfunction

" -----------------------------------------------------------------------------

" Toggle the filetype option from empty to "help" (or conversely) for the
" currently edited file. Issue an "unavailable command" if the filetype option
" is neither empty nor "help".

function feat#diapp_vimhelp#ToggleFileType()

    if empty(&filetype)
        let &filetype = "help"
    elseif &filetype == "help"
        let &filetype = ""
    else
        call diapp#WarnUnavlCom(
                    \ "filetype option is neither empty nor \"help\"")
    endif

endfunction

" -----------------------------------------------------------------------------

" Update the feature state dictionary. The 'disabled' item is never updated and
" is assumed to be true.
"
" If the currently edited file is a Vim help file, an autocommand is set up and
" the modeline is interpreted.

function feat#diapp_vimhelp#UpdateState() dict

    let l:com = diapp#FeatStateKeyCom()
    let self[l:com] = []

    let l:modeline_opt_list = s:VimHelpModeline()

    " Truthy if the currently edited file is a Vim help file.
    let l:cur_file_is_help_file = !empty(l:modeline_opt_list)

    if l:cur_file_is_help_file

        " Set up an autocommand to update tags on buffer write.
        execute "autocmd diapp BufWritePost "
                    \ . expand('%')
                    \ . " :helptags "
                    \ . lib#diapp_file#Dir(expand('%'))

        " Execute the 'setlocal' commands contained in 'l:modeline_opt_list'.
        for c in l:modeline_opt_list
            execute c
        endfor

    endif

    let l:wuc = ":call diapp#WarnUnavlCom('current file is not a help file')"

    " -----------------------------------------------------

    let l:com_head = "-nargs=0 FT "
    if l:cur_file_is_help_file
        let self[l:com] = self[l:com] + [l:com_head
                    \ . ":call feat#diapp_vimhelp#ToggleFileType()"]
    else
        let self[l:com] = self[l:com] + [l:com_head . l:wuc]
    endif

    " -----------------------------------------------------

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
