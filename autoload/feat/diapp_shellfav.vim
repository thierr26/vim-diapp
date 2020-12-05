" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Return input string with 'escape' function applied.
"
" Argument #1:
" Menu item full label.
"
" Return value:
" Return value of escape(<argument #1>, '\.')

function s:EscapeUIString(menu_label)

    return escape(a:menu_label, ' \.')

endfunction

" -----------------------------------------------------------------------------

" Return the menu label for a favorite shell command (mapping not included).
"
" Argument #1:
" Current feature state dictionary.
"
" Argument #2:
" Favorite command dictionary (with at least 'cmd' and 'alias' keys).
"
" Return value:
" Menu label for the favorite shell command (already passed through
" 's:EscapeUIString'.

function s:MenuLabel(s, fav)

    let l:label = a:fav.alias . " (" . a:fav.cmd . ")"

    let l:label_chars = strchars(l:label)

    let l:max_chars = diapp#GetFeatOpt('shellfav',
                \ a:s,
                \ 'menu_label_max_length',
                \ '50')

    if l:label_chars > l:max_chars

        if l:max_chars <= 7

            let l:label = "..."

        else

            let l:label = lib#diapp_vim800func#StrCharPart
                        \ (l:label, 0, l:max_chars - 5) . "...)"

        endif

    endif

    return s:EscapeUIString(l:label)

endfunction

" -----------------------------------------------------------------------------

" Show (using 'echo') the favorite shell commands.
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_shellfav#EchoShellFavs(s)

    if empty(a:s.fav)

        call diapp#Warn("No favorite shell commands defined")

    else

        for f in a:s.fav

            if !empty(f.key)
                let l:key_head = "," . f.key . ","
            else
                let l:key_head = ""
            endif

            echo l:key_head . f.alias . "," . f.cmd

        endfor

    endif

endfunction

" -----------------------------------------------------------------------------

" Read favorite shell commands from file.
"
" The file read is the one specified in g:diapp_shellfav_file_name (if it
" exists) or diapp_shellfavs.txt (if it exists).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_shellfav#ReadShellFavFile(s)

    let l:file = diapp#GetFeatOpt('shellfav',
                \ a:s,
                \ 'file_name',
                \ 'diapp_shellfavs.txt')

    let l:fav = []

    if lib#diapp_file#FileExists(l:file)

        let l:abort_cause = ""

        " Maxmum allowed number of lines for the file.
        let l:max_line = diapp#GetFeatOpt('shellfav',
                \ a:s,
                \ 'file_max_line_count',
                \ '10')

        " Load the file as a list of strings (lines).
        let l:line = readfile(l:file, '', l:max_line + 1)

        if len(l:line) == l:max_line + 1
            let l:abort_cause = "too many lines"
        endif

        if empty(l:abort_cause)

            " Maxmum byte length allowed for a line of the file.
            let l:max_line_length = diapp#GetFeatOpt('shellfav',
                    \ a:s,
                    \ 'file_line_max_length',
                    \ '300')

            for l in l:line

                if empty(l)
                    continue
                endif

                if !empty(l:abort_cause)
                    break
                endif

                if strlen(l) > l:max_line_length

                    let l:abort_cause = "line too long"
                    break

                else

                    let l:key = ""
                    let l:alias = ""
                    let l:cmd = ""

                    let l:exp_comas = 1
                    let l:found_comas = 0
                    let l:prev_coma_idx = -1
                    let l:char_count = strchars(l)
                    let l:k = 0

                    while l:k < l:char_count

                        let l:is_coma = lib#diapp_vim800func#StrCharPart
                                    \ (l, l:k, 1) == ","

                        if l:k == 0 && l:is_coma
                            let l:exp_comas = 3
                        endif

                        if l:is_coma

                            if l:exp_comas == 3 && l:found_comas == 1

                                let l:key = lib#diapp_vim800func#StrCharPart
                                            \ (l, 1, l:k - 1)

                            elseif (l:exp_comas == 3 && l:found_comas == 2)
                                        \ || (l:exp_comas == 1
                                        \ && l:found_comas == 0)

                                let l:alias = lib#diapp_vim800func#StrCharPart
                                            \ (l, l:prev_coma_idx + 1,
                                            \ l:k - l:prev_coma_idx - 1)

                            endif

                            let l:found_comas = l:found_comas + 1
                            if l:found_comas <= l:exp_comas
                                let l:prev_coma_idx = l:k
                            endif

                        endif

                        if l:k == l:char_count - 1

                            let l:cmd = lib#diapp_vim800func#StrCharPart
                                        \ (l, l:prev_coma_idx + 1)
                            if l:found_comas < l:exp_comas
                                        \ || (l:exp_comas == 3 && empty(l:key))
                                        \ || empty(l:alias)
                                        \ || empty(l:cmd)
                                let l:abort_cause = "invalid file format"
                            endif

                        endif

                        let l:k = l:k + 1

                    endwhile

                    let l:fav = l:fav + [{
                                \ 'key'  : l:key,
                                \ 'alias': l:alias,
                                \ 'cmd'  : l:cmd}]

                endif

            endfor

        endif

        if !empty(l:abort_cause)
            call diapp#Warn('Stop reading file "'
                        \ . l:file
                        \ . '" ('
                        \ . l:abort_cause
                        \ . ')')
            let l:fav = []
        endif

    endif

    let a:s.fav = l:fav

endfunction

" -----------------------------------------------------------------------------

" Launch a favorite shell command.
"
" Argument #1:
" Current feature state dictionary.
"
" Argument #2:
" Alias for the favorite shell command.

function feat#diapp_shellfav#LaunchShellFav(s, alias)

    let l:cmd = ""

    for f in a:s.fav

        if f.alias == a:alias
            let l:cmd = f.cmd
            break
        endif

    endfor

    if empty(l:cmd)
        call diapp#Warn("Unknown alias")
    else
        call call('diapp#StoreFeatureFuncCall',
                    \ [diapp#StateKeyLastExtCmd(),
                    \ 'feat#diapp_shellfav#LaunchShellFav',
                    \ a:alias])
        execute "!" . l:cmd
    endif

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the edited file is such that the feature state
" dictionary should be updated on a 'BufEnter' or 'FileType' event, return a
" falsy value otherwise.
"
" Return value:
" 0 or 1.

function feat#diapp_shellfav#CannotSkipUpdate()

    " For the favorite shell commands feature, feature state dictionary must
    " be systematically updated.
    return 1

endfunction

" -----------------------------------------------------------------------------

" Update the feature state dictionary. The 'disabled' item is never updated and
" is assumed to be true.

function feat#diapp_shellfav#UpdateState() dict

    if !has_key(self, 'startup_done') || !self.startup_done

        call feat#diapp_shellfav#ReadShellFavFile(self)
        let self.startup_done = 1

    endif

    " Reset the 'menu' item of the feature state dictionary before building
    " each menu item.
    let l:menu = diapp#FeatStateKeyMenu()
    let self[l:menu] = {'label': "She&llFavs", 'sub': []}

    let l:com = diapp#FeatStateKeyCom()
    let self[l:com] = []

    let l:map = diapp#FeatStateKeyMap()
    let self[l:map] = []

    " -----------------------------------------------------

    let self[l:com] = self[l:com] + ["-nargs=0 EchoShellFavs "
                \ . ":call diapp#RunFeatureFunc("
                \ . "'feat#diapp_shellfav#EchoShellFavs')"]

    let self[l:com] = self[l:com] + ["-nargs=0 ReadShellFavsFile "
                \ . ":call diapp#RunFeatureFuncAndRefreshUI("
                \ . "'feat#diapp_shellfav#ReadShellFavFile')"]

    let self[l:com] = self[l:com] + ["-nargs=1 SF "
                \ . ":call diapp#RunFeatureFuncAndRefreshUI("
                \ . "'feat#diapp_shellfav#LaunchShellFav', "
                \ . "<f-args>)"]

    " -----------------------------------------------------

    for f in self.fav

        let l:cmd = ":SF " . f.alias . "<CR>"

        let self[l:menu].sub
                    \ = self[l:menu].sub
                    \ + [{'label': s:MenuLabel(self, f),
                    \ 'mode': "n",
                    \ 'command': l:cmd,
                    \ 'enabled': 1,
                    \ 'mapping': f.key}]

        if !empty(f.key)
            let self[l:map] = self[l:map] + ["nnoremap " . f.key . " " . l:cmd]
        endif

    endfor

    " -----------------------------------------------------

    if !empty(self.fav)

        let self[l:menu].sub
                    \ = self[l:menu].sub
                    \ + [{'label': '-sep-',
                    \ 'mode': "n",
                    \ 'command': ':',
                    \ 'enabled': 1}]

        let self[l:menu].sub
                    \ = self[l:menu].sub
                    \ + [{'label': s:EscapeUIString(
                    \ '&Refresh favorite shell commands'),
                    \ 'mode': "n",
                    \ 'command': ":ReadShellFavsFile<CR>",
                    \ 'enabled': 1}]

    endif

    " -----------------------------------------------------

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
