" Save 'compatible-option' value.
let s:cpo_save = &cpo

" Reset 'compatible-option' to its Vim default value.
set cpo&vim

if version >= 800
    " Vim version is at least 8.0.

    let s:strcharpart_ref = function("strcharpart")
    let s:reltimefloat_ref = function("reltimefloat")

else
    " Vim version is below 8.0.

    let s:strcharpart_ref = function("strpart")

    function s:reltimefloat(...)
        return str2float(call("reltimestr", a:000))
    endfunction
    let s:reltimefloat_ref = function("s:reltimefloat")

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

" Restore 'compatible-option' value.
let &cpo = s:cpo_save
unlet s:cpo_save
