" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" Take a list of strings (referred to as lines) (argument 'text') and a lexer
" state (argument 'state') as argument and change the lexer state so that it
" points to the next character and return the updated state. On the first call,
" the 'state' argument must be an empty dictionary. For the subsequent calls,
" use the returned value as 'state' argument (keeping the same value for the
" 'text' argument).
"
" Note that a similar function exists to change lexer state to the beginning of
" the next non empty line: 'lib#diapp_lexing#MoveToNextLine'. You can call
" any of the functions with the returned value of any of them.
"
" Argument #1:
" List of (possibly empty) strings (as returned, for example, by Vim function
" 'readfile').
"
" Argument #2:
" Empty dictionary or return value of a previous call (or of a call to
" 'lib#diapp_lexing#MoveToNextLine') with same first argument.
"
" Return value:
" Lexer state, that is a dictionary with the following items:
"
" - 'l': line number (1 based).
" - 'c': column number (1 based).
" - 'e': element (character) at line 'l' and column 'c'.
" - 'm': line and column move (e.g {'l': 0, 'c': 1} if the lexer state has
"        changed to the next character on the same line, {'l': 2, 'c': 0} if
"        the lexer state has changed to the first character on the second next
"        line).
" - 'd': "done" flag (truthy if the 'state' argument was "pointing" to the last
"        character of the last non empty line of argument 'text' or if argument
"        'text' has no non empty lines).
function lib#diapp_lexing#MoveToNextChar(text, state)

    " Copy the provided state to 'l:s'. 'l:s' will be updated by the function
    " and returned.
    let l:s = deepcopy(a:state)

    " Number of lines in the text.
    let l:ln = len(a:text)

    " Initialize state if needed.
    if empty(l:s)
        let l:s.l = 0
        let l:s.c = 0
        let l:s.d = l:ln == 0
        let l:s.e = ""
        let l:s.m = {'l': 0, 'c':0}
    endif

    if l:s.d
        " End of text already reached, nothing more can be done.

        return l:s " Early return.
    endif

    if l:s.l == 0 || l:s.c == strchars(a:text[l:s.l - 1])
        " We have to move to next line if possible.

        " Copy the current line number.
        let l:new_l = l:s.l

        " Increment line number copy as long as the next line is empty, or stop
        " if there's no next line.
        while l:new_l < l:ln && strchars(a:text[l:new_l]) == 0
            let l:new_l = l:new_l + 1
        endwhile

        if l:new_l < l:ln
            " 'l:new_l + 1' is the number of the first non empty line after
            " 'l:s.l'.

            let l:s.m = {'l': l:new_l + 1 - l:s.l, 'c': 0}
            let l:s.l = l:s.l + l:s.m.l
            let l:s.c = 1
        else
            " There is no non empty lines after 'l:s.l'.

            " Set the "done" flag in the state.
            let l:s.d = 1

            let l:s.e = ""
            let l:s.m = {'l': 0, 'c':0}
            return l:s " Early return.
        endif

    else
        " We just have to move to the next character on the same line.

        let l:s.m = {'l': 0, 'c': 1}
        let l:s.c = l:s.c + l:s.m.c
    endif

    " Update the current character key of the state.
    let l:s.e = lib#diapp_vim800func#StrCharPart(
                \ a:text[l:s.l - 1], l:s.c - 1, 1)

    return l:s

endfunction

" -----------------------------------------------------------------------------

" Update lexer state with a move to the beginning of the next non empty line.
" Otherwise similar to 'lib#diapp_lexing#MoveToNextChar'.
"
" Argument #1:
" List of (possibly empty) strings (as returned, for example, by Vim function
" 'readfile').
"
" Argument #2:
" Empty dictionary or return value of a previous call (or of a call to
" 'lib#diapp_lexing#MoveToNextChar') with same first argument.
"
" Return value:
" Lexer state. See documentation for 'lib#diapp_lexing#MoveToNextChar' for
" details.
function lib#diapp_lexing#MoveToNextLine(text, state)

    let l:s = lib#diapp_lexing#MoveToNextChar(a:text, a:state)

    if l:s.m.l == 0 && l:s.m.c == 1
        " The "move to next char" operation has moved to next character.

        " Change the state so that it "points" to the last character of the
        " line.
        let l:s.c = strchars(a:text[l:s.l - 1])

        " Do another "move to next char" operation. It will move to the next
        " non empty line if any. Return immediately.
        return lib#diapp_lexing#MoveToNextChar(a:text, l:s)
    endif

    " We get there if and only if the first "move to next char" operation has
    " already moved to next non empty line or if it could not move due to end
    " of text being reached. Nothing more to do.

    return l:s

    " NOTE: This implementation is probably a bit slow as in many cases it will
    " call 'lib#diapp_lexing#MoveToNextChar' twice. But it is short and
    " avoids duplicating the state initialization code. <2020-06-13>

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
