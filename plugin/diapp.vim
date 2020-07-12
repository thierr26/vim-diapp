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
        echohl WarningMsg
        echomsg "You have set or changed variable '"
                    \ . l:identifier
                    \ . "' but it's too late to take the change into account. "
                    \ . "Set the variable on Vim startup using a vimrc file."
        echohl None
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

    echohl WarningMsg
    echo "Command currently unavailable"
                \ . (a:0 > 0 ? " (" . a:1 . ")" : "")
    echohl None

endfunction

" -----------------------------------------------------------------------------

" Issue a warning message with " Nothing done." appended.
"
" Argument #1:
" Warning message.

function diapp#WarnNothingDone(msg)

    echohl WarningMsg
    echo a:msg . " Nothing done."
    echohl None

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

" Key for the "menu" item of a feature state.
"
" Return value:
" Key for the "menu" item of a feature state.

function diapp#FeatStateKeyMenu()

    return 'menu'

endfunction

" -----------------------------------------------------------------------------

" Key for the "com" item of a feature state.
"
" Return value:
" Key for the "com" item of a feature state.

function diapp#FeatStateKeyCom()

    return 'com'

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
            echohl WarningMsg
            echomsg "You have set flag 'g:diapp_"
                        \ . a:feat
                        \ . "_disabled' to a falsy value but it's too late to "
                        \ . "disable feature '"
                        \ . a:feat
                        \ . "'. Set the flag on Vim startup using a vimrc "
                        \ . "file."
            echohl None
            let l:s.no_disabling_warning_issued = 1
        elseif l:s.disabled
            let l:s.disabled = l:user_desired_disabled_item
        endif

    endif

    if !l:s.disabled && !has_key(l:s, 'update_state')
        let l:s.update_state = function("feat#diapp_gprbuild#UpdatedState")
    endif

    if l:s.disabled || !feat#diapp_gprbuild#CannotSkipUpdate()
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
                    \ . "#UpdatedState' has changed the 'disabled' item of "
                    \ . "the feature state dictionary"
    endif

    return l:s

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

        " Initialize the return value with an embryonic initial state.
        let l:s = {'feat': {'gprbuild': {}}}

        " Initialize s:skipped_update.
        let s:skipped_update = {'gprbuild': 0}
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

        " Create the menu item.
        let l:mode = l:menu_data.mode
        let l:label = join(l:ancestor_list + [l:menu_data.label], '.')
        if has_key(l:menu_data, 'mapping') && !empty(l:menu_data.mapping)
            let l:label = l:label . '<TAB>' . l:menu_data.mapping
        endif
        let l:cmd = l:menu_data.command
        execute l:mode . "noremenu <silent> " . l:label . " " . l:cmd

        " Enable or disable the item.
        let l:status = l:menu_data.enabled ? "enable" : "disable"
        execute l:mode . "menu " . l:status . " " . l:label

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

    if has('gui_running')
        " We're running in a Vim with a graphical user interface.

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
    endif

    " Refresh the user commands.
    let l:com = diapp#FeatStateKeyCom()
    for k in keys(s:state.feat)
        if !s:state.feat[k].disabled
                    \ && !s:skipped_update[k]
                    \ && has_key(s:state.feat[k], l:com)
            for comm in s:state.feat[k][l:com]
                execute "command! " . comm
            endfor
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
" Feature name (key of the 'feat' item of global state dictionary 's:state').
"
" Argument #2:
" "Funcref" for the function to be run.
"
" Other arguments (optional):
" Any other arguments that need to be passed to the "feature function".

function diapp#RunFeatureFunc(feat, FuRef, ...)

    call call(a:FuRef, [s:state.feat[a:feat]] + a:000)

endfunction

" -----------------------------------------------------------------------------

" Run a "feature function" (with the feature state dictionary plus extra
" arguments (if any) as arguments), update the feature state dictionary and
" refreshe the user interface.
"
" Argument #1:
" Feature name (key of the 'feat' item of global state dictionary 's:state').
"
" Argument #2:
" "Funcref" for the function to be run.
"
" Other arguments (optional):
" Any other arguments that need to be passed to the "feature function".

function diapp#RunFeatureFuncAndRefreshUI(feat, FuRef, ...)

    call call('diapp#RunFeatureFunc',[a:feat, a:FuRef] + a:000)
    call s:DiappRefreshUI(1)

endfunction

" -----------------------------------------------------------------------------

" Initialize the state structure.
let s:state = s:UpdatedState()

" Set up autocommands.
augroup diapp

    autocmd!

    " autocmd BufRead,BufNewFile *.txt :set filetype=text

    autocmd BufEnter * :call s:DiappRefreshUI()
    autocmd FileType * :call s:DiappRefreshUI()

augroup END

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
