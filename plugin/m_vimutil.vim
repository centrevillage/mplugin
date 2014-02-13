scriptencoding utf8
" Vim Utility ==================================================================
" vertion  : 1.0
" date     : 2005/12/29 
" update   : 2012/07/28
" license    : MIT License 
" license {{{
"   The MIT License (MIT)
"   Copyright (c) 2012 centrevillage(centrevillage@gmail.com)
"   
"   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
"   
"   The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
"   
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" license }}}
" =============================================================================

if exists('g:loaded_m_vimutil') || &cp
    finish
endif
let g:loaded_m_vimutil = 1

function! GetUnderCursorStr(pat, ...) 
    let offsetS = 0
    let offsetE = 0
    if a:0 > 0
        let offsetS = a:1
    endif
    if a:0 > 1
        let offsetE = a:2
    endif

    let cline = getline('.')
    let cpos = col('.') - 1
    let posE = 0
    while posE != -1
        let posS = match(cline, a:pat, posE)
        let posE = matchend(cline, a:pat, posE)
        if posE > cpos
            return strpart(cline, posS+offsetS, posE - posS - (offsetS + offsetE))
        endif
    endwhile
endfunction

function! GetWordStr()
    return GetUnderCursorStr('\w\+')
endfunction

function! JavaJumpPackage(path)
    let s = GetUnderCursorStr('\(\w\|\.\)\+')
    let s = a:path . '/' . substitute(s, '\.', '/', 'g') . '.java' 
    execute 'e '. s
endfunction


