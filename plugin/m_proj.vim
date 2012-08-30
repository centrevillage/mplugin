scriptencoding utf8
" Vim Utility ==================================================================
" vertion  : 1.0
" created  : 2011/08/12 
" updated  : 2012/07/28
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

if exists('g:loaded_m_proj') || &cp
    finish
endif
let g:loaded_m_proj = 1

let g:m_project_maven_opts = ''
let g:m_project_mvn_error_format = '\[ERROR\] \(.\+\):\[\(\d\+\),\(\d\+\)\] \(.*\)'
let g:m_project_mvn_error_continue_line = '\[ERROR\] \(.\+\)'
let g:m_project_mvn_error_end_format = '\[ERROR\]\s*$'
let g:m_project_exlore_command = ''

let g:m_project_profiles = {}
let g:m_project_current = ''
let t:m_project_current = ''
let g:m_project_project_on_tabpage = 1
let g:m_project_jump_on_select = 1

function! MProjGetCurrentProjName()
  if g:m_project_project_on_tabpage
    if !exists('t:m_project_current')
      let t:m_project_current = g:m_project_current
    endif
    return t:m_project_current
  else
    return g:m_project_current
  endif
endfunction

function! MProjSet(...)
  try 
    if a:0 == 0
      throw "No project name"
    endif
    let project_name = a:1
    if a:0 > 1
      if !has_key(g:m_project_profiles, project_name)
        let g:m_project_profiles[project_name] = {}
      endif
      for eq in a:000[1:]
        let [name, val] = split(eq, '=')
        if name == 'ext' || name == 'dir' || name == 'docdir' || name == 'srcdir' || name == 'ignore'
          let g:m_project_profiles[project_name][name] = val
        elseif name =~ '^cmd:\(\w\+\)'
"          let cmdname = substitute(name, '^cmd:\(\w\+\)', '\1', 'g')
          "let cmdstate = substitute(val, "^[\"']\\(.*\\)[\"']", '\1', 'g')
          let cmdname = name
          let cmdstate = val
          let g:m_project_profiles[project_name][cmdname] = cmdstate
        else
          throw '[' . name . '] propery is not exsists.'
        endif
      endfor
    else
      if !has_key(g:m_project_profiles, project_name)
        throw '"' . project_name . '" project is not exists.'
      end
    endif
  catch /.*/
    echoerr 'MProjSet:[error] ' . v:exception
  endtry
endfunction
command! -nargs=+ MProjSet :call MProjSet(<f-args>)

function! MProjDel(project_name)
  if has_key(g:m_project_profiles, a:project_name)
    call remove(g:m_project_profiles, a:project_name)
  endif
endfunction
command! -nargs=1 MProjDel :call MProjDel(<f-args>)

function! MProjSelect(project_name)
  if !has_key(g:m_project_profiles, a:project_name)
    echoerr 'MSelectProj:[error] "' . a:project_name . '" project is not exists.'
  else
    let t:m_project_current = a:project_name
    let g:m_project_current = a:project_name
    if g:m_project_jump_on_select
      call MProjJumpRootDir()
    endif
  endif
endfunction
command! -nargs=1 MProjSelect :call MProjSelect(<f-args>)

function! MProjGetRootDir(...)
  let project_name = MProjGetCurrentProjName()
  if a:0 > 0
    let project_name = a:1
  endif
  if empty(project_name)
    echoerr 'MSelectProj:[error] No project name.'
    return ""
  end
  if !has_key(g:m_project_profiles, project_name)
    echoerr 'MSelectProj:[error] "' . project_name . '" project is not exitsts.'
    return ""
  else
    let current_project_config = g:m_project_profiles[project_name]
    if !has_key(current_project_config, 'dir')
      echoerr 'MProjJumpRootDir:[error] "' . project_name . '" project has not "dir" property.'
      return ""
    endif
    let dirs = split(current_project_config['dir'], ',')
    let dir = dirs[0]
    let dir = substitute(dir, "^[\"']\\(.*\\)[\"']", '\1', 'g')
    return dir
  endif
endfunction
function! MProjJumpRootDir(...)
  let project_name = MProjGetCurrentProjName()
  if a:0 > 0
    let project_name = a:1
  endif
  let dir = MProjGetRootDir(project_name)
  execute 'cd '. dir
  if len(g:m_project_exlore_command) > 0
    execute g:m_project_exlore_command . ' ' . dir
  endif
endfunction
command! -nargs=* MProjJumpRootDir :call MProjJumpRootDir(<f-args>)

function! MProjList()
  let list = ['project list --']
  let projects = []
  let index = 1
  let current_project_name = MProjGetCurrentProjName()
  for project_name in keys(g:m_project_profiles)
    let project_config = g:m_project_profiles[project_name]
    let mark = ''
    if current_project_name == project_name
      let mark = '*'
    endif
    let line = '[' . index . mark  . '] ' . project_name . ' ('
    let i = 0
    for [k, v] in items(project_config)
      if k !~ '^cmd:'
      if i > 0
        let line .= ' '
        let first = 0
      endif
      let line .= k . "=" . v
      let i += 1
      endif
    endfor
    let line .= ')'
    call add(projects, project_name)
    call add(list, line)
    let index += 1
  endfor
  let retval = inputlist(list)
  if retval > 0
    call MProjSelect(projects[retval-1])
  endif
endfunction
command! MProjList :call MProjList()

function! MProjStatusLine()
  let project_name = MProjGetCurrentProjName()
  if len(project_name) > 0
    return '[project=' . project_name . ']'
  endif
  return ''
endfunction

function! s:MProjArgs(list)
  let project_name = MProjGetCurrentProjName()
  let args = a:list
  if len(a:list) > 1
    if has_key(g:m_project_profiles, a:list[0])
      let project_name = a:list[0]
      let args = a:list[1:]
    else
      throw '[error] "' . a:list[0] . '" project is not exists.'
    end
  else
    if empty(project_name)
      throw '[error] Current project is not set. Please execute "MProjSelect {projcect-name}" command.'
      return
    endif
  endif
  return {'project_name': project_name, 'args': args}
endfunction

function! FindFile(...)
  try 
    let proj_and_args = s:MProjArgs(a:000)
    if len(proj_and_args) == 0
        echoerr 'Failed to execute "FindFile" command.'
      return
    end
    let project_name = proj_and_args['project_name']
    let arg = proj_and_args['args']
    let findword = arg[0]
    let ext = ''
    let current_project_config = g:m_project_profiles[project_name]
    if has_key(current_project_config, 'ext')
      let ext = '-e ' . current_project_config['ext']
    endif
    let ignore = ''
    if has_key(current_project_config, 'ignore')
      let ignore = '-i ' . current_project_config['ignore']
    endif
    let dir = '.'
    if has_key(current_project_config, 'dir')
      let dirs = split(current_project_config['dir'], ',')
      let dir = join(dirs, ' ')
    end
    let directjump_old = g:mgrep_opt_directjump
    let g:mgrep_opt_directjump = 1
    let command = 'Grep -f ' . ext . ' ' . ignore . ' ' . findword . ' ' . dir
"    call confirm(command)
    execute command
    let g:mgrep_opt_directjump = directjump_old
  catch /.*/
    echo 'FindFile:' . v:exception
  endtry
endfunction
command! -nargs=+ FF :call FindFile(<f-args>)

function! MProjGrep(...)
  let proj_and_args = s:MProjArgs(a:000)
    if len(proj_and_args) == 0
        echoerr 'Failed to execute "MProjGrep" command.'
        return 
    end
  let project_name = proj_and_args['project_name']
  let findword = proj_and_args['args'][0]
  let ext = ''
  let current_project_config = g:m_project_profiles[project_name]
  if has_key(current_project_config, 'ext')
    let ext = '-e ' . current_project_config['ext']
  endif
  let ignore = ''
  if has_key(current_project_config, 'ignore')
    let ignore = '-i ' . current_project_config['ignore']
  endif
  let dir = '.'
  if has_key(current_project_config, 'dir')
    let dirs = split(current_project_config['dir'], ',')
    let dir = join(dirs, ' ')
  end
  let directjump_old = g:mgrep_opt_directjump
  let g:mgrep_opt_directjump = 1
  execute 'Grep ' . ext . ' ' . ignore . ' ' . findword . ' ' . dir
  let g:mgrep_opt_directjump = directjump_old
endfunction
command! -nargs=+ GG :call MProjGrep(<f-args>)

function! MProjJavaJumpPackage()
  let project_name = MProjGetCurrentProjName()
  if !empty(project_name) && has_key(g:m_project_profiles, project_name)
    let current_project_config = g:m_project_profiles[project_name]
    if has_key(current_project_config, 'srcdir')
      call JavaJumpPackage(current_project_config['srcdir'])
    else
      echoerr 'MProjJavaJumpPackage:[error] "srcdir" property is not set.'
    endif
  endif
endfunction

function! MProjDocGrep(...) 
  let project_name = MProjGetCurrentProjName()
  if empty(project_name)
    echoerr '[error] Current project is not set. Please execute "MProjSelect {projcect-name}" command.'
    return
  endif
  let dir = '.'
  let current_project_config = g:m_project_profiles[project_name]
  if has_key(current_project_config, 'docdir')
    let dir = current_project_config['docdir']
  endif
  if a:0 > 1
    let category = a:1
    let word = a:2
  else
    let category = ''
    let word = a:1
  endif
  let ext = '-e @html'
  let dir = dir . '/' . category
  let directjump_old = g:mgrep_opt_directjump
  let g:mgrep_opt_directjump = 1
  let cmd = 'Grep -f ' . ext . ' "\b' . word . '\b" ' . dir
  echo cmd
  execute cmd
  let g:mgrep_opt_directjump = directjump_old
endfunction
command! -nargs=+ MProjDocGrep :call MProjDocGrep(<f-args>)

function! MProjDocGrepListCategory()
  let project_name = MProjGetCurrentProjName()
  if empty(project_name)
    echoerr '[error] Current project is not set. Please execute "MProjSelect {projcect-name}" command.'
    return
  endif
  let dir = '.'
  let current_project_config = g:m_project_profiles[project_name]
  if has_key(current_project_config, 'docdir')
    let dir = current_project_config['docdir']
  endif
  let s = glob(dir. '/*')
  let dirs = split(s, "\n")
  let lines = []
  for line in dirs
    call add(lines, substitute(line, '^.*[\\/]', '', 'g'))
  endfor
  echo join(lines, "\n")
endfunction
command! MProjDocGrepListCategory :call MProjDocGrepListCategory()

function! Sbt(...)
  let proj_and_args = s:MProjArgs(a:000)
  let project_name = proj_and_args['project_name']
  let commands = proj_and_args['args']
  let current_project_config = g:m_project_profiles[project_name]
  let dir = '.'
  if has_key(current_project_config, 'dir')
    let dir = current_project_config['dir']
  end
  let s:_current_path = getcwd()
  try
    execute 'cd ' . dir
    let _old_makeprg = &makeprg
    let _old_efm = &efm
    let &makeprg='sbt ' . join(commands)
    set efm=%E\ %#[error]\ %f:%l:\ %m,%C\ %#[error]\ %p^,%-C%.%#,%Z,
           \%W\ %#[warn]\ %f:%l:\ %m,%C\ %#[warn]\ %p^,%-C%.%#,%Z,
           \%-G%.%#
    make
    let &makeprg = _old_makeprg
    let &efm = _old_efm
  finally
    execute 'cd ' . s:_current_path
  endtry 
  if len(getqflist()) > 0
    :QfList
  endif
endfunction
command! -nargs=+ Sbt :call Sbt(<f-args>)

function! MProjMaven(...)
  let project_name = MProjGetCurrentProjName()
  let mvncommand = ''
  if has_key(g:m_project_profiles, a:1)
    let project_name = a:1
    let mvncommand = join(a:000[1:], ' ')
  else
    let mvncommand = join(a:000, ' ')
  endif
  if !has_key(g:m_project_profiles, project_name)
    echoerr 'Maven:[error] "' . project_name . '" project is not exists.'
    return
  endif
  let current_project_config = g:m_project_profiles[project_name]
  if !has_key(current_project_config, 'dir')
    echoerr 'Maven:[error] "' . project_name . '] project has not "dir" property.'
    return
  endif
  let dirs = split(current_project_config['dir'], ',')
  let dir = dirs[0]
  let _dir = getcwd()
  execute 'cd ' . dir
  let result = iconv(system('mvn ' . mvncommand . ' ' . g:m_project_maven_opts), &termencoding, &encoding)
  let result_lines = split(result, "\n")

  " make qflist
  call setqflist([])

  let match = 0
  let text = ''
  for item in result_lines
    if match > 0
        if item =~ g:m_project_mvn_error_end_format
            call setqflist([{'filename': filename , 'lnum': lnum, 'col': col, 'text': text}], 'a')
            let match = 0
        else
            let matched = matchlist(item, g:m_project_mvn_error_continue_line)
            if len(matched) != 0
                let text .= matched[1]
            endif
        endif
    endif
    let matched = matchlist(item, g:m_project_mvn_error_format)
    if len(matched) != 0 
      let match = 1
      let filename = matched[1]
      let lnum = matched[2]
      let col = matched[3]
      let text = matched[4]
    endif
  endfor

  execute 'cd ' . _dir

  if has("win32")
  execute "silent! sp [MvnResult]"
  else
  execute "silent! sp \[MvnResult\]"
  endif
  setlocal modifiable
  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal buftype=nofile
  setlocal noswapfile
"  setlocal nowrap
  setlocal bufhidden=hide
  setlocal isf-=:
  setlocal isf-=[
  setlocal isf-=]
  set noinsertmode
  normal! ggVGd
  call setline(1, result_lines)
  setlocal nomodifiable
"  echo result
endfunction
command! -nargs=+ Mvn :call MProjMaven(<f-args>)

function! MProjCmd(...)
  let project_name = MProjGetCurrentProjName()
  let cmd = ''
  if has_key(g:m_project_profiles, a:1)
    let project_name = a:1
    if a:0 > 1
      let cmd = 'cmd:' . a:000[1]
    endif
  else
    let cmd = 'cmd:' . a:000[0]
  endif
  if len(cmd) == 0
    echoerr 'Cmd:[error] invalid arguments.'
    return
  endif
  if !has_key(g:m_project_profiles, project_name)
    echoerr 'Cmd:[error] "' . project_name . '" project is not exists.'
    return
  endif
  let current_project_config = g:m_project_profiles[project_name]
  if !has_key(current_project_config, cmd)
    echoerr 'Cmd:[error] "' . cmd . '" command is not exists.'
    return
  endif
  if !has_key(current_project_config, 'dir')
    echoerr 'Cmd:[error] "' . project_name . '] project has not "dir" property.'
    return
  endif
  let command = current_project_config[cmd]
  let dirs = split(current_project_config['dir'], ',')
  let dir = dirs[0]
  let _dir = getcwd()
  execute 'cd ' . dir
  let result = iconv(system(command), &termencoding, &encoding)
  let result_lines = split(result, "\n")
  execute 'cd ' . _dir

  if has("win32")
    execute "silent! sp [CmdResult]"
  else
    execute "silent! sp \[CmdResult\]"
  endif
  setlocal modifiable
  setlocal nonumber
  setlocal foldcolumn=0
  setlocal nofoldenable
  setlocal buftype=nofile
  setlocal noswapfile
"  setlocal nowrap
  setlocal bufhidden=hide
  setlocal isf-=:
  setlocal isf-=[
  setlocal isf-=]
  set noinsertmode
  normal! ggVGd
  call setline(1, result_lines)
  setlocal nomodifiable
"  echo result
endfunction
command! -nargs=+ CC :call MProjCmd(<f-args>)

nnoremap FF :call FindFile(GetWordStr())<cr>
nnoremap <Leader>GG :call MProjGrep(GetWordStr())<cr>
"vim:ts=2:sw=2:
