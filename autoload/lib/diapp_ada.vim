" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

" -----------------------------------------------------------------------------

" List of Ada 202x reserved words (i.e. Ada 2012 reserved words plus
" "parallel") plus "aggregate", "extends", "external", "library" and "project"
" if an argument is provided and is equal to "gnat_project" (case insensitive).
"
" Argument #1 (optional):
" Kind of Ada file ("spec", "body" or "gnat_project") (case insensitive,
" defaults to "body").
"
" Return value:
" List of lower case words.

function s:reserved_word(...)

    let l:kind = get(a:, 1, "body")

    let l:ret = ['abort',
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

    if l:kind ==? "gnat_project"
        let l:ret = l:ret + ['aggregate',
                    \ 'extends',
                    \ 'external',
                    \ 'library',
                    \ 'project']
    endif

    return l:ret

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

function s:is_delimiter(char)

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
" Kind of Ada file ("spec", "body" or "gnat_project") (case insensitive,
" defaults to "body").
"
" Return value:
" Lexer state (similar to the one returned by
" 'lib#diapp_lexing#move_to_next_char' but with more items), that is a
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
function s:move_to_lexeme_tail(text, state, ...)

    let l:kind = get(a:, 1, "body")

    let l:reserved_word = s:reserved_word(l:kind)

    let l:s = lib#diapp_lexing#move_to_next_char(a:text, a:state)

    let l:blank_regexp = "[\t ]"

    let l:is_comment = 1

    while l:is_comment

        if has_key(l:s, 'd') && l:s['d']
            " End of text already reached, nothing more can be done.

            return l:s " Early return.
        endif

        while (!has_key(l:s, 'd') || !l:s['d'])
                    \ && match(l:s['e'], l:blank_regexp) != -1
            let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
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
            let l:test_s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
            if !l:test_s['d']
                        \ && l:test_s['l'] == l:s['l']
                        \ && l:test_s['e'] == "-"
                let l:is_comment = 1
                let l:s = lib#diapp_lexing#move_to_next_line(a:text, l:s)
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
                let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
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

                let l:test_s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
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
                \ && strcharpart(a:text[l:l - 1], l:s['c'] + 1, 1) == "'"
        " The lexeme is a character literal.
        let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
        let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
        let l:token_name = "character_literal"
    elseif s:is_delimiter(l:s['e'])
        " The lexeme is a delimiter.
        let l:old_s = deepcopy(l:s)
        let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
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
            let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
        endwhile
        let l:s = deepcopy(l:old_s)
        let l:token_name = "numerical_literal"
    else
        " The lexeme is an identifier or a reserved word.
        while !l:s['d']
                    \ && l:s['l'] == l:l
                    \ && !s:is_delimiter(l:s['e'])
                    \ && match(l:s['e'], l:blank_regexp) == -1
            let l:old_s = deepcopy(l:s)
            let l:s = lib#diapp_lexing#move_to_next_char(a:text, l:s)
        endwhile
        let l:s = deepcopy(l:old_s)
        let l:token_name = "identifier"
    endif

    " Add a 'lexeme' item to the returned dictionary.
    let l:s['lexeme'] = strcharpart(
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

" Extension of Ada files (".ads" for specifications, ".adb" for bodies and
" ".gpr" for GNAT project files).
"
" Argument #1:
" Kind of Ada file (one of "spec", "body" or "gnat_project") (case
" insensitive).
"
" Return value:
" Conventional extension for the kind of file, dot included.

function lib#diapp_ada#Ext(kind)

    if a:kind ==? 'spec'
        return ".ads"
    elseif a:kind ==? 'body'
        return ".adb"
    else " Could have been: elseif a:kind ==? 'gnat_project'
        return ".gpr"
    endif

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

function lib#diapp_ada#file_info(file_name)

    let l:ext = "." . lib#diapp_file#Ext(a:file_name)

    if l:ext ==? lib#diapp_ada#Ext('spec')
        let l:ret = {'kind': 'spec'}
    elseif l:ext ==? lib#diapp_ada#Ext('body')
        let l:ret = {'kind': 'body'}
    elseif l:ext ==? lib#diapp_ada#Ext('gnat_project')
        let l:ret = {'kind': 'gnat_project',
                    \ 'abstract': 0,
                    \ 'aggregate': 0,
                    \ 'library': 0}
    else
        let l:ret = {'kind': ''}
        return l:ret " Early return.
    endif

    if l:ret['kind'] ==? 'gnat_project'
                \ && lib#diapp_file#FileExists(a:file_name)
        " The file is an existing GNAT project file.

        " Load the file as a list of strings (lines).
        let l:gpr_text = readfile(a:file_name)

        " Extract lexemes until finding the project keyword and update the
        " returned dictionary items according to the found reserved words.
        let l:lexeme = []
        let l:lexer_state = {}
        while !has_key(l:lexer_state, 'd') || !l:lexer_state['d']

            let l:lexer_state = s:move_to_lexeme_tail(
                        \ l:gpr_text, l:lexer_state, l:ret['kind'])

            if l:lexer_state['lexeme'] ==? "project"
                " The lexeme is the 'project' reserved word.

                " Loop over the lexeme seen just before the 'project' reserved
                " word and update the returned dictionary items accordingly.
                for k in l:lexeme
                    if k ==? "abstract"
                        let l:ret['abstract'] = 1
                    elseif k ==? "aggregate"
                        let l:ret['aggregate'] = 1
                    elseif k ==? "library"
                        let l:ret['library'] = 1
                    endif
                endfor
                break " Early loop exit.
            elseif l:lexer_state['lexeme'] == ";"
                " The lexeme is a semicolon, probably terminating a with
                " clause.

                " Reset the lexeme list as we are not interested in the with
                " clause lexeme.
                let l:lexeme = []
            else
                " The lexeme is neither a semicolon nor the 'project' reserved
                " word.

                " Append the lexeme to the lexeme list.
                let l:lexeme = l:lexeme + [l:lexer_state['lexeme']]
            endif
         endwhile

    endif

    return l:ret

endfunction

" -----------------------------------------------------------------------------

" Return a truthy value if the provided dictionary (supposed to have been
" returned by 'lib#diapp_ada#file_info') seems to be the one of a concrete
" (i.e. not abstract) GNAT project file and a falsy value otherwise.
"
" Argument #1:
" Dictionary as output by 'lib#diapp_ada#file_info'.
"
" Return value:
" Truthy for a concrete (i.e. not abstract) GNAT project file, falsy otherwise.

function lib#diapp_ada#IsConcreteGNATProject(file_info_dic)

    return a:file_info_dic['kind'] ==? 'gnat_project'
                \ && !a:file_info_dic['abstract']

endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
