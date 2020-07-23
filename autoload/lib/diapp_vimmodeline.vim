" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Vim modeline head ("vim:").
"
" Return value:
" Vim modeline head.

function s:ModelineHead()

    return "vim:"

endfunction

" -----------------------------------------------------------------------------

" Vim modeline head character length ('len("vim:")').
"
" Return value:
" Character length of Vim modeline head.

function s:ModelineHeadLength()

    return strlen(s:ModelineHead())

endfunction

" -----------------------------------------------------------------------------

" Regular expression for option searching in modelines.
"
" Return value:
" Regular expression.

function lib#diapp_vimmodeline#OptPat()
    return '^[^:]\+:'
endfunction

" -----------------------------------------------------------------------------

" Extract modeline from line provided as argument (supposed to actually contain
" a Vim modeline of the first form (see help for 'modeline' in Vim)) and with
" only colons as separators and with a trailing colon.
"
" Argument #1:
" Line (string).
"
" Return value:
" Modeline (like "vim:sw=3:ts=6:").

function s:ModelineFromLine(lin)

    let l:k = 0
    while lib#diapp_vim800func#StrCharPart(
                \ a:lin, l:k, s:ModelineHeadLength())
                \ !=# s:ModelineHead()
        let l:k += 1
    endwhile

    let l:remaining = lib#diapp_vim800func#StrCharPart(
                \ a:lin, l:k + s:ModelineHeadLength())

    let l:ret = s:ModelineHead()
    let l:pat = lib#diapp_vimmodeline#OptPat()
    while l:remaining =~? l:pat
        let l:app = substitute(l:remaining, '\(' . l:pat . '\).*$', '\1', '')
        let l:ret .= l:app
        let l:remaining = lib#diapp_vim800func#StrCharPart(
                    \ l:remaining, strlen(l:app))
    endwhile

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Return modeline for the currently edited file.
"
" Argument #1 (optional):
" The absolute value of the argument is the number of lines to explore at the
" beginning of the file (if positive value) or at the end of the file (if
" negative value). Defaults to 5.
"
" Argument #2 (optional):
" Similar to argument #1. If used, should be 0 or of a different sign than
" argument #1. Defaults to -5 (if argument #1 is not provided) or 0 (if
" argument 1 is provided).
"
" Return value:
" String (starts with 's:ModelineHead()' or is empty).

function lib#diapp_vimmodeline#Modeline(...)

    " Number of lines to explore at the beginning of the file.
    let l:b = 5

    " Number of lines to explore at the end of the file.
    let l:e = -5

    " Take optional arguments into account.
    if a:0 > 0
        if a:1 > 0
            let l:b = a:1
            let l:e = 0
        elseif a:1 < 0
            let l:e = a:1
            let l:b = 0
        endif
    endif
    if a:0 > 1
        if a:2 > l:b
            let l:b = a:2
        elseif a:2 < l:e
            let l:e = a:2
        endif
    endif

    let l:iter = 1
    for n in [l:b, l:e]

        let l:k = 0
        while (l:k < (l:iter == 1 ? l:b : (-l:e)))
            let l:k += 1
            let l:l = l:iter == 1 ? getline(l:k) : getline(line('$') + 1 - l:k)
            if l:l =~# ('\s' . s:ModelineHead())
                return s:ModelineFromLine(l:l) " Early return.
            endif
        endwhile

        " Set 'l:iter' for second loop iteration.
        let l:iter = 2
    endfor

    " We get there only if we haven't found any modeline.

    return ""

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
