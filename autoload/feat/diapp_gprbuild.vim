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

" Name of current file (if no argument is provided) or of the file provided as
" argument, relative to current working directory if possible, to be used in
" user interface.
"
" Argument #1 (optional):
" Absolute or relative file name.
"
" Return value:
" Name of current file, relative to current working directory if possible.

function s:FileNameForUI(...)

    return lib#diapp_file#Relative(get(a:, 1, expand('%')))

endfunction

" -----------------------------------------------------------------------------

" Return an empty string (which indicates a failure of the function) or the
" relative path name of a GNAT project file located in or above the directory
" containing the file provided as argument. If no argument is provided or an
" empty string is provided, then the current working directory is used.
"
" The directory containing the file provided as argument is explored first. If
" it contains a "default.gpr" file, it's relative path name is returned.
" Otherwise other .gpr files are searched in the same directory. The ones
" describing abstract projects are excluded. If in the remaining files, one is
" matching "*_test.gpr", then it's relative path name is returned. Otherwise,
" the relative path name of another one is returned or the search continues in
" the parent directory, and so on.
"
" Argument #1 (optional):
" Absolute or relative file name (typically an Ada source file).
"
" Return value:
" Empty string or relative path name of a GNAT project file located in or above
" the directory containing the file provided as argument.

function s:GuessedGPRFile(...)

    if a:0 == 0 || empty(a:1)
        let l:dir = getcwd() . "/"
    else
        let l:dir = lib#diapp_file#Full(a:1)
    endif

    let l:ext = lib#diapp_ada#Ext('gnat_project')
    let l:default_gpr = "default" . l:ext
    let l:test_gpr_filter = '*_test' . l:ext
    let l:all_gpr_filter = '*' . l:ext
    let l:filter = [l:test_gpr_filter, l:all_gpr_filter]

    let l:ret = ""
    let l:old_dir = ""

    let l:done = 0
    while l:old_dir !=# l:dir

        let l:old_dir = l:dir
        let l:dir = lib#diapp_file#Dir(l:dir)

        let l:candidate = l:dir . "/" . l:default_gpr
        if lib#diapp_file#FileExists(l:candidate)
            let l:ret = lib#diapp_file#Relative(l:candidate)
            break " Early loop exit (while loop).
        else
            for k in l:filter
                let l:f = l:dir . "/" . k
                let l:gpr_list = glob(l:f, 0, 1)
                for gpr in l:gpr_list
                    if lib#diapp_file#FileExists(gpr)
                        let l:f_i = lib#diapp_ada#FileInfo(gpr)
                        if !l:f_i['abstract']
                            let l:ret = gpr
                            let l:done = 1
                            break " Early loop exit (innermost for loop).
                        endif
                    endif
                endfor
                if l:done
                    break " Early loop exit (for loop).
                endif
            endfor
            if l:done
                break " Early loop exit (while loop).
            endif
        endif

    endwhile

    return s:FileNameForUI(l:ret)

endfunction

" -----------------------------------------------------------------------------

" Return a GPRbuild shell command.
"
" If no source file (third argument) is provided, then the command is like:
"
" gprbuild <user opt.> -P <GNAT proj. file> -p -v
"
" If the second argument is provided, then the command is like:
"
" gprbuild <user opt.> -P <GNAT proj. file> -p -v -U -f <source file>
"
" or
"
" gprbuild <user opt.> -P <GNAT proj. file> -p -v -U -f -gnatc <source file>
"
" if the source file is an .ads file (Ada specification).
"
" <user opt.> denotes the options the user may have provided via
" 'g:diapp_gprbuild_default_gprbuild_options' or via command 'SetGPRbuildOpt'.
"
" If the GNAT project file name is empty, then the -P option is omitted.
"
" Meaning of the mentioned GPRbuild switches:
"
" -P       : Use project file provided as argument.
"
" -p       : Attempt to create missing directories (typically object files
"            directory or executable files directory).
"
" -gnatb   : Generate brief messages to stderr even if verbose mode set.
"
" -gnatj999: Treat error message with continuation lines as a single unit.
"
" -gnatef  : Display full source path name in brief error messages.
"
" -gnatU   : Force all error messages to be preceded by string ’error:’
"
" -f       : Force recompilation.
"
" -U       : Compile all sources of all projects, but if sources are specified
"            on the command line, compile only those sources.
"
" -gnatc: Check syntax and semantic only (don't do code generation).
"
" Argument #1:
" Current feature state dictionary.
"
" Argument #2:
" Absolute or relative GNAT project file name.
"
" Argument #3 (optional):
" Absolute or relative Ada source file name.
"
" Return value:
" Shell command.

function s:GPRbuildShellCommand(current_state, gpr, ...)

    let l:ret = "gprbuild"
                \ . (empty(a:current_state['gprbuild_opt']) ? "" : " ")
                \ . a:current_state['gprbuild_opt']
                \ . (empty(a:gpr) ? "" : " -P ")
                \ . a:gpr
                \ . " -p -gnatb -gnatj999 -gnatef -gnatU"

    if a:0 > 0
        " Source file argument provided and not empty.

        let l:ret = l:ret . " -U -f"

        if a:1 =~? escape(lib#diapp_ada#Ext("spec"), '.') . "$"
            " The source file is an Ada specification.

            let l:ret = l:ret . " -gnatc"
        endif

        if !empty(a:1)
            let l:ret = l:ret . " " . a:1
        endif

    endif

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Select current file (or the file provided as second argument if any) as GNAT
" project file.
"
" Argument #1:
" Current feature state dictionary.
"
" Argument #2 (optional):
" Absolute or relative file name.

function feat#diapp_gprbuild#SelectGPRFile(current_state, ...)

    if a:0 == 0
        let a:current_state['gnat_project'] = s:FileNameForUI()
    else
        let l:f_i = lib#diapp_ada#FileInfo(a:1)
        if lib#diapp_ada#IsConcreteGNATProject(l:f_i)
            let a:current_state['gnat_project'] = s:FileNameForUI(a:1)
        elseif l:f_i['kind'] !=? 'gnat_project'
            call diapp#WarnNothingDone("Not a GNAT project.")
        else
            call diapp#WarnNothingDone("Abstract GNAT project.")
        endif
    endif

endfunction

" -----------------------------------------------------------------------------

" Show (using 'echo') the selected GNAT project file (if any).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#EchoGPRFile(current_state)

    if empty(a:current_state['gnat_project'])
        call diapp#Warn("No GNAT project selected")
    else
        echo a:current_state['gnat_project']
    endif

endfunction

" -----------------------------------------------------------------------------

" Set GPRbuild options.
"
" Argument #1:
" Current feature state dictionary.
"
" Argument #2:
" GPRbuild options (e.g. "-v -XBUILD_MODE=optimizations").

function feat#diapp_gprbuild#SetGPRbuildOpt(current_state, options)

    let a:current_state['gprbuild_opt'] = a:options

endfunction

" -----------------------------------------------------------------------------

" Reset GPRbuild options.
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#ResetGPRbuildOpt(current_state)

    let a:current_state['gprbuild_opt'] = ""

endfunction

" -----------------------------------------------------------------------------

" Show (using 'echo') the current GPRbuild options (if any).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#EchoGPRbuildOpt(current_state)

    if empty(a:current_state['gprbuild_opt'])
        call diapp#Warn("No GPRbuild options")
    else
        echo a:current_state['gprbuild_opt']
    endif

endfunction

" -----------------------------------------------------------------------------

" Write all changed buffers, run a command, supposed to be an output of
" 's:GPRbuildShellCommand', populate the quickfix list and open the quickfix
" window (or close it if there's no diagnostic message to show).
"
" Argument #1:
" Shell command, supposed to be an output of 's:GPRbuildShellCommand'.
"
" Argument #2 (optional):
" Quickfix window status line.

function s:RunGPRbuildShellCommand(cmd, ...)

    " Write all changed buffers.
    wa

    echo "Running " . a:cmd

    " Run the command, capture the output and turn it to a list of lines.
    let l:cmd_output = lib#diapp_vim800func#SystemList(a:cmd)

    let l:qflist = []

    " Loop over the lines.
    for lin in l:cmd_output

        " Try to determine the index of the ":<line number>:<column number>: "
        " part of the line. Result is -1 if no such part is found.
        let l:location_pos = match(lin, ':[0-9]\+:[0-9]\+: ')

        if l:location_pos == -1
            " Current line is not a diagnostic message (error, warning or
            " note) with a file location part.

            " Stop processing the current line.
            continue
        endif

        " Extract the file name (should be an absolute file name due to the
        " '-gnatef' switch).
        let l:location_file = strpart(lin, 0, l:location_pos)

        " Extract line number and column number.
        let l:m = strpart(lin, l:location_pos + 1)
        let l:lnum = substitute(l:m, ":.*$", "", "")
        let l:m = substitute(l:m, "^[^:]*:", "", "")
        let l:col = substitute(l:m, ":.*$", "", "")

        " Extract the actual message.
        let l:m = substitute(l:m, "^[^:]*: ", "", "")

        " Initialize the message type.
        let l:type = ""

        if l:m =~? '^error: '
            " The message is actually an error message.
            let l:type = "E"
        elseif l:m =~? '^warning: '
            " The message is actually a warning message.
            let l:type = "W"
        elseif l:m =~? '^note: '
            " The message is actually a note.
            let l:type = "N"
        elseif l:m =~? '^info: '
            " The message is actually an informational message.
            let l:type = "I"
        endif
        " The list of types are taken from Vim source file quickfix.c
        " (https://github.com/vim/vim/blob/master/src/quickfix.c, function
        " qf_types). Other types might be added in the future (e.g. hint or
        " remark).
        " SEE: Vim issue #5527 (https://github.com/vim/vim/issues/5527).
        " <2020-07-05>

        if empty(l:type)
            " Message type could not be determined.

            " Do as if it was an error message.
            let l:type = "E"
        else
            " Message type could be determined.

            " Remove the part that gave us the message type, otherwise it would
            " appear twice in the quickfix list.
            let l:m = substitute(l:m, "^[^:]*: ", "", "")
        endif

        let l:qfitem = {
                    \ 'filename': lib#diapp_file#Full(l:location_file),
                    \ 'module'  : lib#diapp_file#BaseName(l:location_file),
                    \ 'lnum'    : l:lnum,
                    \ 'col'     : l:col,
                    \ 'vcol'    : 1,
                    \ 'text'    : l:m,
                    \ 'type'    : l:type}

        let l:buf_num = bufnr(l:qfitem['filename'])
        if l:buf_num != -1
            let l:qfitem['bufnr'] = l:buf_num
        endif

        let l:qflist = l:qflist + [l:qfitem]

    endfor

    call setqflist(l:qflist, 'r')

    if !empty(l:qflist)
        " There are errors or warnings in the quickfix list.

        " Open the quickfix window.
        copen

        if a:0 > 0
            " Optional argument provided.

            execute "setlocal statusline=" . s:EscapeUIString(a:1)
        endif

        " Wrap lines longer than the width of the window.
        set wrap

    else
        " There are no error or warning in the quickfix list.

        " Close the quickfix window.
        cclos

    endif

    redraw
    echomsg "("
                \ . (v:shell_error == 0
                \ ? "Passed"
                \ : "Failed [exit status " . v:shell_error . "]")
                \ . ", "
                \ . (empty(l:qflist) ? "no" : len(l:qflist))
                \ . " diag. message"
                \ . (len(l:qflist) < 2 ? "" : "s")
                \ . ") "
                \ . a:cmd

endfunction

" -----------------------------------------------------------------------------

" Build current GNAT project file.
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#BuildCurGNATProj(current_state)

    let l:gpr = s:FileNameForUI()
    let l:cmd = s:GPRbuildShellCommand(a:current_state, l:gpr)
    call s:RunGPRbuildShellCommand(l:cmd, "Build of " . l:gpr)

endfunction

" -----------------------------------------------------------------------------

" Compile current file.
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#CompileCurFile(current_state)

    let l:src = s:FileNameForUI()
    let l:cmd = s:GPRbuildShellCommand(
                \ a:current_state, a:current_state['gnat_project'], l:src)
    call s:RunGPRbuildShellCommand(l:cmd, "Compilation of " . l:src)

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the edited file is such that the feature state
" dictionary should be updated on a 'BufEnter' or 'FileType' event, return a
" falsy value otherwise.
"
" Return value:
" 0 or 1.

function feat#diapp_gprbuild#CannotSkipUpdate()

    return &filetype ==? "ada"
                \ || &filetype ==? "c"
                \ || &filetype ==? "cpp"
                \ || &filetype ==? "fortran"

endfunction

" -----------------------------------------------------------------------------

" Update the feature state dictionary. The 'disabled' item is never updated and
" is assumed to be true. The 'active' item may have been modified.
"
" Argument #1:
" Current value of the feature state dictionary.
"
" See also:
" diapp#FeatStateKeyActive

function feat#diapp_gprbuild#UpdatedState(current_state)

    " Have 'l:s' (shorter to write than "a:current_state") point to
    " 'a:current_state'.
    let l:s = a:current_state

    let l:s[diapp#FeatStateKeyActive()] = 1 " The feature is always active.

    if !l:s[diapp#FeatStateKeyActive()]
        return l:s " Early return.
    endif

    if !has_key(l:s, 'gnat_project')
        let l:s['gnat_project'] = diapp#GetFeatOpt(
                    \ 'gprbuild', l:s, 'default_gpr_file', '')
        " Not using 's:GuessedGPRFile()' as third argument to
        " 'diapp#GetFeatOpt' but only when actually needed probably speeds up
        " the function.
        if empty(l:s['gnat_project'])
            let l:s['gnat_project'] = s:GuessedGPRFile()
        endif
    endif

    if !has_key(l:s, 'gprbuild_opt')
        let l:s['gprbuild_opt'] = diapp#GetFeatOpt(
                    \ 'gprbuild', l:s, 'default_gprbuild_options', '')
    endif

    " Reset the 'menu' item of the feature state dictionary before building
    " each menu item.

    let l:com = diapp#FeatStateKeyCom()
    let l:s[l:com] = []

    let l:menu = diapp#FeatStateKeyMenu()
    let l:s[l:menu] = {'label': "&GPRbuild", 'sub': []}

    let l:gpr_candidate = s:FileNameForUI()
    let l:ada_file_info = lib#diapp_ada#FileInfo(l:gpr_candidate)

    " -----------------------------------------------------

    let l:no_gpr_selected = "No GNAT project selected."
    let l:abst_gpr = " is abstract."

    if !empty(l:s['gnat_project']) && l:gpr_candidate ==# l:s['gnat_project']
        " Current file has already been chosen as GNAT project file.

        let l:lab = s:EscapeUIString(
                    \ "("
                    \ . l:gpr_candidate
                    \ . " is already the selected GNAT project.)")
        let l:valid_gpr_candidate = 0
    else
        " Current file has not already been chosen as GNAT project file.

        " Determining whether the current file is a valid GNAT project file
        " candidate.
        let l:valid_gpr_candidate = lib#diapp_ada#IsConcreteGNATProject(
                    \ l:ada_file_info)

        if l:valid_gpr_candidate
            " The current file is a valid GNAT project file candidate.

            if empty(l:s['gnat_project'])
                let l:instead_of_indication = ""
            else
                let l:instead_of_indication
                            \ = " (instead of " . l:s['gnat_project'] . ")"
            endif

            let l:lab = s:EscapeUIString(
                        \ "Select current file as GNAT &project"
                        \ . l:instead_of_indication)
        else
            " The current file is not a valid GNAT project file candidate.

            let l:sel = "The selected GNAT project is "

            if l:ada_file_info['kind'] ==? 'gnat_project'
                if empty(l:s['gnat_project'])
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:gpr_candidate
                                \ . l:abst_gpr
                                \ . " "
                                \ . l:no_gpr_selected
                                \ . ")")
                else
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:gpr_candidate
                                \ . l:abst_gpr
                                \ . " "
                                \ . l:sel
                                \ . l:s['gnat_project']
                                \ . ")")
                endif
            else
                if empty(l:s['gnat_project'])
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:no_gpr_selected
                                \ . ")")
                else
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:sel
                                \ . l:s['gnat_project']
                                \ . ")")
                endif
            endif
        endif
    endif

    let l:cmd = ":call diapp#RunFeatureFuncAndRefreshUI('gprbuild', "
                \ . "function('feat#diapp_gprbuild#SelectGPRFile'))"
    let l:menu_item_use_cur_file_as_gpr
                \ = {'label': l:lab,
                \ 'mode': "n",
                \ 'command': l:cmd . "<CR>",
                \ 'enabled': l:valid_gpr_candidate}
    let l:s[l:menu]['sub']
        \ = l:s[l:menu]['sub'] + [l:menu_item_use_cur_file_as_gpr]

    let l:abstract_gpr_warn_msg_arg
                \ = "'current file is not a concrete GNAT project file'"

    let l:s[l:com] = l:s[l:com] + ["-nargs=0 SelectCurGPRFile "]
    if l:valid_gpr_candidate
        let l:s[l:com][-1] = l:s[l:com][-1] . l:cmd
    else
        let l:s[l:com][-1] = l:s[l:com][-1]
                    \ . ":call diapp#WarnUnavlCom("
                    \ . l:abstract_gpr_warn_msg_arg
                    \ . ")"
    endif
    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=1 -complete=file SelectGPRFile "
                \ . ":call diapp#RunFeatureFuncAndRefreshUI('gprbuild', "
                \ . "function('feat#diapp_gprbuild#SelectGPRFile'), "
                \ . "<f-args>)"]
    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=0 EchoGPRFile "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#EchoGPRFile'))"]

    " -----------------------------------------------------

    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=1 SetGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#SetGPRbuildOpt'), "
                \ . "<f-args>)"]
    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=0 ResetGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#ResetGPRbuildOpt'))"]
    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=0 EchoGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#EchoGPRbuildOpt'))"]

    " -----------------------------------------------------

    let l:s[l:com] = l:s[l:com]
                \ + ["-nargs=0 GPRbuildCompileCurFile "]

    let l:no_gpr_selected_arg
                \ = "'" . substitute(
                \ substitute(l:no_gpr_selected, '\.$', "", ""),
                \ '^\(.\)', '\l\1', "") . "'"

    if l:ada_file_info['kind'] ==? 'gnat_project'
        " The current file is a GNAT project.

        " Determining whether the current file is a valid GNAT project file
        " candidate.
        let l:valid_gpr_candidate = lib#diapp_ada#IsConcreteGNATProject(
                    \ l:ada_file_info)

        if l:valid_gpr_candidate
            let l:s[l:com][-1] = l:s[l:com][-1]
                        \ . ":call diapp#RunFeatureFunc('gprbuild', "
                        \ . "function('feat#diapp_gprbuild#BuildCurGNATProj'))"
            let l:ena = 1
            let l:lab = s:EscapeUIString("&Build " . s:FileNameForUI())
        else
            let l:s[l:com][-1] = l:s[l:com][-1]
                        \ . ":call diapp#WarnUnavlCom("
                        \ . l:abstract_gpr_warn_msg_arg
                        \ . ")"
            let l:ena = 0
            let l:lab = s:EscapeUIString(
                        \ "(current buffer project" . l:abst_gpr . ")")
        endif
    else
        " The current file is not a GNAT project.

        if empty(l:s['gnat_project'])
            let l:s[l:com][-1] = l:s[l:com][-1]
                        \ . ":call diapp#WarnUnavlCom("
                        \ . l:no_gpr_selected_arg
                        \ . ")"
            let l:ena = 0
            let l:lab = s:EscapeUIString("&Compile current buffer file")
        else
            let l:s[l:com][-1] = l:s[l:com][-1]
                        \ . ":call diapp#RunFeatureFunc('gprbuild', "
                        \ . "function('feat#diapp_gprbuild#CompileCurFile'))"
            let l:ena = 1
            let l:lab = s:EscapeUIString("&Compile " . s:FileNameForUI())
        endif
    endif

    let l:map = diapp#GetFeatOpt(
                \ 'gprbuild', l:s, 'compile_cur_mapping', '<F10>')
    let l:cmd = ":GPRbuildCompileCurFile<CR>"
    let l:menu_item_compile_cur_file
                \ = {'label': l:lab,
                \ 'mode': "n",
                \ 'command': l:cmd,
                \ 'enabled': l:ena,
                \ 'mapping': l:map}
    let l:s[l:menu]['sub']
        \ = l:s[l:menu]['sub'] + [l:menu_item_compile_cur_file]

    execute "nnoremap " . l:map . " " . l:cmd

    " -----------------------------------------------------

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
