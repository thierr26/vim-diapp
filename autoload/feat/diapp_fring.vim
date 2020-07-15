" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Base file name of the currently edited file.
"
" Return value:
" Base file name of the currently edited file.

function s:BufferBaseFileName()

    return lib#diapp_file#BaseName(expand('%'))

endfunction

" -----------------------------------------------------------------------------

" Directory containing the currently edited file.
"
" Return value:
" Directory containing the currently edited file.

function s:BufferDirName()

    return lib#diapp_file#Dir(expand('%'))

endfunction

" -----------------------------------------------------------------------------

" File ring scheme description to be used in user interface.
"
" Argument #1
" Index of an item of the 'scheme' item of the dictionary.
"
" Return value:
" String describing a file ring scheme.

function s:RingSchemeUILabel(k) dict

    let l:sens = self.scheme[a:k].case_sensitive

    return self.scheme[a:k].descr
                \ . " (case "
                \ . (l:sens ? "sensitive" : "insensitive")
                \ . ")"

endfunction

" -----------------------------------------------------------------------------

" Indices of candidate file ring schemes and indices of regular expressions in
" the schemes. The regular expressions "pointed to" by the indices match the
" name of the currently edited file.
"
" Return value:
" List (possibly empty) of dictionaries with the following items:
"
" - 'scheme_index': index of an item of the 'scheme' item of the dictionary.
"
" - 'expr_index'  : index of an item of the 'expr' of the item with index
"   'scheme_index' of the 'scheme' item of the dictionary.

function s:CandidateRingScheme() dict

    let ret = []

    let l:f = s:BufferBaseFileName()

    if empty (l:f)
        return l:ret " Early return.
    endif

    let k = 0
    for scheme in self.scheme
        let l:case_sensitive = scheme.case_sensitive
        let e_k = 0
        for e in scheme.expr
            let l:match = l:case_sensitive ? l:f =~# e : l:f =~? e
            if l:match
                let l:ret = l:ret + [{'scheme_index': k, 'expr_index': e_k}]
                break " Early loop exit (innermost loop).
            endif
            let e_k += 1
        endfor
        let k += 1
    endfor

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Path to the file which is next to the currently edited file in the ring.
"
" Argument #1
" Dictionary list as returned by 's:CandidateRingScheme'.
"
" Return value:
" String describing a file ring scheme.

function s:NextFileInRing(scheme_and_expr_index_list) dict

    let l:f = s:BufferBaseFileName()

    let l:ret = ""

    if empty (l:f)
        return l:ret " Early return.
    endif

    for scheme_and_expr_index in a:scheme_and_expr_index_list

        let l:k = scheme_and_expr_index.scheme_index
        let l:e_k = scheme_and_expr_index.expr_index

        let l:sens = self.scheme[l:k].case_sensitive
        let l:expr = self.scheme[l:k].expr[l:e_k]
        let l:group_1 = substitute(l:f, l:expr, '\1', '')

        let l:next_e_k = l:e_k + 1
        if l:next_e_k == len(self.scheme[k].expr)
            let l:next_e_k = 0
        endif

        let l:actual_expr = substitute(
                    \ self.scheme[k].expr[l:next_e_k],
                    \ '\\(\.\\+\\)',
                    \ l:group_1,
                    \ '')
                    \ . (l:sens ? '\C' : '\c')

        let l:filter = s:BufferDirName() . "/*"
        for file in glob(l:filter, 1, 1)
            if lib#diapp_file#BaseName(file) =~# l:actual_expr
                let l:ret = file
                break " Early loop exit (innermost for loop).
            endif
        endfor
        if !empty(l:ret)
            break " Early loop exit (for loop).
        endif

    endfor

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Assign script local dictionary 's:ring'.

function s:Initialize()

    let s:ring = {'candidate': function("s:CandidateRingScheme"),
                \ 'ui_label': function("s:RingSchemeUILabel"),
                \ 'next_file': function("s:NextFileInRing"),
                \ 'scheme': []}

    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "Ada (.ads for spec, .adb for body)",
                \ 'expr': ['\(.\+\)\.ads$', '\(.\+\)\.adb$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "Ada (_.ada for spec, .ada for body)",
                \ 'expr': ['\(.\+\)_\.ada$', '\(.\+\)\.ada$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "Ada (.1.ada for spec, .2.ada for body)",
                \ 'expr': ['\(.\+\)\.1\.ada$', '\(.\+\)\.2\.ada$'],
                \ 'case_sensitive': 0}]

    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C/C++ (.h for header, .c for source)",
                \ 'expr': ['\(.\+\)\.h$', '\(.\+\)\.c$'],
                \ 'case_sensitive': 0}]

    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C++ (.h for header, .cc for source)",
                \ 'expr': ['\(.\+\)\.h$', '\(.\+\)\.cc$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C++ (.hh for header, .cc for source)",
                \ 'expr': ['\(.\+\)\.hh$', '\(.\+\)\.cc$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C++ (.h for header, .cpp for source)",
                \ 'expr': ['\(.\+\)\.h$', '\(.\+\)\.cpp$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C++ (.hpp for header, .cpp for source)",
                \ 'expr': ['\(.\+\)\.hpp$', '\(.\+\)\.cpp$'],
                \ 'case_sensitive': 0}]
    let s:ring.scheme = s:ring.scheme
                \ + [{'descr': "C++ (.h for header, .cxx for source)",
                \ 'expr': ['\(.\+\)\.h$', '\(.\+\)\.cxx$'],
                \ 'case_sensitive': 0}]
    " REF: https://stackoverflow.com/a/18591926. <2020-07-14>

endfunction

" -----------------------------------------------------------------------------

" Show (using 'echo') the file ring candidates (if any).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_fring#EchoFRingCandidates(current_state)

    if empty(a:current_state.candidate)

        call diapp#Warn(s:BufferBaseFileName()
                    \ . " cannot be part of a file ring")

    else

        for k in a:current_state.candidate
            echo s:ring.ui_label(k.scheme_index)
        endfor

    endif

endfunction

" -----------------------------------------------------------------------------

" Echo (using 'echo') the next file in the ring (if any).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_fring#EchoFRingNext(current_state)

    if empty(a:current_state.candidate)

        " Let 'feat#diapp_fring#EchoFRingCandidates' issue the warning message.
        call feat#diapp_fring#EchoFRingCandidates(a:current_state)

    else

        let l:f = s:ring.next_file(a:current_state.candidate)
        if empty(l:f)
            call diapp#Warn(s:BufferBaseFileName() . " is alone in the ring")
        else
            echo l:f
        endif

    endif

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the edited file is such that the feature state
" dictionary should be updated on a 'BufEnter' or 'FileType' event, return a
" falsy value otherwise.
"
" Return value:
" 0 or 1.

function feat#diapp_fring#CannotSkipUpdate()

    return 1

endfunction

" -----------------------------------------------------------------------------

" Update the feature state dictionary. The 'disabled' item is never updated and
" is assumed to be true.

function feat#diapp_fring#UpdatedState() dict

    if !exists("s:ring")
        call s:Initialize()
    endif

    " Find the file ring candidates for the currently edited file.
    let self.candidate = s:ring.candidate()

    let l:com = diapp#FeatStateKeyCom()
    let self[l:com] = []

    " -----------------------------------------------------

    let self[l:com] = self[l:com] + ["-nargs=0 EchoFRingCandidates "
                \ . ":call diapp#RunFeatureFunc('fring', "
                \ . "function('feat#diapp_fring#EchoFRingCandidates'))"]

    let self[l:com] = self[l:com] + ["-nargs=0 EchoFRingNext "
                \ . ":call diapp#RunFeatureFunc('fring', "
                \ . "function('feat#diapp_fring#EchoFRingNext'))"]

    " -----------------------------------------------------

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
