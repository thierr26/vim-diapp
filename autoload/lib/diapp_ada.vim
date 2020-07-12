" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" List of Ada 202x reserved words (i.e. Ada 2012 reserved words plus
" "parallel").
"
" Return value:
" List of lower case words.

function lib#diapp_ada#ReservedWord()

    return ['abort',
                \ 'abs',
                \ 'abstract',
                \ 'accept',
                \ 'access',
                \ 'aliased',
                \ 'all',
                \ 'and',
                \ 'array',
                \ 'at',
                \ 'begin',
                \ 'body',
                \ 'case',
                \ 'constant',
                \ 'declare',
                \ 'delay',
                \ 'delta',
                \ 'digits',
                \ 'do',
                \ 'else',
                \ 'elsif',
                \ 'end',
                \ 'entry',
                \ 'exception',
                \ 'exit',
                \ 'for',
                \ 'function',
                \ 'generic',
                \ 'goto',
                \ 'if',
                \ 'in',
                \ 'interface',
                \ 'is',
                \ 'limited',
                \ 'loop',
                \ 'mod',
                \ 'new',
                \ 'not',
                \ 'null',
                \ 'of',
                \ 'or',
                \ 'others',
                \ 'out',
                \ 'overriding',
                \ 'package',
                \ 'parallel',
                \ 'pragma',
                \ 'private',
                \ 'procedure',
                \ 'protected',
                \ 'raise',
                \ 'range',
                \ 'record',
                \ 'rem',
                \ 'renames',
                \ 'requeue',
                \ 'return',
                \ 'reverse',
                \ 'select',
                \ 'separate',
                \ 'some',
                \ 'subtype',
                \ 'synchronized',
                \ 'tagged',
                \ 'task',
                \ 'terminate',
                \ 'then',
                \ 'type',
                \ 'until',
                \ 'use',
                \ 'when',
                \ 'while',
                \ 'with',
                \ 'xor']

endfunction

" -----------------------------------------------------------------------------

" Check whether the string of length 1 provided as argument is an Ada delimiter
" or an opening or closing square bracket ("[" or "]").
"
" Argument #1:
" String of length 1. (No checking is done.)
"
" Return value:
" Truthy value if the argument is a (non-compound) Ada delimiter or an opening
" or closing square bracket ("[" or "]"), falsy value otherwise.

function s:IsDelimiter(char)

    " NOTE: '=~' or '!~' should probably have been used instead of 'match()' in
    " the whole file. No functional impact. <2020-06-27>

    return match(a:char, "[&'()\*+,-\./:;<=>|]") != -1
                \ || a:char == "["
                \ || a:char == "]"

endfunction

" -----------------------------------------------------------------------------

" Take a list of strings (referred to as lines) (argument 'text') (supposed to
" be the text of an Ada specication or body or of a GNAT project file) and a
" lexer state (argument 'state') as argument and change the lexer state so that
" it points to the last character of the next lexeme (i.e. lexical element) and
" return the updated state. On the first call, the 'state' argument must be an
" empty dictionary. For the subsequent calls, use the returned value as 'state'
" argument (keeping the same value for the 'text' argument).
"
" Note that comments are ignored (skipped).
"
" The third (optional) argument makes it possible to qualify the kind of text
" provided as first argument. If it is equal to "gnat_project" (case
" insensitive), then a different list of reserved words is used.
"
" Argument #1:
" List of (possibly empty) strings (as returned, for example, by Vim function
" 'readfile').
"
" Argument #2:
" Empty dictionary or return value of a previous call with same first argument.
"
" Argument #3 (optional):
" Reserved words list. Defaults to the return value of
" 'lib#diapp_ada#ReservedWord'. It is useful to be able to specify a specific
" list of reserved words as some files (e.g. GNAT project files) may use a
" language "like" Ada but with more reserved words. In this case, using the
" standard list of ada reserved words would lead some reserved words to be
" described as identifiers in the returned dictionary (item 'token_name').
"
" Return value:
" Lexer state (similar to the one returned by
" 'lib#diapp_lexing#MoveToNextChar' but with more items), that is a
" dictionary with the following items:
"
" - 'l'         : line number (1 based).
" - 'c'         : column number (1 based).
" - 'e'         : element (character) at line 'l' and column 'c'.
" - 'm'         : line and column move (e.g {'l': 0, 'c': 1} if the lexer state
"                 has changed to the next character on the same line, {'l': 2,
"                 'c': 0} if the lexer state has changed to the first character
"                 on the second next line).
" - 'd'         : "done" flag (truthy if the 'state' argument was "pointing" to
"                 the last character of the last non empty line of argument
"                 'text' or if argument 'text' has no non empty lines).
" - 'lexeme'    : lexeme string.
" - 'lexeme_l'  : line number (1 based) of the first character of the lexeme.
" - 'lexeme_c'  : column number (1 based) of the first character of the lexeme.
" - 'token_name': "kind" of lexeme (one of "string_literal",
"                 "character_literal", "numeric_literal", "delimiter",
"                 "identifier" and "reserved_word")
function lib#diapp_ada#MoveToLexemeTail(text, state, ...)

    let l:reserved_word = get(a:, 1, lib#diapp_ada#ReservedWord())

    let l:s = lib#diapp_lexing#MoveToNextChar(a:text, a:state)

    let l:blank_regexp = "[\t ]"

    let l:is_comment = 1

    while l:is_comment

        if has_key(l:s, 'd') && l:s['d']
            " End of text already reached, nothing more can be done.

            return l:s " Early return.
        endif

        while (!has_key(l:s, 'd') || !l:s['d'])
                    \ && match(l:s['e'], l:blank_regexp) != -1
            let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        endwhile

        if l:s['d']
            " End of text reached, nothing more can be done.

            return l:s " Early return.
        endif

        " Here we know that 'l:s' "points" to the first character of a lexeme
        " (possibly a comment).

        " If the lexeme is a comment, skip it.
        let l:is_comment = 0
        if l:s['e'] == '-'
            let l:test_s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
            if !l:test_s['d']
                        \ && l:test_s['l'] == l:s['l']
                        \ && l:test_s['e'] == "-"
                let l:is_comment = 1
                let l:s = lib#diapp_lexing#MoveToNextLine(a:text, l:s)
            endif
        endif
    endwhile

    let l:l = l:s['l']
    let l:c = l:s['c']

    " In some cases (unterminated string literal for example), the lexeme field
    " of the returned dictionary will be "fixed" by appending a non empty
    " 'l:fix_tail'.
    let l:fix_tail = ""

    if l:s['e'] == "\""
        " The lexeme is a string literal .

        " Moving forward to the end of the string literal or to the end of the
        " line. If we find the end of the line before the end of the string
        " literal, then the text is an illegal Ada or GNAT project text.
        let l:cur_char = ""
        let l:done = 0
        while !l:done

            while (!has_key(l:s, 'd') || !l:s['d'])
                        \ && l:s['l'] == l:l
                        \ && l:cur_char != "\""

                let l:old_s = deepcopy(l:s)
                let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
                let l:cur_char = l:s['e']

            endwhile

            if l:s['l'] != l:l || (has_key(l:s, 'd') && l:s['d'])
                " End of line found before end of string literal.

                " Make sure 'l:s' "points" to the end of the line containing
                " the string literal.
                let l:s = deepcopy(l:old_s)
                let l:done = 1
                let l:fix_tail = "\""

            else
                " Double quote character found. It may be the end of the
                " string literal (if it is not immediately followed by another
                " double quote character) or not (in the opposite case).

                let l:test_s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
                if l:test_s['d']
                            \ || l:test_s['l'] != l:l
                            \ || l:test_s['e'] != "\""
                    " The found double quote was the end of the string literal.
                    let l:done = 1
                endif
            endif
        endwhile
        let l:token_name = "string_literal"
    elseif l:s['e'] == "'"
                \ && match(a:state['e'], "[A-Za-z0-9]") == -1
                \ && l:s['c'] <= strchars(a:text[l:l - 1]) - 2
                \ && lib#diapp_vim800func#StrCharPart(
                \ a:text[l:l - 1], l:s['c'] + 1, 1) == "'"
        " The lexeme is a character literal.
        let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        let l:token_name = "character_literal"
    elseif s:IsDelimiter(l:s['e'])
        " The lexeme is a delimiter.
        let l:old_s = deepcopy(l:s)
        let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        if !l:s['d'] && l:s['l'] == l:l
            let l:compound_candidate = l:old_s['e'].l:s['e']
            if l:compound_candidate != "=>"
                        \ && l:compound_candidate != "=>"
                        \ && l:compound_candidate != ".."
                        \ && l:compound_candidate != "**"
                        \ && l:compound_candidate != ":="
                        \ && l:compound_candidate != "/="
                        \ && l:compound_candidate != ">="
                        \ && l:compound_candidate != "<="
                        \ && l:compound_candidate != "<<"
                        \ && l:compound_candidate != ">>"
                        \ && l:compound_candidate != "<>"
                " The lexeme is not a compound delimiter
                let l:s = deepcopy(l:old_s)
            endif
        else
            " The lexeme is not a compound delimiter
            let l:s = deepcopy(l:old_s)
        endif
        let l:token_name = "delimiter"
    elseif match(l:s['e'], "[0-9]") != -1
        " The lexeme is a numerical literal.
        let l:old_s = deepcopy(l:s)
        while !l:s['d']
                    \ && l:s['l'] == l:l
                    \ && (match(l:s['e'], "[0-9_\.#a-fA-F]") != -1
                    \ || (match(l:s['e'], "[+-]") != -1
                    \ && match(l:old_s['e'], "[eE]") != -1))
            let l:old_s = deepcopy(l:s)
            let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        endwhile
        let l:s = deepcopy(l:old_s)
        let l:token_name = "numerical_literal"
    else
        " The lexeme is an identifier or a reserved word.
        while !l:s['d']
                    \ && l:s['l'] == l:l
                    \ && !s:IsDelimiter(l:s['e'])
                    \ && match(l:s['e'], l:blank_regexp) == -1
            let l:old_s = deepcopy(l:s)
            let l:s = lib#diapp_lexing#MoveToNextChar(a:text, l:s)
        endwhile
        let l:s = deepcopy(l:old_s)
        let l:token_name = "identifier"
    endif

    " Add a 'lexeme' item to the returned dictionary.
    let l:s['lexeme'] = lib#diapp_vim800func#StrCharPart(
                \ a:text[l:l - 1], l:c - 1, l:s['c'] + 1 - l:c) . l:fix_tail

    " Add the lexeme location (keys 'lexeme_l' (line) and 'lexeme_c' (column))
    " to the returned dictionary.
    let l:s['lexeme_l'] = l:l
    let l:s['lexeme_c'] = l:c

    if l:token_name ==? 'identifier'

        " Change 'l:token_name' from 'identifier' to 'reserved_word' if
        " appropriate.
        for w in l:reserved_word
            if l:s['lexeme'] ==? w
                let l:token_name = "reserved_word"
                break " Early loop exit.
            endif
        endfor
    endif

    " Add the 'token_name' item to the returned dictionary.
    let l:s['token_name'] = l:token_name

    return l:s

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
