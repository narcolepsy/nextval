"
" nextval - Increment/decrement the current value with one keystroke
"
" Copyright (C) 2013 Michael Arlt
"
" Distributed under the GNU General Public License (GPL) 3.0 or higher
" - see http://www.gnu.org/licenses/gpl.html
"

" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.

" Version: 1.11
"
" Changes: 1.11
" - Bugfix for increment/decrement in last empty line (Serpent)
" Changes: 1.1
" - Added boolen for python (True/False)
" - Added integer surrounded by text
" - Added many hex-variants
" - Improved float
" - Bugfix: inc/dec "worked" if you where near a value
" - Big thanx to serpent for code/feedback/ideas
" - Added expamples in source for simpler testing
" Changes: 1.02
" - Set default keys to overwrite Vims internal cmd C-a (inc) and C-x (dec)
" Changes: 1.01
" - Added standard check if already loaded
" - Uses <Plug> for automatic mapping (if not already defined)
"   -> Changed plugin calling - see usage
" - Removed forgotten debug output (sorry)
" - Added buffer awareness
"
" Installation:
" # if you use pathogen:
" mkdir -p ~/.vim/bundle/netxval/plugin
" cp nextval.vim  ~/.vim/bundle/netxval/plugin

" Usage: (e.g. in .vimrc)
" This is the default mapping if you did not define a setting on your own
" nmap <silent> <unique> + <Plug>nextvalInc
" nmap <silent> <unique> - <Plug>nextvalDec
" During editing position your cursor on a boolean, integer, number or
" hex value and press + or - in normal mode (esc).

" Tests:
" 15 # int
" -5 # neg. int
" 0.1 # num/float
" 0.25 # num/float
" .2 # num/float
" -0.1 # num/float
" test5 # int surrounded
" test123test # int surrounded
" true # boolean
" TRUE # boolean
" True # boolean
" 2b # hex
" 0a # hex
" 0xf9 # hex
" 0F # hex
" f # hex
" F # hex
" 5A3 # tex
" &#x2019 # xml/xhtml
" \x19 # unix, bash
" FFh or 05A3H # intel assembly
" #9 # modulo2
" 16#5A3# # ada/vhdl
" 16r5A3 # smalltalk/algol
" 16#5A7 # postscript/bash
" \u0019 \U00000019 # bash
" #16r4a # common lisp
" &H5A3 or &5a3 # several basic
" 0h5A3 ti series
" U+20AD # unicode
" S=U+9 # integer
" $5A3 # assembly/basic
" H'ABCD' # microchip
" x"5A3" # vhdl
" 8'hFF # verilog
" #x4a # common lisp
" X'5A3' # ibm mainframe


" check if already loaded
if exists('g:nextval_plugin_loaded')
	finish
endif
let g:nextval_plugin_loaded = 1

" default keymappings
if !hasmapto('<Plug>nextvalInc')
	nmap <silent> <unique> <C-a> <Plug>nextvalInc
endif
if !hasmapto('<Plug>nextvalDec')
	nmap <silent> <unique> <C-x> <Plug>nextvalDec
endif
" map <Plug> to internal function
nnoremap <unique> <script> <Plug>nextvalInc <SID>nextvalInc
nnoremap <SID>nextvalInc :call <SID>nextval('+')<CR>
nnoremap <unique> <script> <Plug>nextvalDec <SID>nextvalDec
nnoremap <SID>nextvalDec :call <SID>nextval('-')<CR>

"let s:re_hex = "\\(3'h\\|#16r\\|16#\\|16r\\|" " more pre-chars
let s:re_hex = "\\(\\d\\+'h\\|'h\\|#16r\\|16#\\|16r\\|" " more pre-chars
let s:re_hex = s:re_hex . 'x"\|#x\|0[xh]\|\\[xuU]\|[XH]' . "'\\|" " 2 pre-chars
let s:re_hex = s:re_hex . '[#\$hH]\|' " 1 pre-char
let s:re_hex = s:re_hex . '\|\)' " no pre-chars
let s:re_hex = s:re_hex . '\([0-9a-fA-F]\+\)' " hex himself
let s:re_hex = s:re_hex . "\\([hH#\"']\\|\\)" " post-chars

"let s:re_hex = "\\(3'h\\|#16r\\|16#\\|16r\\|" " more pre-chars
let s:re_bin = "\\(\\d\\+'b\\|'b\\|0b" " more pre-chars
"let s:re_bin = s:re_bin . 'x"\|#x\|0[xh]\|\\[xuU]\|[XH]' . "'\\|" " 2 pre-chars
"let s:re_bin = s:re_bin . '[#\$hH]\|' " 1 pre-char
let s:re_bin = s:re_bin . '\|\)' " no pre-chars
let s:re_bin = s:re_bin . '\([0-9a-fA-F]\+\)' " hex himself
let s:re_bin = s:re_bin . "\\([hH#\"']\\|\\)" " post-chars

" main
function s:nextval(operator)
	if !exists('b:nextval_column')
		" vars to remember last cursor position and determined word-type
		let b:nextval_column = ''
		let b:nextval_line = ''
		let b:nextval_type = ''
		let b:nextval_hexupper = 0
	endif

	" remember and adjust settings
	if 'a' == 'A'
		setlocal noignorecase
		let s:ignorecase = 1
	endif
	let s:iskeyword = &iskeyword   " remember current iskeyword
	silent setlocal iskeyword+=# " enable #XX hex values
	silent setlocal iskeyword+=$ " enable #XX hex values
	silent setlocal iskeyword+=\" " enable #XX hex values
	silent setlocal iskeyword+=' " enable #XX hex values
	silent setlocal iskeyword+=\\ " enable \xXX hex values
	silent setlocal iskeyword+=- " enable negative values
	silent setlocal iskeyword+=. " enable float values

	let word = expand('<cword>')

	" check if cursor is really on the expanded cword (vim-bug?!)
	if match(word,getline(".")[col(".") - 1]) < 0 || word == ''
		call s:cleanup()
		return
	endif

	" forget type if col/line changed
	if b:nextval_column != col('.') || b:nextval_line != line('.')
		let b:nextval_type = ''
	endif

	" determine type of word (int/hex)
	if matchstr(word,'\(-\?[1-9][0-9]*\)\|0') == word
		if b:nextval_type != 'hex'
			let b:nextval_type = 'int'
		endif
	elseif matchstr(word,'-\?[0-9]*\.[0-9]\+') == word
		let b:nextval_type = 'num'
	elseif matchstr(word, s:re_hex) == word
		let b:nextval_type = 'hex'
	elseif matchstr(word, s:re_bin) == word
		let b:nextval_type = 'bin'
	elseif matchstr(word,'true\|false\c') == word
		let b:nextval_type = 'bool'
	elseif matchstr(word,'\([^0-9]*\)\([0-9]\+\)\([^0-9]*\)') == word " increment/decrement integer surrounded by text (i.e. abc12)
		let b:nextval_type = 'int'
		let word_parts = matchlist(word,'\([^0-9]*\)\([0-9]\+\)\([^0-9]*\)')
		let word_prefix = word_parts[1]
		let word = word_parts[2]
		let word_suffix = word_parts[3]
		if str2nr(word) == 0 && a:operator == '-'	" do nothing when trying to decrement 0
			let b:nextval_type = 'ignore'
			unlet word_parts
		endif
	endif

	if b:nextval_type == 'int'
		let newword = a:operator == '+' ? str2nr(word)+1 : str2nr(word)-1
	elseif b:nextval_type == 'num'
		let newword = <SID>nextnum(word,a:operator)
	elseif b:nextval_type == 'hex'
		let newword = <SID>nexthex(word,a:operator)
	elseif b:nextval_type == 'bin'
		let newword = <SID>nextbin(word,a:operator)
	elseif b:nextval_type == 'bool'
		let newword = <SID>nextbool(word)
	endif

	if exists('word_parts')
		let newword = word_prefix . newword . word_suffix
	endif

	if exists('newword')
		execute 'normal ciw' . newword
		execute 'normal wb'
		let b:nextval_column = col('.')
		let b:nextval_line = line('.')
		"execute ':w'
	endif
	call s:cleanup()
	return
endfunction

" restore settings
function s:cleanup()
	if exists('s:ignorecase')
		setlocal ignorecase
	endif
	silent execute 'setlocal iskeyword='.s:iskeyword
	return
endfunction

" switch boolean value
function s:nextbool(value)
	if a:value == 'false'
		return 'true'
	elseif a:value == 'true'
		return 'false'
	elseif a:value == 'FALSE'
		return 'TRUE'
	elseif a:value == 'TRUE'
		return 'FALSE'
	elseif a:value == 'False'
		return 'True'
	elseif a:value == 'True'
		return 'False'
	endif
endfunction

" change numeric value (n; ,n; n,n)
function s:nextnum(value,operator)
	let dotpos = match(a:value,'\.')
	let fractdigits = len(a:value)-dotpos-1
	if a:operator == '+'
		let result = str2float(a:value)+(1/pow(10,fractdigits))
	else
		let result = str2float(a:value)-(1/pow(10,fractdigits))
	endif
	let newnum = printf('%.' . fractdigits . 'f',result)
	if dotpos == 0 && result < 1 && result > 0
		let newnum = strpart(newnum,1)
	endif
	return newnum
endfunction

" change hex value (#X; 0xX; X)
function s:nexthex(value,operator)
	let m = matchlist(a:value,s:re_hex)
	let prefix = m[1]
	let value = m[2]
	let suffix = m[3]
   "Check to see if there is a specified width for the hex number (verilog
   "only currently)
   if str2nr(s:verilog_width(prefix)) > 0
      let s:width = s:verilog_width(prefix)
      let has_width = 'true'
      let s:minus_one = float2nr(pow(2,s:width))-1
   endif
   "Now check if the value is about to go negative - if it is we care about
   "its width and have to perform some crude maths based on the width
   if has_width == 'true'
      let len = (s:width-1)/4+1
      if str2nr(value,16) == 0
         let newval = a:operator == '+' ? str2nr(value,16)+1 : s:minus_one
      elseif str2nr(value,16) == s:minus_one
         let newval = a:operator == '+' ? 0                  : str2nr(value,16)-1
      else
         let newval = a:operator == '+' ? str2nr(value,16)+1 : str2nr(value,16)-1
      endif
   else
      let newval = a:operator == '+' ? str2nr(value,16)+1 : str2nr(value,16)-1
      let len = len(value)
   endif

	if strpart(value,0,1) != '0' " || ... todo ?! when will a use have fixed digits?! ... fmod(len,2)
		let len = 1
	endif

   "Create upper/lowercase hex value
	if len(matchstr(value,'[A-F]'))
      let hex_modifier = 'X'
	elseif len(matchstr(value,'[a-f]'))
      let hex_modifier = 'x'
   else
      "TODO should not enter here!
      let hex_modifier = 'X'
	endif
   
   let newhex = printf('%0' . len . hex_modifier, newval)
	return prefix . newhex . suffix
endfunction

" change bin value (#X; 0xX; X)
function s:nextbin(value,operator)
	let m = matchlist(a:value,s:re_bin)
	let prefix = m[1]
	let value = m[2]
	let suffix = m[3]
	let len = len(value)
   "Check to see if there is a specified width for the hex number (verilog
   "only currently)
   if str2nr(s:verilog_width(prefix)) > 0
      let s:width = s:verilog_width(prefix)
      let has_width = 'true'
      let s:minus_one = float2nr(pow(2,s:width))-1
   endif
   "Now check if the value is about to go negative - if it is we care about
   "its width and have to perform some crude maths based on the width
   if has_width == 'true'
      if str2nr(value,2) == 0
         let newval = a:operator == '+' ? str2nr(value,2)+1 : s:minus_one
      elseif str2nr(value,2) == s:minus_one
         let newval = a:operator == '+' ? 0                 : str2nr(value,2)-1
      else
         let newval = a:operator == '+' ? str2nr(value,2)+1 : str2nr(value,2)-1
      endif
   else
      let newval = a:operator == '+' ? str2nr(value,2)+1 : str2nr(value,2)-1
   endif

	if strpart(value,0,1) != '0' " || ... todo ?! when will a use have fixed digits?! ... fmod(len,2)
		let len = 1
	endif
   if has_width == 'true'
      let newbin = printf('%0' . s:width . 'b', newval)
   else
      let newbin = printf('%0' . len . 'b', newval)
   endif
	return prefix . newbin . suffix
endfunction

function s:verilog_width(prefix)
   let s:re_width    = "\\(\\d\\+\\)'[hbd]"
   let local_width   = matchlist(a:prefix, s:re_width)
   if local_width[1] == ''
      return -1
   else
      return str2nr(local_width[1])
   endif
endfunction
