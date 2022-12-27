" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" File base name.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" File base name.

function lib#diapp_file#BaseName(file_name)

    return fnamemodify(a:file_name, ':t')

endfunction

" -----------------------------------------------------------------------------

" File base name without the extension.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" File base name without the extension.

function lib#diapp_file#BaseNameNoExt(file_name)

    return fnamemodify(a:file_name, ':t:r')

endfunction

" -----------------------------------------------------------------------------

" File extension.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" File extension.

function lib#diapp_file#Ext(file_name)

    return fnamemodify(a:file_name, ':e')

endfunction

" -----------------------------------------------------------------------------

" Parent directory.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" Containing directory.

function lib#diapp_file#Dir(file_name)

    return fnamemodify(a:file_name, ':h')

endfunction

" -----------------------------------------------------------------------------

" Full path name
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" Full path name.

function lib#diapp_file#Full(file_name)

    return fnamemodify(a:file_name, ':p')

endfunction

" -----------------------------------------------------------------------------

" Relative path name (relative to the current working directory) if possible.
"
" Argument #1:
" Absolute or relative file name.
"
" Return value:
" Relative path name (relative to the current working directory) or argument
" unchanged if it's not below the current working directory.

function lib#diapp_file#Relative(file_name)

    return fnamemodify(a:file_name, ':.')

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if and only if the file provided as argument is found
" in the current directory.
"
" Argument #1:
" File base name.
"
" Return value:
" Truthy value if and only if the file provided as argument is found in the
" current directory.

function lib#diapp_file#FileExists(file_name)

    return findfile(a:file_name, getcwd()) ==# a:file_name

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
