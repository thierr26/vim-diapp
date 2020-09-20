" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Insert a pattern repeatedly. First argument (default pattern) is mandatory.
" The two other arguments are optional (zero, one or two of them can be
" provided, in any order). Allowed types for the optional arguments are
" integer and string. The two optional arguments cannot be of the same type.
"
" The number of pattern repetitions is the number needed to make 'col('$')'
" equal to the integer optional argument (or to '&textwidth' if no such
" argument is provided). The last inserted pattern may be truncated.
"
" Argument #1:
" Default pattern (string).
"
" Argument #2 (optional):
" Pattern (string) or target text width (integer).
"
" Argument #3 (optional):
" Pattern (string) or target text width (integer).

function lib#diapp_autofill#AutoFill(default_pattern, ...)

    if empty(a:default_pattern)
        " Empty value provided for 'a:default_pattern'.

        call diapp#WarnNothingDone("Empty default pattern.")
        return
    endif

    let l:line_width = &textwidth

    let l:pattern = lib#diapp_curbuf#CharUnderCursor()
    if empty(l:pattern)
        let l:pattern = a:default_pattern
    endif

    let l:line_width_arg_found = 0
    let l:pattern_arg_found = 0
    let l:err = 0

    " Loop over the list of extra arguments.
    for a in a:000

        " Make sure 'l:err' is truthy in case of early loop exit.
        let l:err = 1

        if type(a) == type(0) || (a =~ '^\s*-\?[0-9]\+\(\.[0-9]\+\)\?\s*$')
            " Current argument is a number (integer or floating point).

            if l:line_width_arg_found
                call diapp#WarnNothingDone("Too many numeric arguments.")
                return
            endif

            let l:fl = str2float(a)
            if float2nr(l:fl) != l:fl
                " 'a' has a fractional part.
                break " Early loop exit.
            endif

            let l:line_width = a
            let l:line_width_arg_found = 1

        elseif type(a) == type("")
            " Current argument is a string.

            if empty(a)
                call diapp#WarnNothingDone("Empty pattern.")
                return
            endif

            if l:pattern_arg_found
                call diapp#WarnNothingDone("Too many string arguments.")
                return
            endif

            let l:pattern = a
            let l:pattern_arg_found = 1

        else

            break " Early loop exit.

        endif

        " Make sure 'l:err' is falsy in case of normal loop termination.
        let l:err = 0

    endfor

    if l:err
        " There has been an early exit from the loop above.

        call diapp#WarnNothingDone("Don't know what to do with arguments other "
                    \ . "than integers or strings.")
        return
    endif

    " Save textwidth option value.
    let l:textwidth_save = &textwidth

    " Disable automatic line breaks.
    let &textwidth = 0

    " Fill.
    while col('$') <= l:line_width
        execute "normal! a" . l:pattern . ""
    endwhile

    " Remove the excess.
    while col('$') > l:line_width + 1
        normal! X
    endwhile

    " Restore textwidth option value.
    let &textwidth = l:textwidth_save

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
