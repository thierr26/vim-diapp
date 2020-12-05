" Exit if a file type plugin has already been loaded for this buffer or if
" "compatible" mode is set.
if exists ("g:loaded_diapp") || &cp
   finish
endif

" Don't load the plugin twice.
let g:loaded_diapp = 1

" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

let s:default_min_refresh_period = 1.8 " seconds.

" -----------------------------------------------------------------------------

" Take a variable identifier (a string) as first argument and return the value
" of the variable if it exists or the value of the second argument.
"
" Argument #1:
" Variable identifier.
"
" Argument #2:
" Substitution value.
"
" Return value:
" Can be anything.

function s:Get(identifier, default)

    return exists(a:identifier) ? {a:identifier} : a:default

endfunction

" -----------------------------------------------------------------------------

" Take a variable identifier (a string) as first argument and return:
"
" - 0 if the first argument is the identifier of an existing variable with a
"   falsy value or the first argument is not the identifier of an existing
"   variable and the second argument is falsy or not provided.
"
" - 1 if the first argument is the identifier of an existing variable with a
"   truthy value or the first argument is not the identifier of an existing
"   variable and the second argument is provided and truthy.
"
" Argument #1:
" Variable identifier.
"
" Argument #2 (optional):
" 0 or 1. Defaults to 0.
"
" Return value:
" 0 or 1.

function s:GetFlag(identifier, ...)

    return s:Get(a:identifier, get(a:, 1, 0)) ? 1 : 0

endfunction

" -----------------------------------------------------------------------------

" Issue a warning message.
"
" Argument #1:
" Warning message.

function diapp#Warn(msg)

    echohl WarningMsg
    echo a:msg
    echohl None

endfunction

" -----------------------------------------------------------------------------

" Return the value of a feature option, that is the value of global variable
" 'g:diapp_<feat>_<id>' or <default> if the global variable does not exist.
"
" - <feat>: Feature name, first argument.
"
" - <id>: Option identifier, third argument.
"
" - <default>: Default value, fourth argument.
"
" The feature state dictionary must be provided (second argument). It is used
" to store the returned feature option value and make sure the function always
" return the same value when called with the same arguments. This implies that
" changing 'g:diapp_<feat>_<id>' during a Vim sesssion has no effect. If such
" change is detected, the function issues a warning message.
"
" Argument #1: Feature name.
"
" Argument #2: Feature state dictionary.
"
" Argument #3: Identifier.
"
" Argument #4: Default value.
"
" Return value: Can be anything.

function diapp#GetFeatOpt(feat, current_state, id, default)

    let l:identifier = "g:diapp_" . a:feat . "_" . a:id
    let l:desired_value = exists(l:identifier) ? {l:identifier} : a:default

    if !has_key(a:current_state, 'option')
        let a:current_state.option = {}
    endif

    if !has_key(a:current_state.option, a:id)
        let a:current_state.option[a:id]
                    \ = {'value': l:desired_value,
                    \ 'warning_issued': 0}
    elseif a:current_state.option[a:id].value !=# l:desired_value
                \ && !a:current_state.option[a:id].warning_issued
        call diapp#Warn("You have set or changed variable '"
                    \ . l:identifier
                    \ . "' but it's too late to take the change into account. "
                    \ . "Set the variable on Vim startup using a vimrc file.")
        let a:current_state.option[a:id].warning_issued = 1
    endif

    return a:current_state.option[a:id].value

endfunction

" -----------------------------------------------------------------------------

" Issue a warning indicating that the command is unavailable.
"
" Argument #1 (optional):
" Complementary message (will be parenthesized).

function diapp#WarnUnavlCom(...)

    call diapp#Warn("Command currently unavailable"
                \ . (a:0 > 0 ? " (" . a:1 . ")" : ""))

endfunction

" -----------------------------------------------------------------------------

" Issue a warning message with " Nothing done." appended.
"
" Argument #1:
" Warning message.

function diapp#WarnNothingDone(msg)

    call diapp#Warn(a:msg . " Nothing done.")

endfunction

" -----------------------------------------------------------------------------

" A feature state dictionary key.
"
" Return value:
" Feature state dictionary key (string).

function diapp#FeatStateKeyMenu()

    return 'menu'

endfunction

" -----------------------------------------------------------------------------

" A feature state dictionary key.
"
" Return value:
" Feature state dictionary key (string).

function diapp#FeatStateKeyCom()

    return 'com'

endfunction

" -----------------------------------------------------------------------------

" A feature state dictionary key.
"
" Return value:
" Feature state dictionary key (string).

function diapp#FeatStateKeyMap()

    return 'map'

endfunction

" -----------------------------------------------------------------------------

" A state dictionary key.
"
" Return value:
" State dictionary key (string).

function diapp#StateKeyLastExtCmd()

    return 'last_ext_cmd'

endfunction

" -----------------------------------------------------------------------------

" Reserved feature names.
"
" Return value:
" Reserved feature name.

function s:ReservedFeatureNames()

    return ['plugin']

endfunction

" -----------------------------------------------------------------------------

" Return an updated feature state dictionary. The update operation includes
" (and even starts with) the update of the 'disabled' item based on the global
" flag 'g:diapp_<feature name>_disabled'. If the global flag does not exist,
" then the feature is enabled.
"
" Argument #1:
" Feature name.
"
" Argument #2:
" Empty dictionary or current value of the feature state dictionary.
"
" Return value:
" Updated feature state dictionary.

function s:UpdateFeatureState(feat, current_state)

    " Truthy if the current feature state dictionary is empty (which means that
    " the update is actually an initialization), falsy otherwise.
    let l:initializing = empty(a:current_state)

    " Compute the desired 'disabled' item value based on a user defined global
    " flag (if existent).
    let l:user_desired_disabled_item
                \ = s:GetFlag('g:diapp_' . a:feat . '_disabled')

    if l:initializing

        " Initialize the return value with an embryonic feature state
        " dictionary.
        let l:s = {'disabled': l:user_desired_disabled_item,
                    \ 'no_disabling_warning_issued': 0}

    else

        " Initialize the return value with the current feature state
        " dictionary.
        let l:s = a:current_state

        if !l:s.disabled
                    \ && l:user_desired_disabled_item
                    \ && !l:s.no_disabling_warning_issued
            call diapp#Warn("You have set flag 'g:diapp_"
                        \ . a:feat
                        \ . "_disabled' to a falsy value but it's too late to "
                        \ . "disable feature '"
                        \ . a:feat
                        \ . "'. Set the flag on Vim startup using a vimrc "
                        \ . "file.")
            let l:s.no_disabling_warning_issued = 1
        elseif l:s.disabled
            let l:s.disabled = l:user_desired_disabled_item
        endif

    endif

    if !l:s.disabled && !has_key(l:s, 'update_state')
        let l:s.update_state
                    \ = function("feat#diapp_" . a:feat . "#UpdateState")
    endif

    if l:s.disabled || !feat#diapp_{a:feat}#CannotSkipUpdate()
        " The feature is disabled or it is enabled but the edited file is such
        " that the feature state dictionary update can be skipped.
        let s:skipped_update[a:feat] = 1
        return l:s " Early return.
    else
        let s:skipped_update[a:feat] = 0
    endif

    " We get there only if the feature is enabled and the feature state
    " dictionary update cannot be skipped.

    " Update the feature state dictionary.
    call l:s.update_state()

    " The 'disabled' item must not have been changed.
    if l:s.disabled
        throw "Internal error: function 'feat#diapp_"
                    \ . a:feat
                    \ . "#UpdateState' has changed the 'disabled' item of "
                    \ . "the feature state dictionary"
    endif

    return l:s

endfunction

" -----------------------------------------------------------------------------

" Return the directories contained in a runtime directories option as a list of
" directories.
"
" Argument #1:
" Runtime directories option value (e.g. '&runtimepath' or '&packpath').
"
" Return value:
" List of directories.

function s:RunTimeOptDirList(opt_value)

    return split(a:opt_value, ',')

endfunction

" -----------------------------------------------------------------------------

" Return the list of Diapp's feature names, based on files found in the
" directory provided as argument.
"
" Argument #1:
" Directory to explore.
"
" Return value:
" List of feature names (possibly empty).

function s:FeatureListFromDir(dir)

    let l:ret = []

    let l:feature_file = lib#diapp_vim800func#GlobPath(
                \ a:dir, "**/autoload/feat/diapp_*.vim", 1, 1)

    for f in l:feature_file
        let l:ret = l:ret + [substitute(
                    \ f,
                    \ '^.*[\\\/]autoload[\\\/]feat[\\\/]'
                    \ . 'diapp_\([^\.]\+\)\.vim$',
                    \ '\1',
                    \ 0)]
    endfor

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Explore runtime directories until finding Diapp's feature scripts.
"
" Return value:
" List of feature names.

function s:FeatureList()

    let l:ret = []

    " List of directories in option 'runtimepath'.
    let l:rtp_list = s:RunTimeOptDirList(&runtimepath)

    " Loop over 'packpath' directories.
    for d in l:rtp_list

        let l:ret = s:FeatureListFromDir(d)
        if !empty(l:ret)
            return l:ret " Early return.
        endif

    endfor

    " We get there if 'Diapp's feature scripts have not been found in the
    " directories of '&runtimepath'.

    " List of directories in option 'packpath' (if the option exists).
    let l:pp_list = exists("&packpath")
                \ ? s:RunTimeOptDirList(&packpath)
                \ : []

    " Loop over 'packpath' directories.
    for d in l:pp_list

        if index(l:rtp_list, d) == -1
            " Current 'packpath' directory was not in 'runtimepath'.

            let l:ret = s:FeatureListFromDir(d)
            if !empty(l:ret)
                return l:ret " Early return.
            endif
        endif

    endfor

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" If argument (current state dictionary) is provided, return it updated.
" Otherwise return an initial state dictionary.
"
" Also, manage script-local dictionary 's:skipped_update' (one item for each
" feature). A truthy value for an item is a signal for 's:DiappRefreshUI' that
" it should not update the user interface for the feature. A part of the
" management of s:skipped_update is done by 's:UpdateFeatureState'. And a reset
" is done by 's:DiappRefreshUI' (just before exiting).
"
" Argument #1 (optional):
" Current state dictionary.
"
" Return value:
" Updated state dictionary.

function s:UpdatedState(...)

    if a:0 == 0
        " No state dictionary provided as argument.

        " Find Diapp's feature names.
        let l:feat = s:FeatureList()

        " Warn if reserved feature names have been used.
        for f in l:feat
            if index(s:ReservedFeatureNames(), f) != -1
                call diapp#Warn(
                            \ '"' . f . '" is not allowed as a feature name.')
            endif
        endfor

        if empty(l:feat)
            call diapp#Warn("Diapp is not working "
                        \ . "(feature script files not found)")
        else
            let l:com = "command! -nargs=0 EchoDiappFeatureNames"
            let k = 0
            for f in l:feat
                let k += 1
                let l:com .= " :echo '" . f . "'"
                            \ . (k == len(l:feat) ? "" : " |")
            endfor
            execute l:com
        endif

        " Initialize state dictionary with embryonic feature state
        " dictionaries. Also initialize 's:skipped_update'.
        let l:s = {'feat': {}}
        let s:skipped_update = {}
        for f in l:feat
            let l:s.feat[f] = {}
            let s:skipped_update[f] = 0
        endfor

    else
        " Current state dictionary provided as argument.

        " Initialize the return value with this current state.
        let l:s = a:1
    endif

    " For each feature (i.e. for each item of the 'feat' item of the dictionary
    " state), update the feature state.
    for k in keys(l:s.feat)
        let l:s.feat[k] = s:UpdateFeatureState(k, l:s.feat[k])
    endfor

    return l:s

endfunction

" -----------------------------------------------------------------------------

" Create a feature menu.
"
" Argument #1:
" Feature name (key of the 'feat' item of global state dictionary 's:state').
"
" Argument #2 (optional):
" Not documented here. Used only in internal recursive calls.
"
" Argument #3 (optional):
" Not documented here. Used only in internal recursive calls.

function s:CreateUIFeatureMenu(feat, ...)

    " 0 or 2 extra arguments must be provided.
    if a:0 != 0 && a:0 != 2
        throw "Internal error: 0 or 2 extra arguments expected"
    endif

    if a:0 == 0
        " No optional argument is provided.

        " The call is a call by the main "refresh UI" function
        " ('s:DiappRefreshUI') and we have to create the whole menu of a
        " feature.

        " There is no parent menu item.
        let l:ancestor_list = []

        " The needed menu data are in the 'menu' item of the feature state
        " dictionary.
        let l:menu_data = s:state.feat[a:feat][diapp#FeatStateKeyMenu()]

    else
        " The two optional arguments are provided.

        " The first one is the list of ancestors of the menu item to be
        " created.
        let l:ancestor_list = a:1

        " The second one is the data dictionary for the menu item to be
        " created.
        let l:menu_data = a:2

    endif

    if has_key(l:menu_data, 'sub')
        " The menu item to be created is itself a menu.

        " Loop over the items of the menu.
        for s in l:menu_data.sub

            " Do a recursive call with the appropriate optional arguments.
            call s:CreateUIFeatureMenu(a:feat,
                        \ l:ancestor_list + [l:menu_data.label], s)
        endfor

    else
        " The menu item to be created is a "leaf" item.

        " Build the menu item label.
        let l:label = join(l:ancestor_list + [l:menu_data.label], '.')
        if has_key(l:menu_data, 'mapping') && !empty(l:menu_data.mapping)
            let l:label = l:label . '<TAB>' . l:menu_data.mapping
        endif

        " Loop over the menu item modes and create the menu item for each mode.
        let l:remaining_modes = l:menu_data.mode
        while strlen(l:remaining_modes) != 0

            let l:mode = strpart(l:remaining_modes, 0, 1)
            let l:remaining_modes = strpart(l:remaining_modes, 1)

            " For insert mode, "<ESC>" is added to exit insert mode before
            " launching the menu command.
            let l:esc = (l:mode ==? "i") ? "<ESC>" : ""

            " Create the menu item.
            execute l:mode . "noremenu <silent> "
                        \ . l:label . " " . l:esc . l:menu_data.command

            " Enable or disable the menu item.
            let l:status = l:menu_data.enabled ? "enable" : "disable"
            execute l:mode . "menu " . l:status . " " . l:label

        endwhile

    endif

endfunction

" -----------------------------------------------------------------------------

" Update the global state dictionary 's:state' and refresh the user interface
" (menus, commands).
"
" Argument #1 (optional):
" Truthy to force the function execution (i.e. to bypass the check of the
" elapsed time since last call for the same buffer), falsy otherwise. Defaults
" to falsy.
"
" Return value:
"
" - 1: The function has returned immediately due to the check of the
"      elapsed time since last call for the same buffer.
"
" - 0: The function has run normally.

function s:DiappRefreshUI(...)

    if has('reltime') && !exists('s:diapp_refresh_count')
        " Initialize the run count.
        let s:diapp_refresh_count = 0
    endif

    " 'l:force' is set to a truthy value if an argument is provided and truthy.
    let l:force = get(a:, 1, 0)

    " A falsy value for 'l:force' causes the function to return immediately if
    " all of the following conditions are true:
    "
    " - Vim has been compiled with the 'reltime' feature.
    "
    " - 'b:diapp_refresh_count' exists and is equal to the number of runs of
    "   the present function (which means that it has not been run for another
    "   buffer since the last run for the current buffer).
    "
    " - 'b:diapp_refresh_date' exists (and it exists if Vim has been compiled
    "   with the 'reltime' feature and if the present function has been called
    "   at least once in the current buffer, and in this case
    "   'b:diapp_refresh_date' contains the date of the previous call of the
    "   function in the current buffer).
    "
    " - The difference in seconds between current date and
    "   'b:diapp_refresh_date' is lower than global variable
    "   'g:diapp_min_refresh_period' (or is lower than
    "   's:default_min_refresh_period' if 'g:diapp_min_refresh_period').
    if !l:force
                \ && has('reltime')
                \ && exists('b:diapp_refresh_count')
                \ && b:diapp_refresh_count == s:diapp_refresh_count
                \ && exists('b:diapp_refresh_date')
                \ && lib#diapp_vim800func#RelTimeFloat(
                \ reltime(b:diapp_refresh_date))
                \ < s:Get('g:diapp_min_refresh_period',
                \ s:default_min_refresh_period)
        return 1 " Early return.
    endif

    " From now on, there must be NO early return and NO abnormal function exit
    " (to make sure the 'b:diapp_refresh_date', 's:diapp_refresh_count' and
    " 'b:diapp_refresh_count' update is done at the end).

    " Update the state structure.
    let s:state = s:UpdatedState(s:state)

    " Delete the user-defined commands.
    let l:com = diapp#FeatStateKeyCom()
    if exists('s:user_comm_defined')
        for k in keys(s:state.feat)
            if s:user_comm_defined[k] && !s:skipped_update[k]
                for comm in s:state.feat[k][l:com]
                    let l:com_name = comm
                    while l:com_name =~ '^ *-'
                        let l:com_name = substitute(l:com_name,
                                    \ '^ *-[^ ]\+ *', '', '')
                    endwhile
                    let l:com_name = substitute(l:com_name, ' .\+$', '', '')
                    execute "delcommand " . l:com_name
                endfor
            endif
        endfor
    endif

    " Undo the user-defined mappings.
    let l:map = diapp#FeatStateKeyMap()
    if exists('s:user_map_defined')
        for k in keys(s:state.feat)
            if s:user_map_defined[k] && !s:skipped_update[k]
                for comm in s:state.feat[k]['current_map']

                    let l:key = substitute(comm,
                                \ '^[^ ]\+ \+\([^ ]\+\) .*$', '\1', '')

                    let l:comm2 = comm[0:1]

                    if l:comm2 ==# "ma" || l:comm2 ==# "no"
                        let l:ucomm = "unmap"
                    elseif l:comm2 ==# "nm" || l:comm2 ==# "nn"
                        let l:ucomm = "nunmap"
                    elseif l:comm2 ==# "vm" || l:comm2 ==# "vn"
                        let l:ucomm = "vunmap"
                    elseif l:comm2 ==# "xm" || l:comm2 ==# "xn"
                        let l:ucomm = "xunmap"
                    elseif l:comm2 ==# "sm" || l:comm2 ==# "sn"
                        let l:ucomm = "sunmap"
                    elseif l:comm2 ==# "om" || l:comm2 ==# "on"
                        let l:ucomm = "ounmap"
                    elseif l:comm2 ==# "im" || l:comm2 ==# "in"
                        let l:ucomm = "iunmap"
                    elseif l:comm2 ==# "lm" || l:comm2 ==# "ln"
                        let l:ucomm = "lunmap"
                    elseif l:comm2 ==# "cm" || l:comm2 ==# "cn"
                        let l:ucomm = "cunmap"
                    elseif l:comm2 ==# "tm" || l:comm2 ==# "tn"
                        let l:ucomm = "tunmap"
                    endif

                    execute l:ucomm . " " . l:key

                endfor
            endif
        endfor
    endif

    let l:menu = diapp#FeatStateKeyMenu()

    " Refresh the graphical menu for all the enabled features that actually
    " have a menu.
    for k in keys(s:state.feat)
        if !s:state.feat[k].disabled
                    \ && !s:skipped_update[k]
                    \ && has_key(s:state.feat[k], l:menu)
            try
                execute "aunmenu " . s:state.feat[k][l:menu].label
            catch
                " We get there if the feature menu does not yet exist.
            endtry
            call s:CreateUIFeatureMenu(k)
        endif
    endfor

    " Refresh the user commands.
    let s:user_comm_defined = deepcopy(s:state.feat)
    for k in keys(s:state.feat)
        let s:user_comm_defined[k] = 0
        if !s:state.feat[k].disabled
                    \ && !s:skipped_update[k]
                    \ && has_key(s:state.feat[k], l:com)
            let s:user_comm_defined[k] = 1
            for comm in s:state.feat[k][l:com]
                execute "command! " . comm
            endfor
        endif
    endfor

    " Refresh the mappings.
    let s:user_map_defined = deepcopy(s:state.feat)
    for k in keys(s:state.feat)
        let s:user_map_defined[k] = 0
        if !s:state.feat[k].disabled
                    \ && !s:skipped_update[k]
                    \ && has_key(s:state.feat[k], l:map)
            let s:user_map_defined[k] = 1
            for comm in s:state.feat[k][l:map]
                execute comm
            endfor
            let s:state.feat[k]['current_map'] = s:state.feat[k][l:map]
        endif
    endfor

    " Reset 's:skipped_update'.
    for k in keys(s:state.feat)
        let s:skipped_update[k] = 0
    endfor

    " Update the run counts and refresh date if Vim has been compiled with the
    " 'reltime' feature.
    if has('reltime')

        " NOTE: The Vim number type seems to be a signed 64 bits integer type
        " (on Debian GNU/Linux 10 AMD64 at least) and the '+' operation does
        " not seem to fail on overflow but "wraps around". This behavior is OK
        " for the usage we do of 's:diapp_refresh_count' (equality test against
        " a previous value). <2020-06-28>
        let s:diapp_refresh_count = s:diapp_refresh_count + 1
        let b:diapp_refresh_count = s:diapp_refresh_count
        let b:diapp_refresh_date = reltime()
    endif

    return 0

endfunction

" -----------------------------------------------------------------------------

" Run a "feature function" (with the feature state dictionary plus extra
" arguments (if any) as arguments) and update the feature state dictionary.
"
" Argument #1:
" Name of the feature function (like
" "feat#diapp_<feature name>#<function name>").
"
" Other arguments (optional):
" Any other arguments that need to be passed to the "feature function".

function diapp#RunFeatureFunc(name, ...)

    let l:feat = substitute(a:name, '^feat#diapp_\([^#]\+\)#.\+$', '\1', '')
    if s:state.feat[l:feat].disabled
        call diapp#WarnUnavlCom("feature '" . l:feat . "' is disabled")
    else
        execute "call call('"
                    \ . a:name
                    \ . "', [s:state.feat['"
                    \ . l:feat
                    \ . "']] + a:000)"
    endif

endfunction

" -----------------------------------------------------------------------------

" Call 'diapp#RunFeatureFunc' with argument #1 and extra arguments and then
" call 's:DiappRefreshUI(1)'.
"
" Argument #1:
" Name of the feature function (like
" "feat#diapp_<feature name>#<function name>").
"
" Other arguments (optional):
" Any other arguments that need to be passed to the "feature function".

function diapp#RunFeatureFuncAndRefreshUI(name, ...)

    call call('diapp#RunFeatureFunc', [a:name] + a:000)
    call s:DiappRefreshUI(1)

endfunction

" -----------------------------------------------------------------------------
"
" Call 'diapp#RunFeatureFunc' using the list stored in a state dictionnary item
" as argument.
"
" Argument #1:
" State dictionary item key.

function diapp#RunStoredFeatureFunc(state_key)

    call call('diapp#RunFeatureFunc', s:state[a:state_key])

endfunction

" -----------------------------------------------------------------------------
"
" Store the list made of argument #2 and extra arguments as a state dictionnary
" item (the name of this item is provided in argument #1).
"
" Argument #1:
" State dictionary item key.
"
" Argument #2:
" Name of a feature function (like
" "feat#diapp_<feature name>#<function name>").
"
" Other arguments (optional):
" Any other arguments that need to be passed to the feature function.

function diapp#StoreFeatureFuncCall(state_key, name, ...)

    let s:state[a:state_key] = [a:name] + a:000

endfunction

" -----------------------------------------------------------------------------

" Initialize the state structure.
let s:state = s:UpdatedState()

" Set up autocommands.
augroup diapp

    autocmd!

    autocmd FileType,BufRead,BufEnter * :call s:DiappRefreshUI()

augroup END

" Define permanent commands and mappings.

command -nargs=0 EchoLastGPRbuildCommand
            \ :call diapp#RunFeatureFunc(
            \ 'feat#diapp_gprbuild#EchoLastCommand')

command -nargs=0 RerunLastDiappExtCommand
            \ :call diapp#RunStoredFeatureFunc(diapp#StateKeyLastExtCmd())
let s:key = diapp#GetFeatOpt(
            \ 'plugin', s:state, 'rerun_last_diapp_ext_cmd_mapping', '<F12>')
execute "nnoremap " . s:key . " :RerunLastDiappExtCommand<CR>"
execute "inoremap " . s:key . " <ESC>:RerunLastDiappExtCommand<CR>"

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
