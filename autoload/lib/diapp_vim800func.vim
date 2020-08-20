" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

if version >= 800
    " Vim version is at least 8.0.

    let s:strcharpart_ref = function("strcharpart")
    let s:reltimefloat_ref = function("reltimefloat")
    let s:systemlist_ref = function("systemlist")
    let s:globpath_ref = function("globpath")

else
    " Vim version is below 8.0.

    let s:strcharpart_ref = function("strpart")

    function s:reltimefloat(...)
        return str2float(call("reltimestr", a:000))
    endfunction
    let s:reltimefloat_ref = function("s:reltimefloat")

    function s:systemlist(...)
        return split(call("system", a:000), '\n')
    endfunction
    let s:systemlist_ref = function("s:systemlist")

    function s:globpath(...)
        if a:0 > 3 && a:4
            return split(call("globpath", a:000[0:2]), '\n')
        else
            return call("globpath", a:000[0:2])
        endif
    endfunction
    let s:globpath_ref = function("s:globpath")

endif

" -----------------------------------------------------------------------------

" To be used like function 'strcharpart' in Vim 8.
function lib#diapp_vim800func#StrCharPart(...)
    return call(s:strcharpart_ref, a:000)
endfunction

" -----------------------------------------------------------------------------

" To be used like function 'reltimefloat' in Vim 8.
function lib#diapp_vim800func#RelTimeFloat(...)
    return call(s:reltimefloat_ref, a:000)
endfunction

" -----------------------------------------------------------------------------

" To be used like function 'systemlist' in Vim 8.
function lib#diapp_vim800func#SystemList(...)
    return call(s:systemlist_ref, a:000)
endfunction

" -----------------------------------------------------------------------------

" To be used like function 'globpath' in Vim 8. If Vim version is below 8.0
" then the 5th argument (alllinks) is ignored.
function lib#diapp_vim800func#GlobPath(...)
    return call(s:globpath_ref, a:000)
endfunction

" -----------------------------------------------------------------------------

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
