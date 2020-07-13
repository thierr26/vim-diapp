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

" List of Ada reserved as returned by 'lib#diapp_ada#ReservedWord' with GNAT
" project file specific reserved words appended ("aggregate", "extends",
" "external", "library" and "project").
"
" Return value:
" List of lower case words.

function s:ReservedWord()

    return lib#diapp_ada#ReservedWord()
                \ + ['aggregate',
                \ 'extends',
                \ 'external',
                \ 'library',
                \ 'project']

endfunction

" -----------------------------------------------------------------------------

" Convert an Ada source file name (.ads or .adb file) to the associated Ada
" unit name (with "keywords" capitalized). For example, "src/my-great_unit.ads"
" is converted to "My.Great_Unit".
"
" Argument #1:
" Absolute or relative Ada source file name.
"
" Return value:
" Ada unit name.

function s:AdaUnitName(file_name)

    let l:ret = ""

    let l:hierarchical_unit
                \ = split(lib#diapp_file#BaseNameNoExt(a:file_name), "-")

    for h in l:hierarchical_unit

        let l:keyword = split(h, "_")

        for k in l:keyword
            let l:ret .= substitute(k, '\(.\)', '\u\1', '') . '_'
        endfor
        let l:ret = substitute(l:ret, '_$', '\.', '')

    endfor
    let l:ret = substitute(l:ret, '\.$', '', '')

    return l:ret

    " REF: https://docs.adacore.com/gnat_ugn-docs/html/gnat_ugn/gnat_ugn/the_gnat_compilation_model.html#file-naming-rules
    " <2020-06-07>

    " FIXME: Make the function fully aware of the GNAT Ada file naming rules.
    " In some cases, a tilde character ("~") may be used instead of an hyphen
    " character ("-") to separate the two first hierarchical unit levels.
    " <2020-06-15>

    " IDEA: Make case conversion configurable, as the user may want some
    " "keywords" fully converted to upper case (e.g. "IO" in "Text_IO").
    " <2020-06-07>

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the provided dictionary (supposed to have been
" returned by 's:FileInfo') seems to be the one of a concrete (i.e. not
" abstract) GNAT project file and a falsy value otherwise.
"
" Argument #1:
" Dictionary as output by 's:FileInfo'.
"
" Return value:
" Truthy for a concrete (i.e. not abstract) GNAT project file, falsy otherwise.

function s:IsConcreteGNATProject() dict

    return self.kind ==? 'gnat_project' && !self.abstract

endfunction

" -----------------------------------------------------------------------------

" Return a dictionary containing various information about the Ada source file
" or project file provided as argument.
"
" The returned dictionary has at least a 'kind' item, with one of the following
" values:
"
" - ''            : the file is of an unrecognized kind of Ada file or is not
"                   an Ada file.
" - 'spec'        : the file is an Ada specification.
" - 'body'        : the file is an Ada body.
" - 'gnat_project': the file is a GNAT project file.
"
" If the value for the 'kind' item is 'gnat_project', then the dictionary also
" has the following items:
"
" - 'abstract' : 1 if the project is an abstract project, 0 otherwise.
" - 'aggregate': 1 if the project is an aggregate project, 0 otherwise.
" - 'library'  : 1 if the project is a library project, 0 otherwise.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" Dictionary.

function s:FileInfo(file_name)

    let l:ext = "." . lib#diapp_file#Ext(a:file_name)

    let l:ret = {'kind': '',
                \ 'is_concrete': function("s:IsConcreteGNATProject")}

    if l:ext ==? ".ads"
        let l:ret.kind = 'spec'
    elseif l:ext ==? ".adb"
        let l:ret.kind = 'body'
    elseif l:ext ==? ".gpr"
        let l:ret.kind = 'gnat_project'
        let l:ret.abstract = 0
        let l:ret.aggregate = 0
        let l:ret.library = 0
    endif

    if l:ret.kind ==? 'gnat_project'
                \ && lib#diapp_file#FileExists(a:file_name)
        " The file is an existing GNAT project file.

        " Load the file as a list of strings (lines).
        let l:gpr_text = readfile(a:file_name)

        " Extract lexemes until finding the project keyword and update the
        " returned dictionary items according to the found reserved words.
        let l:lexeme = []
        let l:lexer_state = {}
        while !has_key(l:lexer_state, 'd') || !l:lexer_state.d

            let l:lexer_state = lib#diapp_ada#MoveToLexemeTail(
                        \ l:gpr_text, l:lexer_state, s:ReservedWord())

            if l:lexer_state.lexeme ==? "project"
                " The lexeme is the 'project' reserved word.

                " Loop over the lexeme seen just before the 'project' reserved
                " word and update the returned dictionary items accordingly.
                for k in l:lexeme
                    if k ==? "abstract"
                        let l:ret.abstract = 1
                    elseif k ==? "aggregate"
                        let l:ret.aggregate = 1
                    elseif k ==? "library"
                        let l:ret.library = 1
                    endif
                endfor
                break " Early loop exit.
            elseif l:lexer_state.lexeme == ";"
                " The lexeme is a semicolon, probably terminating a with
                " clause.

                " Reset the lexeme list as we are not interested in the with
                " clause lexeme.
                let l:lexeme = []
            else
                " The lexeme is neither a semicolon nor the 'project' reserved
                " word.

                " Append the lexeme to the lexeme list.
                let l:lexeme = l:lexeme + [l:lexer_state.lexeme]
            endif
         endwhile

    endif

    return l:ret

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

    let l:ext = ".gpr"
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
                        let l:f_i = s:FileInfo(gpr)
                        if !l:f_i.abstract
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
                \ . (empty(a:current_state.gprbuild_opt) ? "" : " ")
                \ . a:current_state.gprbuild_opt
                \ . (empty(a:gpr) ? "" : " -P ")
                \ . a:gpr
                \ . " -p -gnatb -gnatj999 -gnatef -gnatU"

    if a:0 > 0
        " Source file argument provided and not empty.

        let l:ret = l:ret . " -U -f"

        if a:1 =~? "\.ads$"
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
        let a:current_state.gnat_project = s:FileNameForUI()
    else
        let l:f_i = s:FileInfo(a:1)
        if l:fi.is_concrete()
            let a:current_state.gnat_project = s:FileNameForUI(a:1)
        elseif l:f_i.kind !=? 'gnat_project'
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

    if empty(a:current_state.gnat_project)
        call diapp#Warn("No GNAT project selected")
    else
        echo a:current_state.gnat_project
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

    let a:current_state.gprbuild_opt = a:options

endfunction

" -----------------------------------------------------------------------------

" Reset GPRbuild options.
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#ResetGPRbuildOpt(current_state)

    let a:current_state.gprbuild_opt = ""

endfunction

" -----------------------------------------------------------------------------

" Show (using 'echo') the current GPRbuild options (if any).
"
" Argument #1:
" Current feature state dictionary.

function feat#diapp_gprbuild#EchoGPRbuildOpt(current_state)

    if empty(a:current_state.gprbuild_opt)
        call diapp#Warn("No GPRbuild options")
    else
        echo a:current_state.gprbuild_opt
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

        let l:buf_num = bufnr(l:qfitem.filename)
        if l:buf_num != -1
            let l:qfitem.bufnr = l:buf_num
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
                \ a:current_state, a:current_state.gnat_project, l:src)
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
" is assumed to be true.

function feat#diapp_gprbuild#UpdatedState() dict

    if !has_key(self, 'gnat_project')
        let self.gnat_project = diapp#GetFeatOpt(
                    \ 'gprbuild', self, 'default_gpr_file', '')
        " Not using 's:GuessedGPRFile()' as third argument to
        " 'diapp#GetFeatOpt' but only when actually needed probably speeds up
        " the function.
        if empty(self.gnat_project)
            let self.gnat_project = s:GuessedGPRFile()
        endif
    endif

    if !has_key(self, 'gprbuild_opt')
        let self.gprbuild_opt = diapp#GetFeatOpt(
                    \ 'gprbuild', self, 'default_gprbuild_options', '')
    endif

    " Reset the 'menu' item of the feature state dictionary before building
    " each menu item.

    let l:com = diapp#FeatStateKeyCom()
    let self[l:com] = []

    let l:menu = diapp#FeatStateKeyMenu()
    let self[l:menu] = {'label': "&GPRbuild", 'sub': []}

    let l:gpr_candidate = s:FileNameForUI()
    let l:ada_file_info = s:FileInfo(l:gpr_candidate)

    " -----------------------------------------------------

    let l:no_gpr_selected = "No GNAT project selected."
    let l:abst_gpr = " is abstract."

    if !empty(self.gnat_project) && l:gpr_candidate ==# self.gnat_project
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
        let l:valid_gpr_candidate = l:ada_file_info.is_concrete()

        if l:valid_gpr_candidate
            " The current file is a valid GNAT project file candidate.

            if empty(self.gnat_project)
                let l:instead_of_indication = ""
            else
                let l:instead_of_indication
                            \ = " (instead of " . self.gnat_project . ")"
            endif

            let l:lab = s:EscapeUIString(
                        \ "Select current file as GNAT &project"
                        \ . l:instead_of_indication)
        else
            " The current file is not a valid GNAT project file candidate.

            let l:sel = "The selected GNAT project is "

            if l:ada_file_info.kind ==? 'gnat_project'
                if empty(self.gnat_project)
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
                                \ . self.gnat_project
                                \ . ")")
                endif
            else
                if empty(self.gnat_project)
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:no_gpr_selected
                                \ . ")")
                else
                    let l:lab = s:EscapeUIString(
                                \ "("
                                \ . l:sel
                                \ . self.gnat_project
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
    let self[l:menu].sub
        \ = self[l:menu].sub + [l:menu_item_use_cur_file_as_gpr]

    let l:abstract_gpr_warn_msg_arg
                \ = "'current file is not a concrete GNAT project file'"

    let self[l:com] = self[l:com] + ["-nargs=0 SelectCurGPRFile "]
    if l:valid_gpr_candidate
        let self[l:com][-1] = self[l:com][-1] . l:cmd
    else
        let self[l:com][-1] = self[l:com][-1]
                    \ . ":call diapp#WarnUnavlCom("
                    \ . l:abstract_gpr_warn_msg_arg
                    \ . ")"
    endif
    let self[l:com] = self[l:com]
                \ + ["-nargs=1 -complete=file SelectGPRFile "
                \ . ":call diapp#RunFeatureFuncAndRefreshUI('gprbuild', "
                \ . "function('feat#diapp_gprbuild#SelectGPRFile'), "
                \ . "<f-args>)"]
    let self[l:com] = self[l:com]
                \ + ["-nargs=0 EchoGPRFile "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#EchoGPRFile'))"]

    " -----------------------------------------------------

    let self[l:com] = self[l:com]
                \ + ["-nargs=1 SetGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#SetGPRbuildOpt'), "
                \ . "<f-args>)"]
    let self[l:com] = self[l:com]
                \ + ["-nargs=0 ResetGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#ResetGPRbuildOpt'))"]
    let self[l:com] = self[l:com]
                \ + ["-nargs=0 EchoGPRbuildOpt "
                \ . ":call diapp#RunFeatureFunc('gprbuild', "
                \ . "function('feat#diapp_gprbuild#EchoGPRbuildOpt'))"]

    " -----------------------------------------------------

    let self[l:com] = self[l:com]
                \ + ["-nargs=0 GPRbuildCompileCurFile "]

    let l:no_gpr_selected_arg
                \ = "'" . substitute(
                \ substitute(l:no_gpr_selected, '\.$', "", ""),
                \ '^\(.\)', '\l\1', "") . "'"

    if l:ada_file_info.kind ==? 'gnat_project'
        " The current file is a GNAT project.

        " Determining whether the current file is a valid GNAT project file
        " candidate.
        let l:valid_gpr_candidate = l:ada_file_info.is_concrete()

        if l:valid_gpr_candidate
            let self[l:com][-1] = self[l:com][-1]
                        \ . ":call diapp#RunFeatureFunc('gprbuild', "
                        \ . "function('feat#diapp_gprbuild#BuildCurGNATProj'))"
            let l:ena = 1
            let l:lab = s:EscapeUIString("&Build " . s:FileNameForUI())
        else
            let self[l:com][-1] = self[l:com][-1]
                        \ . ":call diapp#WarnUnavlCom("
                        \ . l:abstract_gpr_warn_msg_arg
                        \ . ")"
            let l:ena = 0
            let l:lab = s:EscapeUIString(
                        \ "(current buffer project" . l:abst_gpr . ")")
        endif
    else
        " The current file is not a GNAT project.

        if empty(self.gnat_project)
            let self[l:com][-1] = self[l:com][-1]
                        \ . ":call diapp#WarnUnavlCom("
                        \ . l:no_gpr_selected_arg
                        \ . ")"
            let l:ena = 0
            let l:lab = s:EscapeUIString("&Compile current buffer file")
        else
            let self[l:com][-1] = self[l:com][-1]
                        \ . ":call diapp#RunFeatureFunc('gprbuild', "
                        \ . "function('feat#diapp_gprbuild#CompileCurFile'))"
            let l:ena = 1
            let l:lab = s:EscapeUIString("&Compile " . s:FileNameForUI())
        endif
    endif

    let l:map = diapp#GetFeatOpt(
                \ 'gprbuild', self, 'compile_cur_mapping', '<F10>')
    let l:cmd = ":GPRbuildCompileCurFile<CR>"
    let l:menu_item_compile_cur_file
                \ = {'label': l:lab,
                \ 'mode': "n",
                \ 'command': l:cmd,
                \ 'enabled': l:ena,
                \ 'mapping': l:map}
    let self[l:menu].sub
        \ = self[l:menu].sub + [l:menu_item_compile_cur_file]

    execute "nnoremap " . l:map . " " . l:cmd

    " -----------------------------------------------------

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
