scriptencoding utf8
" MGrep =======================================================================
" version    : 1.0
" created at : 2005/09/15 
" updated at : 2012/07/28
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

if exists('g:loaded_mgrep') || &cp
    finish
endif
if v:version < 700
    echomsg "Vim version is too old. Use Vim 7.x"
    finish
endif
let g:loaded_mgrep = 1

if has("win32") || has("win64")
	let s:line_separator = "\\"
else
	let s:line_separator = "/"
endif

let g:mgrep_filename_pattern = "^\\([^?<>|\"*]\\+\\)$"
let g:mgrep_line_pattern = "^\\t\\(\\d\\+\\)> \\(.*\\)$"
let g:mgrep_line_pattern_linenum = "^\\t\\(\\d\\+\\)> "
let g:mgrep_ignore_pattern = "^\\(<.*>\\)\\|\\(search.*:.*\\)$"
let g:mgrep_opt_disp_0result = 0
" 0: use all mapping
" 1: not use update mapping
" 2: not use edit mapping (except EditResultBuf)
" 3: not use update/edit mapping
let g:mgrep_opt_use_maplevel = 1

let g:mgrep_opt_directjump = 0
let s:mgrep_showing_status = 0
let s:mgrep_file_timestamp = ""
let s:timestamp_size = 10
let s:mgrep_line_status = ""
let s:status_line_size = 4
let w:mgrep_current_path = ""
let s:mgrep_edit_close = 0
let s:mgrep_edit_line = 0
let s:mgrep_edit_buf_modified = 0
let s:prev_bufnr = 0
let g:mgrep_file_encoding = "utf8"
let s:mgrep_prg = 'ruby -S ' . expand('<sfile>:p:h') . '/orep.rb'
let g:mgrep_binayfile_pattern = '\.doc$\|\.xls$\|\.bmp$\|\.png$\|\.jpg\|\.jpeg$\|\.gif$\|\.wav$\|\.aiff$\|\.ogg\|\.mp3$\|\.mp4\|\.avi$\|\.flv$\|\.git\>\|\.svn\>\|\.ttf$\|\.dll$\|\.obj$\|\.jar$\|\.class$\|\.bson$\|\.blend\d*$'

let s:debug = 0

function! <SID>DebugOut(str)
	if s:debug
		echo a:str
	endif
endfunction

augroup mgrep
  autocmd!
  if s:debug
	  autocmd BufEnter \[GrepResult\]  call <SID>InitResult()
	  autocmd BufLeave \[GrepResult\]  call <SID>EndResult()
	  autocmd BufEnter \[GrepEdit\]  call <SID>InitEdit()
	  autocmd BufLeave \[GrepEdit\]  call <SID>EndEdit()
  else
	  autocmd BufEnter \[GrepResult\] silent call <SID>InitResult()
	  autocmd BufLeave \[GrepResult\] silent call <SID>EndResult()
	  autocmd BufEnter \[GrepEdit\] silent call <SID>InitEdit()
	  autocmd BufLeave \[GrepEdit\] silent call <SID>EndEdit()
  endif
augroup END 

function! <SID>SubFunc(s_range, e_range, ...)
	let pat = ""
	let sub = ""
	let flag = ""
	if a:0 > 0
    let splitter = strpart(a:1, 0, 1)
		let index = 0
		let next = 1
		let prev = 1
		while index < 2
			let prev = next
			while 1
				let next = match(a:1, splitter, next) + 1
				if strpart(a:1, next-2, 1) == "\\"
					continue
				endif
				break
			endwhile
			if index == 0
				let pat = strpart(a:1, prev, next-prev-1)
			elseif index == 1
				let sub = strpart(a:1, prev, next-prev-1)
				let flag = strpart(a:1, next, strlen(a:1) - next)
			endif
			let index = index + 1
		endwhile
		if line(a:e_range) == -1 && line(a:s_range) == -1
			echo "Invalid range: ".a:s_range.",".a:e_range
		endif
		let index = a:s_range
		call <SID>DebugOut("pat: ".pat)
		call <SID>DebugOut("sub: ".sub)
		while index <= a:e_range
			let targetLine = <SID>GetEditLine(index)
			let substLine = substitute(targetLine, pat, sub, flag)
			if substLine !=# targetLine
				call <SID>SetEditLine(index, substLine)
			endif
			let index = index + 1
		endwhile
		call <SID>UpdateStatus()	
	endif
endfunction

function! <SID>GetEditLine(num)
	return substitute(<SID>GetNoStatusLine(a:num), g:mgrep_line_pattern, "\\2", "")
endfunction

function! <SID>GetEditLineNum(num)
	return substitute(<SID>GetNoStatusLine(a:num), g:mgrep_line_pattern, "\\1", "")
endfunction

function! <SID>SetEditLine(num, line, ...)
	if a:0 > 0
		let flag = a:1
	else
		let flag = "C"
	endif
	setlocal modifiable
	let line = <SID>GetNoStatusLine(a:num)
	if match(line, g:mgrep_ignore_pattern) == -1 && match(line, g:mgrep_line_pattern) != -1 
		let line_pattern_size = strlen(line) - strlen(substitute(line, g:mgrep_line_pattern, "\\2", ""))
		if s:mgrep_showing_status
			call setline(a:num, strpart(getline(a:num), 0, s:status_line_size + line_pattern_size).a:line)
		else
			call setline(a:num, strpart(getline(a:num), 0, line_pattern_size).a:line)
		endif
		call <SID>SetLineStatus(a:num, 1, flag)
	endif
	setlocal nomodifiable
endfunction

function! <SID>SetLineStatus(line_num, status_num, chr)
	let pos = (a:line_num - 1) * s:status_line_size
	let s:mgrep_line_status = strpart(s:mgrep_line_status, 0, pos + a:status_num).a:chr.strpart(s:mgrep_line_status, pos + a:status_num + 1)
endfunction

function! <SID>GetLineStatus(line_num, status_num)
	let pos = (a:line_num - 1) * s:status_line_size
	return s:mgrep_line_status[pos+a:status_num]
endfunction

function! <SID>WriteFile() 
	let linenum = 1
	let final_linenum = line("$")
	let file = ""
	let dllParamStr = ""
	let isOnUnWriteZone = 0
	let p_lines = []
	let p_nums = []
try
	while linenum <= final_linenum
		call <SID>DebugOut("WriteFile> linenum:".linenum)
		let line = <SID>GetNoStatusLine(linenum)	
		if match(line, g:mgrep_ignore_pattern) != -1
		elseif match(line, g:mgrep_line_pattern) != -1
			if strlen(file) == 0
				call <SID>DebugOut("No filename before line display")
				return
			endif

			let status = <SID>GetLineStatus(linenum, 1)
			if isOnUnWriteZone
				" goto next
			elseif status ==# "C"
				let tmp = substitute(<SID>GetNoStatusLine(linenum), g:mgrep_line_pattern, "\\2", "")
				let i = linenum + 1
				while <SID>GetLineStatus(i, 1) ==# "A"
					let tmp = tmp."\n".substitute(<SID>GetNoStatusLine(i), g:mgrep_line_pattern, "\\2", "")
					let i = i + 1
				endwhile
				call add(p_nums, substitute(<SID>GetNoStatusLine(linenum), g:mgrep_line_pattern, "\\1", ""))
				call add(p_lines, tmp)
				" goto next
				let linenum = i
				continue
			elseif status ==# "D"
				" minus line number is delete target
				call add(p_nums, -substitute(<SID>GetNoStatusLine(linenum), g:mgrep_line_pattern, "\\1", ""))
				call add(p_lines, "")
			endif
		elseif match(line, g:mgrep_filename_pattern) != -1
			if len(p_nums) != 0
				" write
				execute "sp ".file
				set bufhidden=delete
				let offset = 0
				let i = 0
				while i < len(p_nums)
					let num = get(p_nums, i)
					if num > 0
						let offset = offset + <SID>SetLines(num + offset, get(p_lines, i)) - 1
					else
						" num < 0
						execute (-num + offset)."d"
						let offset = offset - 1
					endif
					let i = i + 1
				endwhile
				write	
				close
				let p_lines = []
				let p_nums = []
			endif

			let file = <SID>GetAbsolutePath(substitute(line, g:mgrep_filename_pattern, "\\1", ""))
			if filewritable(file) == 0
				let isOnUnWriteZone = 1
				if <SID>GetLineStatus(linenum, 1) ==# "C"
					echo "Can not change Read-Only file! :".file
				endif
				let linenum = linenum + 1
				continue
			elseif <SID>GetTimeStamp(linenum) != getftime(file)
				let isOnUnWriteZone = 1
				if <SID>GetLineStatus(linenum, 1) ==# "C"
					echo "Already changed file! :".file
				endif
				call <SID>SetLineStatus(linenum, 2, "U")
				let linenum = linenum + 1
				continue
			else
				let isOnUnWriteZone = 0
			endif
		endif
		let linenum = linenum + 1
	endwhile
	if len(p_lines) != 0
		" write
		execute "sp ".<SID>GetAbsolutePath(file)
		set bufhidden=delete
		let offset = 0
		let i = 0
		while i < len(p_nums)
			let num = get(p_nums, i)
			if num > 0
				let offset = offset + <SID>SetLines(num + offset, get(p_lines, i)) - 1
			else
				" num < 0
				execute (-num + offset)."d"
				let offset = offset - 1
			endif
			let i = i + 1
		endwhile
		write	
		close
	endif
finally
	if s:mgrep_showing_status
		call <SID>ShowStatus(0)
		call <SID>ShowStatus(1)
	endif
	"setlocal nolazyredraw
endtry
endfunction

function! <SID>AdaptFileOpen(filename)
  if a:filename =~ g:mgrep_binayfile_pattern
    execute '!cmd /c ' . '"' . a:filename . '"'
  else
    execute 'edit ' . a:filename
  endif
endfunction

function! <SID>GrepFunc(arg1, ...)
    if !&autowriteall && &modified
        echo "Current buffer is not saved!"
        return
    endif

    " Parse command.
	if a:0 > 0
        let args_tmp = ''
        for argv in a:000
            if argv =~ '^!!'
                let args_tmp .= strpart(argv, 1) . ' '
            elseif argv =~ '^!'
                let args_tmp .= expand(strpart(argv, 1)) . ' '
            else
                let args_tmp .= argv . ' '
            endif
        endfor
        let w:mgrep_args = a:arg1 . ' ' . strpart(args_tmp, 0, len(args_tmp)-1)
	else
        let w:mgrep_args = a:arg1
	endif

	if has("multi_byte") 
    if &encoding != &termencoding
      let grep_cmd = iconv(s:mgrep_prg.' '.w:mgrep_args, &encoding, &termencoding)
    else
      let grep_cmd = s:mgrep_prg.' '.w:mgrep_args
    endif
    if &encoding != g:mgrep_file_encoding
      let std_out = iconv(system(grep_cmd), g:mgrep_file_encoding, &encoding)
    else
      if &encoding != &termencoding
        let std_out = iconv(system(grep_cmd), &termencoding, &encoding)
      else
        let std_out = system(grep_cmd)
      endif
    endif
	else
		let grep_cmd = s:mgrep_prg.' '.w:mgrep_args
    let std_out = system(grep_cmd)
	endif

  let results = split(std_out, "\<NL>")

  if !g:mgrep_opt_disp_0result
    let find = 0
    for line in results
      if match(line, g:mgrep_ignore_pattern) == -1
        let find = 1
        break
      endif
    endfor
    if (!find)
      echo "No results."
      echo "(Grep " . w:mgrep_args . ")"
      return
    endif
  endif

  if g:mgrep_opt_directjump
    let isjump = 0
    let idx = -1
    for line in results
      let idx += 1
      if match(line, g:mgrep_ignore_pattern) != -1
        continue
      elseif match(line, g:mgrep_line_pattern) != -1
        if isjump > 1
          let isjump = 0
          break
        endif
        let isjump = 2
      elseif match(line, g:mgrep_filename_pattern) != -1
        if isjump > 0
          let isjump = 0
          break
        endif
        let isjump = 1
      endif
    endfor
    if isjump == 1
      let filename = substitute(results[idx], g:mgrep_filename_pattern, "\\1", "")
      call <SID>AdaptFileOpen(filename)
      return
    elseif isjump == 2
      let filename = substitute(results[idx-1], g:mgrep_filename_pattern, "\\1", "")
      let line_num = substitute(results[idx], g:mgrep_line_pattern, "\\1", "")
      execute 'edit ' . filename
      execute "normal! ".line_num."G"
      return
    endif
  endif

  if bufname("%") != "[GrepResult]"
    let s:prev_bufnr = bufnr("%")
  endif
  if s:prev_bufnr == 0
    let s:prev_bufnr = bufnr("%")
  endif

  if &autowriteall
      execute "update"
  endif

	let w:mgrep_current_path = getcwd()
	call <SID>CreateBuf()
	let s:mgrep_commnad_num = 1 " 1: GrepFunc 2:VimGrepFunc
	let s:mgrep_showing_status = 0
	let s:mgrep_line_status = ''
	let w:mgrep_cursor_pos = 0
	call <SID>DisplayBuf(results)
	call <SID>CreateAllStatus()
	call <SID>CreateTimeStamp()
	call <SID>SetupSyntax()
	let @" = @0
endfunction

function! <SID>QfFunc()
    if !&autowriteall && &modified
        echo "Current buffer is not saved!"
        return
    endif
  if !g:mgrep_opt_disp_0result
    if empty(getqflist())
      echo "qflist is empty."
      return
    endif
  endif

  let results = ["<QfList>"]
  let item_for_file = {}
  for qfitem in  getqflist()
      if (has_key(qfitem, 'filename') || has_key(qfitem, 'bufnr')) && (has_key(qfitem, 'lnum') && qfitem['lnum'] > 0)
          if !has_key(qfitem, 'filename') && has_key(qfitem, 'bufnr')
              let fname = bufname(qfitem['bufnr'])
          else
              let fname = qfitem['filename']
          endif
          let line = qfitem['lnum']
          if !has_key(item_for_file, fname)
              let item_for_file[fname] = {}
          endif
          if !has_key(item_for_file[fname], line)
              let item_for_file[fname][line] = []
          endif
          call add(item_for_file[fname][line], {'text': qfitem['text'], 'col': qfitem['col']})
      else
          call add(results, '<' . qfitem['text'] . '>')
      endif
  endfor
  for [key, value] in items(item_for_file)
      call add(results, key) 
      let lines = readfile(key)
      let lnums = sort(keys(value))
      for lnum in lnums
          let items = value[lnum]
          for item in items
              call add(results, '<' . item['text'] . ' ['. item['col'] . '] >') 
          endfor
          call add(results, "\t" . lnum . '> ' . lines[lnum-1]) 
      endfor
  endfor

  if g:mgrep_opt_directjump
    let isjump = 0
    let idx = -1
    for line in results
      let idx += 1
      if match(line, g:mgrep_ignore_pattern) != -1
        continue
      elseif match(line, g:mgrep_line_pattern) != -1
        if isjump > 1
          let isjump = 0
          break
        endif
        let isjump = 2
      elseif match(line, g:mgrep_filename_pattern) != -1
        if isjump > 0
          let isjump = 0
          break
        endif
        let isjump = 1
      endif
    endfor
    if isjump == 1
      let filename = substitute(results[idx], g:mgrep_filename_pattern, "\\1", "")
      call <SID>AdaptFileOpen(filename)
      return
    elseif isjump == 2
      let filename = substitute(results[idx-1], g:mgrep_filename_pattern, "\\1", "")
      let line_num = substitute(results[idx], g:mgrep_line_pattern, "\\1", "")
      execute 'edit ' . filename
      execute "normal! ".line_num."G"
      return
    endif
  endif

  if bufname("%") != "[GrepResult]"
    let s:prev_bufnr = bufnr("%")
  endif
  if s:prev_bufnr == 0
    let s:prev_bufnr = bufnr("%")
  endif

  if &autowriteall
      execute "update"
  endif
	let w:mgrep_current_path = getcwd()
	call <SID>CreateBuf()
	let s:mgrep_commnad_num = 4 " 4: QfList
	let s:mgrep_showing_status = 0
	let s:mgrep_line_status = ''
	let w:mgrep_cursor_pos = 0
	call <SID>DisplayBuf(results)
	call <SID>CreateAllStatus()
	call <SID>CreateTimeStamp()
	call <SID>SetupSyntax()
	let @" = @0
endfunction

function! <SID>FormatVimFindResult(list, pat)
	let result_lines = []
    call add(result_lines, 'search pattern: ' . a:pat)
	for item in a:list
        call add(result_lines, substitute(item, '\\', '/', 'g'))
	endfor
	return result_lines
endfunction

function! <SID>FormatVimGrepResult(list, pat)
	let result_lines = []
	let cur_bufnr = ""
    call add(result_lines, 'search pattern: ' . a:pat)
	for item in a:list
		if item.bufnr != cur_bufnr
			let cur_bufnr = item.bufnr
            call add(result_lines, bufname(cur_bufnr))
		endif
        call add(result_lines, "\t".(item.lnum)."> ".(item.text))
	endfor
	return result_lines
endfunction

function! <SID>VimGrepFuncInner(type, arg1, args)
    if !&autowriteall && &modified
        echo "Current buffer is not saved!"
        return
    endif

    let results = []
    if a:type == 'file'
        let resultlist = split(glob(a:arg1), "\n")
        let w:file_pat = a:arg1
        if !g:mgrep_opt_disp_0result
            if (!len(resultlist))
                echo "No results."
                echo "(VimFind " . a:arg1 . ")"
                return
            endif
        endif
        let results = <SID>FormatVimFindResult(resultlist, a:arg1)
    else
        if len(a:args) > 0
            let w:file_pat = join(a:args, ' ')
        else
            let w:file_pat = "**"
        endif
        
        let regexp_sep = a:arg1[0]
        if match(a:arg1, "^".regexp_sep."[^".regexp_sep."]*".regexp_sep."[gj]*$") != -1
            let w:text_pat = a:arg1."j" 
        else
            let w:text_pat = "/".escape(a:arg1, '/')."/j"
        endif

        let w:mgrep_args = w:text_pat." ".w:file_pat
        try
            execute "vimgrep ".w:mgrep_args
        catch
            " Ignore no maching
        endtry
        let resultlist = getqflist()

        if !g:mgrep_opt_disp_0result
            if (!len(resultlist))
                echo "No results."
                echo "(VimGrep " . a:arg1 . ' ' . w:file_pat . ")"
                return
            endif
        endif
        let results = <SID>FormatVimGrepResult(resultlist, w:text_pat)
    endif

	if bufname("%") != "[GrepResult]"
		let s:prev_bufnr = bufnr("%")
	endif
	if s:prev_bufnr == 0
		let s:prev_bufnr = bufnr("%")
	endif

    if &autowriteall
        execute "update"
    endif

	let w:mgrep_current_path = getcwd()
	call <SID>CreateBuf()
    if a:type == 'file'
        let s:mgrep_commnad_num = 3 " 1: GrepFunc 2:VimGrepFunc 3:VimFindFunc
    else
        let s:mgrep_commnad_num = 2 " 1: GrepFunc 2:VimGrepFunc 3:VimFindFunc
    endif
	let s:mgrep_showing_status = 0
	let s:mgrep_line_status = ""
	let w:mgrep_cursor_pos = 0
	call <SID>DisplayBuf(results)
	call <SID>CreateAllStatus()
	call <SID>CreateTimeStamp()
	call <SID>SetupSyntax()
	let @" = @0
endfunction

function! <SID>VimGrepFunc(arg1, ...)
    :call <SID>VimGrepFuncInner('grep', a:arg1, a:000)
endfunction
function! <SID>VimFindFunc(arg1)
    :call <SID>VimGrepFuncInner('file', a:arg1, [])
endfunction

function! <SID>RepeatGrep()
	if     s:mgrep_commnad_num == 1 " Grep
		call <SID>GrepFunc(w:mgrep_args)
	elseif s:mgrep_commnad_num == 2 " VimGrep
		call <SID>VimGrepFunc(w:text_pat, w:file_pat)
	elseif s:mgrep_commnad_num == 3 " VimFind
		call <SID>VimFindFunc(w:file_pat)
	elseif s:mgrep_commnad_num == 4 " Qf
		call <SID>QfFunc()
	endif
endfunction

function! <SID>CreateTimeStamp()
	let s:mgrep_file_timestamp = ""
	let end_line = line("$")
	let linenum = 1
	while linenum <= end_line
		let line = <SID>GetNoStatusLine(linenum)
		if match(line, g:mgrep_ignore_pattern) == -1 && match(line, g:mgrep_line_pattern) == -1 && match(line, g:mgrep_filename_pattern) != -1
			let filename = substitute(line, g:mgrep_filename_pattern, "\\1", "")
			let s:mgrep_file_timestamp = s:mgrep_file_timestamp.<SID>FormatNumStr(getftime(filename), s:timestamp_size)
		else
			let s:mgrep_file_timestamp = s:mgrep_file_timestamp.repeat(' ', s:timestamp_size)
		endif
		let linenum = linenum + 1
	endwhile
endfunction

function! <SID>GetTimeStamp(line_num)
	let pos = (a:line_num - 1) * s:timestamp_size
	return strpart(s:mgrep_file_timestamp, pos, s:timestamp_size) + 0
endfunction

function! <SID>SetTimeStamp(line_num, time_stamp_num)
	let pos = (a:line_num - 1) * s:timestamp_size
	let s:mgrep_file_timestamp = strpart(s:mgrep_file_timestamp, 0, pos).<SID>FormatNumStr(a:time_stamp.strpart, s:timestamp_size).(s:mgrep_file_timestamp, pos + s:time_stamp)
endfunction

function! <SID>GetNoStatusStr(str)
	let str = a:str
	if s:mgrep_showing_status
		let str = strpart(str, s:status_line_size)
	endif
	return str 
endfunction

function! <SID>GetNoStatusLine(linenum)
	let line = getline(a:linenum)
	return <SID>GetNoStatusStr(line)
endfunction

function! <SID>DisplayBuf(lines)
	call <SID>DebugOut("call DisplayBuf()")	
	call <SID>UnMapKeys()
	setlocal modifiable
	" Clear Buffer
	normal! ggVGd
  call setline(1, a:lines)
	if s:mgrep_showing_status
		call <SID>ShowStatus(1)
	endif
	setlocal nomodifiable
	call <SID>MapKeys()
endfunction

function! <SID>OpenFile(str, ...)
	let str = <SID>GetNoStatusStr(a:str)
	setlocal modifiable
	call <SID>DebugOut("f_pat: ".g:mgrep_filename_pattern)
	call <SID>DebugOut("l_pat: ".g:mgrep_line_pattern)
	call <SID>DebugOut("input: ".str)
	if match(str, g:mgrep_ignore_pattern) != -1
		" Ignore pattern
	elseif match(str, g:mgrep_line_pattern) != -1
		let line_num = substitute(str, g:mgrep_line_pattern, "\\1", "")
		call <SID>DebugOut("line_num: ".line_num)
		" save current position before executig search function search
		let save_line = line(".")
		let filename = <SID>GetNoStatusLine(search(g:mgrep_filename_pattern, "b"))
		call cursor(save_line, 0)
		let w:mgrep_cursor_pos = save_line
		if strlen(filename) != 0
			let filename = substitute(filename, g:mgrep_filename_pattern, "\\1", "")
			call <SID>DebugOut("e ".filename)
			if a:0 > 0 && a:1 ==# "sp"
				execute "sp ".filename
			else
				execute "e ".filename
			endif
			execute "normal! ".line_num."G"
		endif
	elseif match(str, g:mgrep_filename_pattern) != -1
		let filename = substitute(str, g:mgrep_filename_pattern, "\\1", "")
		call <SID>DebugOut("open: ".filename)
		execute "e ".filename
	endif
endfunction

function! <SID>EditResultBuf()
	let line = line(".")

	let line_str = <SID>GetNoStatusLine(line)
	if match(line_str, g:mgrep_line_pattern) == -1
		return
	endif

	while <SID>GetLineStatus(line, 1) ==# "A"
		let line = line - 1
	endwhile
	let s:mgrep_edit_line = line
	let s:mgrep_edit_buf = <SID>GetEditLine(line)
	let line = line + 1
	while <SID>GetLineStatus(line, 1) ==# "A"
		let s:mgrep_edit_buf = s:mgrep_edit_buf."\n".<SID>GetEditLine(line)
		let line = line + 1
	endwhile

	if has("win32")
		execute "silent! sp [GrepEdit]"
	else
		execute "silent! sp \[GrepEdit\]"
	endif
endfunction

function! <SID>ExecuteFile()
	let line = line(".")

	let line_str = <SID>GetNoStatusLine(line)
  if match(line_str, g:mgrep_ignore_pattern) != -1
    return
  endif
	if match(line_str, g:mgrep_filename_pattern) == -1
		return
	endif

"  call system(substitute(line_str, "/", "\\", "g"))
  execute '!cmd /c "' . escape(substitute(line_str, '/', '\', 'g'), '"') . '"'
endfunction

function! <SID>CreateBuf()
	if has("win32")
		execute "silent! e [GrepResult]"
	else
		execute "silent! e \[GrepResult\]"
	endif
""	let w:mgrep_buffer=""
"	let w:buffer_exists=1
endfunction

function! <SID>MapKeys()
	map <silent> <buffer> <CR> :call <SID>OpenFile(getline("."))<CR>
	map <silent> <buffer> o :call <SID>OpenFile(getline("."), "sp")<CR>
	map <silent> <buffer> i :call <SID>EditResultBuf()<CR>
	map <silent> <buffer> x :call <SID>ExecuteFile()<CR>
	map <silent> <buffer> s :call <SID>ShowStatus()<CR>
	map <silent> <buffer> <C-^> :call <SID>ChangeBuf()<CR>
	if g:mgrep_opt_use_maplevel == 0 || g:mgrep_opt_use_maplevel == 1
		nmap <silent> <buffer> y :call <SID>YankLines("@\"", "n")<CR>
		vmap <silent> <buffer> y :call <SID>YankLines("@\"", "v")<CR>
		nmap <silent> <buffer> d :call <SID>DelLines("@\"", "n")<CR>
		vmap <silent> <buffer> d :call <SID>DelLines("@\"", "v")<CR>
		nmap <silent> <buffer> D :call <SID>UnDelLines()<CR>
		vmap <silent> <buffer> D :call <SID>UnDelLines()<CR>
		map <silent> <buffer> p :call <SID>PutLines(0)<CR>
		map <silent> <buffer> P :call <SID>PutLines(1)<CR>
	endif
	if g:mgrep_opt_use_maplevel == 0 || g:mgrep_opt_use_maplevel == 2
		map <silent> <buffer> u :call <SID>RepeatGrep()<CR>
		map <silent> <buffer> U :call <SID>UpdateResultBuf()<CR>
		map <silent> <buffer> t :call <SID>WriteFile()<CR>
		map <silent> <buffer> a :call <SID>WriteFile()<CR>:call <SID>RepeatGrep()<CR>
	endif
endfunction

function! <SID>UnMapKeys()
	mapclear <buffer>
endfunction

function! <SID>ChangeBuf()
	execute "b ".s:prev_bufnr
endfunction

function! <SID>UpdateResultBuf()
	let showing_status = 0
	if s:mgrep_showing_status
		call <SID>ShowStatus(0)
		let showing_status = 1
	endif
	setlocal modifiable

	let p_linenum = []
	let p_linestr = []
	let file_name = ""
	let i = 1
	let last = line("$")
try
	while i <= last
		let line_str = getline(i)
		if match(line_str, g:mgrep_ignore_pattern) == -1 && match(line_str, g:mgrep_line_pattern) == -1 && match(line_str, g:mgrep_filename_pattern) != -1

			let file_name = <SID>GetAbsolutePath(substitute(line_str, g:mgrep_filename_pattern, "\\1", ""))
			if !filereadable(file_name) || <SID>GetLineStatus(i, 1) ==# "C" || <SID>GetTimeStamp(i) == getftime(file_name)

				let i = i + 1
				continue
			endif

			let j = i + 1
			while j <= last
				if match(getline(j), g:mgrep_ignore_pattern) != -1 || match(getline(j), g:mgrep_line_pattern) == -1
					break
				endif
				call add(p_linenum, <SID>GetEditLineNum(j))
				let j = j + 1
			endwhile

			" 読み込み
			execute "sp ".file_name
			set bufhidden=delete
			let j = 0
			let n_size = len(p_linenum)
			while j < n_size
				if get(p_linenum, j) <= line("$")
					call add(p_linestr, getline(get(p_linenum, j)))
				endif
				let j = j + 1
			endwhile
			close

			let j = 0
			let l_size = len(p_linestr)
			while j < l_size
				call <SID>SetEditLine(j + i + 1, get(p_linestr, j), " ")
				let j = j + 1
			endwhile

			let dec_size = l_size - n_size
			if dec_size < 0
				execute "".(i+1+l_size).",".(i+1+n_size)."d"
			endif
			call <SID>FitStatusLine(l_size-1, dec_size)

			let p_linenum = []
			let p_linestr = []
		endif
		let i = i + 1
	endwhile
	call <SID>CreateTimeStamp()

finally
	if showing_status
		call <SID>ShowStatus(1)
	endif
	setlocal nomodifiable
endtry
endfunction

function! <SID>YankLines(reg, flag)
	if a:flag == "v"
		if line("'<") != line(".")
			return
		endif
		let i = line("'<")
		let last = line("'>")
		let tmp = ""
		while i <= last
			if <SID>GetLineStatus(i, 1) !=# "D"
				let tmp = tmp."\n".<SID>GetEditLine(i)
			endif
			let i = i + 1
		endwhile
		if strlen(tmp) != 0
			" 余分な改行を省く
			let tmp = strpart(tmp, 1)
		endif
		execute "let ".a:reg." = tmp"
	else
		execute "let ".a:reg." = <SID>GetEditLine(line(\".\"))"
	endif
endfunction

function! <SID>UnDelLines()
	if <SID>GetLineStatus(line("."), 1) ==# "D"
		call <SID>SetLineStatus(line("."), 1, "C")
	endif

	call <SID>UpdateStatus()
	if s:mgrep_showing_status
		call <SID>ShowStatus(0)
		call <SID>ShowStatus(1)
	endif
endfunction

function! DLine()
try
	call <SID>UnMapKeys()
	setlocal modifiable

    let line = line('.')
    if match(<SID>GetNoStatusLine(line), g:mgrep_ignore_pattern) != -1
            \ || match(<SID>GetNoStatusLine(line), g:mgrep_line_pattern) == -1
        return
    endif

    let status = <SID>GetLineStatus(line, 1)

    if status ==# "C"
        if <SID>GetLineStatus(line+1, 1) ==# "A"
            execute line."d"
            call <SID>FitStatusLine(line-1, -1)
            call <SID>SetLineStatus(line, 1, "C")
        else
            call <SID>SetLineStatus(line, 1, "D")
        endif
    elseif status ==# "A"
        execute line."d"
        call <SID>FitStatusLine(line-1, -1)
    elseif status ==# "D"
    else
        call <SID>SetLineStatus(line, 1, "D")
    endif
finally
	call <SID>UpdateStatus()
	setlocal nomodifiable
	call <SID>MapKeys()
	if s:mgrep_showing_status
		call <SID>ShowStatus(0)
		call <SID>ShowStatus(1)
	endif
endtry
endfunction

function! <SID>DelLines(reg, flag)
	if a:flag == "v"
		if line("'<") != line(".")
			return
		endif
		let first = line("'<")
		let last = line("'>")
	else
		let first = line(".")
		let last = line(".")
	endif
try
	let tmp = ""
	call <SID>UnMapKeys()
	setlocal modifiable

	let cnt = last - first + 1
	let i = 0
	let line = first
	while i < cnt
		if match(<SID>GetNoStatusLine(line), g:mgrep_ignore_pattern) != -1
				\ || match(<SID>GetNoStatusLine(line), g:mgrep_line_pattern) == -1
			let line = line + 1
			let i = i + 1
			continue
		endif

		let status = <SID>GetLineStatus(line, 1)

		if status !=# "D"
			let tmp = tmp."\n".<SID>GetEditLine(line)
		endif

		if status ==# "C"
			if <SID>GetLineStatus(line+1, 1) ==# "A"
				execute line."d"
				call <SID>FitStatusLine(line-1, -1)
				call <SID>SetLineStatus(line, 1, "C")
			else
				call <SID>SetLineStatus(line, 1, "D")
				let line = line + 1
			endif
		elseif status ==# "A"
			execute line."d"
			call <SID>FitStatusLine(line-1, -1)
		elseif status ==# "D"
			let line = line + 1
		else
			call <SID>SetLineStatus(line, 1, "D")
			let line = line + 1
		endif
		let i = i + 1
	endwhile
	if strlen(tmp) != 0
		" 余分な改行を省く
		let tmp = strpart(tmp, 1)
	endif
	execute "let ".a:reg." = tmp"
finally
	call <SID>UpdateStatus()
	setlocal nomodifiable
	call <SID>MapKeys()
	if s:mgrep_showing_status
		call <SID>ShowStatus(0)
		call <SID>ShowStatus(1)
	endif
endtry
endfunction

function! <SID>PutLines(flag)
	let showing_status = s:mgrep_showing_status
	if showing_status
		call <SID>ShowStatus(0)
	endif
	setlocal modifiable

	let line = line(".")
	let line_str = getline(line)
	if match(line_str, g:mgrep_line_pattern) == -1
		return
	endif
	let status = <SID>GetLineStatus(line, 1)
	let linenum_str = matchstr(line_str, g:mgrep_line_pattern_linenum)

	if status ==# "D"
		" Delete line with delete flag and new line.
		let size = <SID>SetLines(line, @") - 1
		call <SID>FitStatusLine(line-1, size)
		call <SID>SetLineStatus(line, 1, "C")
		call setline(line, linenum_str.getline(line))
		let i = line + 1
		let last = line + size
		while i <= last
			call <SID>SetLineStatus(i, 1, "A")
			call setline(i, linenum_str.getline(i))
			let i = i + 1
		endwhile
	elseif a:flag
		" put to forward
		let size = <SID>AppendLines(line - 1, @")
		call <SID>FitStatusLine(line - 1, size)
		if status ==# "A"
			call <SID>SetLineStatus(line, 1, "A")
		else
			call <SID>SetLineStatus(line, 1, "C")
		endif
		let i = line 
		let last = line + size
		while i < last
			call <SID>SetLineStatus(i + 1, 1, "A")
			call setline(i, linenum_str.getline(i))
			let i = i + 1
		endwhile
	else
		" put to back
		let size = <SID>AppendLines(line, @")
		call <SID>FitStatusLine(line, size)
		if status !=# "A" && status !=# "C"
			call <SID>SetLineStatus(line, 1, "C")
		endif
		let i = line + 1
		let last = line + size
		while i <= last
			call <SID>SetLineStatus(i, 1, "A")
			call setline(i, linenum_str.getline(i))
			let i = i + 1
		endwhile
	endif

	let @" = @0
	call <SID>UpdateStatus()

	if showing_status
		call <SID>ShowStatus(1)
	endif
	setlocal nomodifiable
endfunction

function! <SID>FitStatusLine(line, inc_size)
  " Arranging status line and timestamp.
	if a:inc_size > 0
		let blank = repeat(' ', s:status_line_size * a:inc_size)
		let s:mgrep_line_status = <SID>StrInsert(s:mgrep_line_status, a:line * s:status_line_size, blank)
		let blank = repeat(' ', s:timestamp_size * a:inc_size)
		let s:mgrep_file_timestamp = <SID>StrInsert(s:mgrep_file_timestamp, a:line * s:timestamp_size, blank)
	elseif a:inc_size < 0
		let s:mgrep_line_status = <SID>StrDelPart(s:mgrep_line_status, a:line * s:status_line_size, (-a:inc_size) * s:status_line_size)
		let s:mgrep_file_timestamp = <SID>StrDelPart(s:mgrep_file_timestamp, a:line * s:timestamp_size, (-a:inc_size) * s:timestamp_size)
	endif
endfunction

function! <SID>InitResult()
	"call confirm("InitResult()")
	call <SID>DebugOut("call InitResult()")	
	" command initilization 
	command! -range -nargs=1 Substitute :call <SID>SubFunc(<line1>,<line2>,<f-args>)
	command! MGRepeat			:call <SID>RepeatGrep()
	command! MGUpdate			:call <SID>UpdateResultBuf()
	command! MGWrite 			:call <SID>WriteFile()
	command! MGWriteAndUpdate	:call <SID>WriteFile() | call <SID>RepeatGrep()

	if !exists("s:mgrep_showing_status")
		let s:mgrep_showing_status = 0
	endif

	setlocal modifiable

	if s:mgrep_edit_close && s:mgrep_edit_buf_modified
		let showing_status = 0
		if s:mgrep_showing_status
			call <SID>ShowStatus(0)
			let showing_status = 1
		endif
		setlocal modifiable

		" [GrepEdit] is closed.
		if s:mgrep_edit_line > 0
			let chg_line = getline(s:mgrep_edit_line)	
			let add_line = s:mgrep_edit_line + 1
			while <SID>GetLineStatus(add_line, 1) == "A"
				let add_line = add_line + 1
			endwhile
			if add_line > s:mgrep_edit_line + 1
				execute "".(s:mgrep_edit_line+1).",".(add_line-1)."d"
			endif
			let linenum_str = matchstr(chg_line, g:mgrep_line_pattern_linenum)
			let size = <SID>SetLines(s:mgrep_edit_line, s:mgrep_edit_buf)

			let i = s:mgrep_edit_line
			let last = s:mgrep_edit_line + size
			while i < last
				call setline(i, linenum_str.getline(i))
				let i = i + 1
			endwhile

			let inc_size = size - (add_line - s:mgrep_edit_line)
			call <SID>FitStatusLine(s:mgrep_edit_line, inc_size)

			call <SID>SetLineStatus(s:mgrep_edit_line, 1, "C")
			while size > 1
				let size = size - 1
				call <SID>SetLineStatus(s:mgrep_edit_line + size, 1, "A")
			endwhile
		endif
		if showing_status
			call <SID>ShowStatus(1)
		endif
		let s:mgrep_edit_close = 0
	endif
	let s:mgrep_edit_line = 0

	if !exists("w:mgrep_cursor_pos")
		let w:mgrep_cursor_pos = 0
	endif

	if has("syntax")
		call <SID>SetupSyntax()
	endif
	call <SID>MapKeys()

	let s:_cpo = &cpo
	set cpo&vim
	let s:_insertmode = &insertmode
	set noinsertmode
	let s:_report = &report
	let &report = 10000
	setlocal nonumber
	setlocal foldcolumn=0
	setlocal nofoldenable
	setlocal buftype=nofile
	setlocal noswapfile
	setlocal nowrap
	setlocal nomodifiable
	setlocal bufhidden=hide

    let s:_current_path = getcwd()
    if !empty(w:mgrep_current_path)
        execute 'cd ' . w:mgrep_current_path
    endif
endfunction

function! <SID>EndResult()
	"call confirm("EndResult()")
	delcommand Substitute
	delcommand MGRepeat
	delcommand MGUpdate
	delcommand MGWrite
	delcommand MGWriteAndUpdate

	let &insertmode = s:_insertmode
	let &cpo = s:_cpo
	let &report = s:_report
	setlocal modifiable

    if !empty(s:_current_path)
        execute 'cd ' . s:_current_path
    endif
endfunction

function! <SID>InitEdit()
	"call confirm("InitEdit()")
	setlocal bufhidden=delete
	setlocal buftype=nofile
	setlocal nobuflisted
	setlocal modifiable
	map <silent> <buffer> <C-^> :close<CR>
	call <SID>SetLines(1, s:mgrep_edit_buf)
endfunction

function! <SID>EndEdit()
	"call confirm("EndEdit()")
	let tmp = <SID>FlattenLines(1, line("$"))
	if tmp ==# s:mgrep_edit_buf
		let s:mgrep_edit_buf_modified = 0
	else 
		let s:mgrep_edit_buf_modified = 1
		let s:mgrep_edit_buf = tmp
	endif
	let s:mgrep_edit_close = 1
endfunction

" orep syntax
if has("syntax")
	function! <SID>SetupSyntax()
		call <SID>DebugOut("setup_syntax")
		syntax clear
		if s:mgrep_prg =~ '.*orep'
			if s:mgrep_showing_status
				syntax match mgrepStatus /^.\{4}/ contained
				syntax match mgrepFileName /^.\{4}[^?<>|\"*]\+$/ contains=mgrepStatus
				syntax match mgrepSearchPattern /^.\{4}search.*:/ contains=mgrepStatus
				syntax match mgrepLine     /^.\{4}\t\d\+>/ contains=mgrepStatus
				syntax match mgrepComment /^.\{4}<.*>$/ contains=mgrepStatus
				highlight link mgrepSearchPattern Special
				highlight link mgrepFileName Statement
				highlight link mgrepLine Type
				highlight link mgrepComment Comment 
				highlight link mgrepStatus Identifier
			else
				syntax match mgrepFileName /^[^?<>|"*]\+$/
				syntax match mgrepSearchPattern /^search.*:/
				syntax match mgrepLine     /^\t\d\+>/
				syntax match mgrepComment /^<.*>$/
				highlight link mgrepSearchPattern Special
				highlight link mgrepFileName Statement
				highlight link mgrepLine Type
				highlight link mgrepComment Comment 
			endif
		endif
	endfunction
endif

function! <SID>UpdateStatus()
	call <SID>DebugOut("UpdateStatus> in")
	let file_line = 0
	let file_first = 0
	let next = 0
	while 1
		let next = match(s:mgrep_line_status, "[CDWR]", next)
		if next == -1
			break
		endif
		let line = next / s:status_line_size + 1
		if s:mgrep_line_status[next] ==# "C" 
				\ || s:mgrep_line_status[next] ==# "D"
			" line
			if file_line == 0
				echo "UpdateStatus> line[".line."]: File is not exists!"
			endif
			if file_first
				let s:mgrep_line_status = <SID>StrReplace(s:mgrep_line_status, ((file_line-1) * s:status_line_size)+1, "C")
				let file_first = 0
			endif
		else
			" file
			let file_line = line
			let file_first = 1
		endif
		let next = next + 1
	endwhile
	
	" update display
	if s:mgrep_showing_status
		setlocal modifiable
		let linenum = 1
		let last_linenum = line("$")
		while linenum <= last_linenum
			call setline(linenum, strpart(s:mgrep_line_status, s:status_line_size * (linenum - 1), s:status_line_size).<SID>GetNoStatusLine(linenum))
			let linenum = linenum + 1
		endwhile
		setlocal nomodifiable
	endif
endfunction

" flag = 0 : Not Show, flag = 1 : Show
function! <SID>ShowStatus(...)
	if a:0 > 0
		let flag = a:1
	else 
		let flag = !s:mgrep_showing_status
	endif
	let s:mgrep_showing_status = flag

	setlocal modifiable
	if flag
		call <SID>DebugOut("ShowStatus: show")
		if strlen(s:mgrep_line_status) == 0
			call <SID>CreateAllStatus()
		end
		let linenum = 1
		let last_linenum = line("$")
		while linenum <= last_linenum
			call setline(linenum, strpart(s:mgrep_line_status, s:status_line_size * (linenum - 1), s:status_line_size).getline(linenum))
			let linenum = linenum + 1
		endwhile
	else
		call <SID>DebugOut("ShowStatus: not show")
		let linenum = 1
		let last_linenum = line("$")
		while linenum <= last_linenum
			call setline(linenum, strpart(getline(linenum), s:status_line_size))
			let linenum = linenum + 1
		endwhile
	endif
	setlocal nomodifiable
	call <SID>SetupSyntax()
endfunction

function! <SID>CreateAllStatus()
	let s:mgrep_line_status = ""
	let linenum = 1
	let last_linenum = line("$")
	while linenum <= last_linenum
		let s:mgrep_line_status = s:mgrep_line_status.<SID>CreateStatus(linenum)
		let linenum = linenum + 1
	endwhile
endfunction

" NOTE: shuld return same length to s:status_line_size
function! <SID>CreateStatus(linenum)
	
	let line = getline(a:linenum)

	if match(line, g:mgrep_ignore_pattern) != -1
		return repeat(' ', s:status_line_size)
	elseif match(line, g:mgrep_line_pattern) != -1
		" line in file?
		let fileline = substitute(line, g:mgrep_filename_pattern, "\\1", "")	
		return repeat(' ', s:status_line_size)
	elseif match(line, g:mgrep_filename_pattern) != -1
		" filename?
		let filename = substitute(line, g:mgrep_filename_pattern, "\\1", "")	
		if filewritable(filename)
			let status = "W"
		elseif filereadable(filename)
			let status = "R"
		else
			let status = "!"
		endif	
		let cnt = s:status_line_size - strlen(status)
		let status = status.repeat(' ', cnt)
		return status
	endif

	echo "CreateStatus> Failed to parse line. line:".line
	return "    "
endfunction

function! <SID>FormatNumStr(num, size)
	return a:num . repeat(' ', a:size - len(a:num))
endfunction

function! <SID>FlattenLines(first, last, ...)
	let sep = a:0 > 0 ? a:1 : "\n"
	let i = a:first < 1 ? 1 : a:first
	let last = a:last > line("$") ? line("$") : a:last
	let retval = ""
	while i < last
		let retval = retval.getline(i).sep
		let i = i + 1
	endwhile
	if i == last
		let retval = retval.getline(i)
	endif
	return retval
endfunction

" retval : appended line size
" retval = 0 : false
function! <SID>SetLines(line, str, ...)
	let sep = a:0 > 0 ? a:1 : "\n"	
	let pos = stridx(a:str, sep)
	if pos == -1
		call setline(a:line, a:str)	
		return 1
	elseif pos == strlen(a:str) - 1
		call setline(a:line, strpart(a:str, 0, strlen(a:str)-1))	
		return 1
	else
		call setline(a:line, strpart(a:str, 0, pos))
		return <SID>AppendLines(a:line, strpart(a:str, pos + 1)) + 1
	endif
endfunction

function! <SID>AppendLines(line, str, ...)
	let sep = a:0 > 0 ? a:1 : "\n"	
	let line = a:line
	let len = strlen(a:str)
	let next = 0
	while next < len
		let prev = next
		let next = match(a:str, sep, next)
		if next == -1
			if append(line, strpart(a:str, prev))
				echo "<SID>AppendLines() Failed"	
				return 0
			endif
			let line = line + 1
			break
		endif
		if append(line, strpart(a:str, prev, next-prev))
			echo "<SID>AppendLines() Faild"	
			return 0
		endif
		let line = line + 1
		let next = next + 1
	endwhile

	return line - a:line
endfunction
function! <SID>StrReplace(dst, idx, src)
	return strpart(a:dst, 0, a:idx).a:src.strpart(a:dst, a:idx+strlen(a:src))
endfunction

function! <SID>StrDelPart(dst, idx, len)
	return strpart(a:dst, 0, a:idx).strpart(a:dst, a:idx+a:len)
endfunction

function! <SID>GetAbsolutePath(str)
	let currentPath = getcwd()
	let pos = 0
	let isReduction = 0
	let path = a:str
	while 1
		let pos = stridx(path, "..".s:line_separator)
		if pos == -1
			let pos = stridx(path, ".".s:line_separator)
			if pos == -1
				break
			endif
			let isReduction = 1
			let pos = pos + 2
			let path = strpart(path, pos-1)
			continue
		end
		let isReduction = 1
		let pos = pos + 3
		let path = strpart(path, pos-1)
		let redPos = strridx(currentPath, s:line_separator)
		let currentPath = strpart(currentPath, 0, redPos)
	endwhile
	if isReduction == 1
		return currentPath.path 
	endif
	return a:str 
endfunction 

function! <SID>StrInsert(dst, idx, src)
	return strpart(a:dst, 0, a:idx).a:src.strpart(a:dst, a:idx)
endfunction

command! -nargs=+ -complete=file Grep call <SID>GrepFunc(<f-args>)
command! -nargs=+ -complete=file VimGrep call <SID>VimGrepFunc(<f-args>)
command! -nargs=+ -complete=file VimFind call <SID>VimFindFunc(<f-args>)
command! QfList call <SID>QfFunc()
