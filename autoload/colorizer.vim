" colorizer.vim	Colorize all text in the form #rrggbb or #rgb; autoload functions
" Maintainer:	lilydjwg <lilydjwg@gmail.com>
" Version:	1.4.2
" License:	Vim License  (see vim's :help license)
"
" See plugin/colorizer.vim for more info.

let s:keepcpo = &cpo
set cpo&vim

function! s:Rgb2xterm(color) "{{{1
  " selects the nearest xterm color for a rgb value like #FF0000
  let best_match=0
  let smallest_distance = 10000000000
  let r = str2nr(a:color[1:2], 16)
  let g = str2nr(a:color[3:4], 16)
  let b = str2nr(a:color[5:6], 16)
  let colortable = s:GetXterm2rgbTable()
  for c in range(0,254)
    let d = pow(colortable[c][0]-r,2) + pow(colortable[c][1]-g,2) + pow(colortable[c][2]-b,2)
    if d<smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor
  return best_match
endfunction

"" the 6 value iterations in the xterm color cube {{{1
let s:valuerange = [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]

"" 16 basic colors {{{1
let s:basic16 = [
      \ [0x00, 0x00, 0x00], [0xCD, 0x00, 0x00],
      \ [0x00, 0xCD, 0x00], [0xCD, 0xCD, 0x00],
      \ [0x00, 0x00, 0xEE], [0xCD, 0x00, 0xCD],
      \ [0x00, 0xCD, 0xCD], [0xE5, 0xE5, 0xE5],
      \ [0x7F, 0x7F, 0x7F], [0xFF, 0x00, 0x00],
      \ [0x00, 0xFF, 0x00], [0xFF, 0xFF, 0x00],
      \ [0x5C, 0x5C, 0xFF], [0xFF, 0x00, 0xFF],
      \ [0x00, 0xFF, 0xFF], [0xFF, 0xFF, 0xFF]]

function! s:Xterm2rgb(color) "{{{1
  " 16 basic colors
  let r = 0
  let g = 0
  let b = 0
  if a:color<16
    let r = s:basic16[a:color][0]
    let g = s:basic16[a:color][1]
    let b = s:basic16[a:color][2]
  endif

  " color cube color
  if a:color>=16 && a:color<=232
    let l:color=a:color-16
    let r = s:valuerange[(l:color/36)%6]
    let g = s:valuerange[(l:color/6)%6]
    let b = s:valuerange[l:color%6]
  endif

  " gray tone
  if a:color>=233 && a:color<=253
    let r=8+(a:color-232)*0x0a
    let g=r
    let b=r
  endif
  let rgb=[r,g,b]
  return rgb
endfunction

" Color Converters {{{1
function! s:RgbBgColor() "{{{2

  let bg = synIDattr(synIDtrans(hlID("Normal")), "bg")

  if match(bg, '#\x\{6\}') > -1
    return [
      \ str2nr(bg[1:2], 16),
      \ str2nr(bg[3:4], 16),
      \ str2nr(bg[5:6], 16),
    \ ]
  endif

  return []

endfunction

function! s:IntAlphaMix(rgba_fg, rgb_bg)

  let fa = a:rgba_fg[3] / 255.0
  let fb = (1.0 - fa)
  let l_blended = map(range(3), {ix, _ -> (a:rgba_fg[ix] * fa) + (a:rgb_bg[ix] * fb)})
  return map(l_blended, {_, v -> float2nr(round(v))})

endfunction

" DECONSTRUCTS
" RGB: #00f #0000ff
" RGBA: #00f8 #0000ff88
" or ARGB: #800f #880000ff
function! s:HexCode(color_text_in) "{{{2

  let rgb_bg = s:RgbBgColor()
  let rx_color_prefix = '%(#|0x)'
  let is_alpha_first = (get(g:, 'colorizer_hex_alpha_first') == 1)

  " STRIP HEX PREFIX
  let foundcolor = tolower(substitute(a:color_text_in, '\v' . rx_color_prefix, '', ''))
  let colorlen = len(foundcolor)

  " SPLIT INTO COMPONENT VALUES
  let lColor = [0xff,0xff,0xff,0xff]
  let matchcolor = foundcolor . '\ze'
  if colorlen == 8

    for ix in [0,1,2,3]
      let ic = ix * 2
      let lColor[ix] = str2nr(foundcolor[ic:(ic+1)], 16)
    endfor

    " END MATCH AT COLOR DIGITS WHEN ALPHA DISPLAY IS UNAVAILABLE
    if empty(rgb_bg)
      if is_alpha_first
        let matchcolor = '\x\x\zs' . foundcolor[2:7] . '\ze'
      else
        let matchcolor = foundcolor[0:5] . '\ze\x\x'
      endif
    endif

  elseif colorlen == 6

    for ix in [0,1,2]
      let ic = ix * 2
      let lColor[ix] = str2nr(foundcolor[ic:(ic+1)], 16)
    endfor

  elseif colorlen == 4

    for ix in [0,1,2,3]
      let lColor[ix] = str2nr(foundcolor[ix], 16)
      let lColor[ix] = or(lColor[ix], lColor[ix] * 16)
    endfor

    " END MATCH AT COLOR DIGITS WHEN ALPHA DISPLAY IS UNAVAILABLE
    if empty(rgb_bg)
      if is_alpha_first
        let matchcolor = '\x\zs' . foundcolor[1:3] . '\ze'
      else
        let matchcolor = foundcolor[0:2] . '\ze\x'
      endif
    endif

  elseif colorlen == 3

    for ix in [0,1,2]
      let lColor[ix] = str2nr(foundcolor[ix], 16)
      let lColor[ix] = or(lColor[ix], lColor[ix] * 16)
    endfor

  endif

  " RGBA/ARGB NORMALIZE
  if is_alpha_first
    let lColor = lColor[1:3] + [lColor[0]]
  endif

  " MIX WITH BACKGROUND COLOR, IF SET
  if !empty(rgb_bg)
    let lColor = s:IntAlphaMix(lColor, rgb_bg)
  endif

  " RETURN [SYNTAX PATTERN, RGB COLOR LIST]
  let sz_pat = join(['\v\c', rx_color_prefix, matchcolor, '>'], '')
  return [sz_pat, lColor[0:2]]

endfunction

" DECONSTRUCTS rgb(255,128,64)
function! s:RgbColor(color_text_in) "{{{2

  " REGEX: COLOR EXTRACT
  let rx_colors = '\v' . join(map(range(1,3), {i, _ -> '\s*(\d{1,3})(\%?)\s*'}), ',')

  " EXTRACT COLOR COMPONENTS
  let rgb_matches = matchlist(a:color_text_in, rx_colors)
  if empty(rgb_matches) | break | endif

  " NORMALIZE TO NUMBER
  let lColor = []
  for ix in [1,3,5]
    let c_cmpnt = str2nr(rgb_matches[ix])
    if rgb_matches[ix+1] == '%'
      let rgb_matches[ix+1] = '\%' " ESCAPE FOR FOLLOWING MATCH REGEX
      let c_cmpnt = (c_cmpnt * 255) / 100
    endif
    if (c_cmpnt < 0) || (c_cmpnt > 255) | break | endif
    call add(lColor, c_cmpnt)
  endfor

  " SKIP INVALID COLORS
  if len(lColor) < 3 | continue | endif

  " BUILD HIGHLIGHT PATTERN
  let sz_pat = call(
        \ 'printf',
        \ [ '\v<rgb\(\s*%s%s\s*,\s*%s%s\s*,\s*%s%s\s*\)'] + rgb_matches[1:6]
      \ )

  return [sz_pat, lColor]

endfunction

" DECONSTRUCTS rgba(255,128,64,0.5)
function! s:RgbaColor(color_text_in) "{{{2

  let rgb_bg = s:RgbBgColor()

  " GET BASE COLOR
  let [pat_rgb, lColor] = s:RgbColor(a:color_text_in)
  let pat_rgb = substitute(pat_rgb, 'rgb', 'rgba', '')

  " SKIP MIXING WHEN BGCOLOR UNSPECIFIED
  if empty(rgb_bg)
    let pat_rgb = substitute(pat_rgb, '\\)', ',', '')
    return [pat_rgb, lColor]
  endif

  " EXTRACT ALPHA COMPONENT
  let alpha_match = matchlist(a:color_text_in, '\v\s*(1%(\.0+)?|0%(\.\d+)?)\s*\)')
  if empty(alpha_match) | break | endif
  let int_alpha = float2nr(round(str2float(alpha_match[1]) * 255.0))

  " APPEND ALPHA & MIX COLOR WITH BACKGROUND
  call add(lColor, int_alpha)
  let lColor = s:IntAlphaMix(lColor, rgb_bg)

  " UPDATE HIGHLIGHT PATTERN
  let pat_rgb = substitute(pat_rgb, '\\)',
        \ printf(',\s*%s\s*\\)', substitute(alpha_match[1], '\.', '\\.', '')),
        \ '')
  return [pat_rgb, lColor]

endfunction

" takes an [R,G,B] int color list, returns a matching color that is visible
function! s:FGforBGList(bg) "{{{1
  let fgc = g:colorizer_fgcontrast
  if (a:bg[0]*30 + a:bg[1]*59 + a:bg[2]*11) > 12000
    return s:predefined_fgcolors['dark'][fgc][1:]
  else
    return s:predefined_fgcolors['light'][fgc][1:]
  end
endfunction

" TODO: should probably be removed (misleading)
" selects the nearest xterm color for a rgb value like #FF0000
function! s:Rgb2xtermList(color) "{{{1
  let best_match=0
  let smallest_distance = 10000000000
  let colortable = s:GetXterm2rgbTable()
  for c in range(0,254)
    let d = pow(colortable[c][0] - a:color[0], 2) +
          \ pow(colortable[c][1] - a:color[1], 2) +
          \ pow(colortable[c][2] - a:color[2], 2)
    if d < smallest_distance
      let smallest_distance = d
      let best_match = c
    endif
  endfor
  return best_match
endfunction

function! s:OpenDebugBuf()
  let s:debug_buf_num = bufnr('Test', 1)
  call setbufvar(s:debug_buf_num, "&buflisted", 1)
  call bufload(s:debug_buf_num)
endfunction

function! s:WriteDebugBuf(object)
  if !exists('s:debug_buf_num') | call s:OpenDebugBuf() | endif
  call appendbufline(s:debug_buf_num, '$', js_encode(a:object))
endfunction

function! s:PreviewColorInLine(line_start, line_finish) "{{{1

  " SKIP PROCESSING HELPFILES (usually large)
  if getbufvar('%', '&syntax') ==? 'help' | return | endif

  " LINE LIMIT
  " TODO: number check first
  let lines = getline(a:line_start, a:line_finish)
  if g:colorizer_maxlines >= 0
    let lines = lines[:g:colorizer_maxlines]
  endif
  if empty(lines) | return | endif

  " TODO: HSL, HSLA
  " TODO: ALLOW PERCENT FOR ALPHA

  " SWITCH ON FULL GRAMMAR
  let rx_nums = join(map(range(3), {i,_ -> '\s*\d{1,3}\%?\s*'}), ',')
  let rx_grammar = [
        \ '%(#|0x)%(\x{8}|\x{6}|\x{4}|\x{3})',
        \ '<rgb\(' . rx_nums . '\)',
        \ '<rgba\(' . rx_nums . ',\s*%(1%(\.0+)?|0%(\.\d+)?)\s*\)',
      \]
  let rx_daddy = '\v\c%(' . join(rx_grammar, '|') . ')'

  " ITERATE THROUGH LINES
  let place = 0
  let ix_line = 0
  while 1

    " FIND NEXT COLOR TOKEN
    let [foundcolor, lastPlace, place] = matchstrpos(lines[ix_line], rx_daddy, place)
    if lastPlace < 0
      let ix_line += 1
      if ix_line < len(lines)
        let place = 0
        continue
      else
        break
      endif
    endif

    " EXTRACT COLOR INFORMATION FROM SYNTAX
    " RETURNS [syntax_pattern, rgb_color_list]
    let pat = ''
    let rgb_color = []
    if foundcolor[0] == '#' || foundcolor[0] == '0'
      let [pat, rgb_color] = s:HexCode(foundcolor)
    elseif foundcolor[0:3] ==? 'rgba'
      let [pat, rgb_color] = s:RgbaColor(foundcolor)
    elseif foundcolor[0:2] ==? 'rgb'
      let [pat, rgb_color] = s:RgbColor(foundcolor)
    else
      continue
    endif

    if empty(pat) || empty(rgb_color)
      continue
    endif

    " NOTE: pattern & color must be tracked independently, since
    "       multiple alpha patterns may map to the same highlight color
    let hex_color = call('printf', ['%02x%02x%02x'] + rgb_color)

    " INSERT HIGHLIGHT
    let group = 'Clrzr' . hex_color
    if !hlexists(group) || s:force_group_update

      let fg = g:colorizer_fgcontrast < 0 ? hex_color : s:FGforBGList(rgb_color)

      " &termguicolors can work outside of gVim in terminals with
      " true-color support with the following `vimrc` settings:
      "   let &t_8f = "\e[38;2;%lu;%lu;%lum" " set foreground color (ANSI, true-color mode)
      "   let &t_8b = "\e[48;2;%lu;%lu;%lum" " set background color (ANSI, true-color mode)
      "   set termguicolors
      if has('termguicolors') && &termguicolors
        exec join(['hi', group, 'guifg=#'.fg, 'guibg=#'.hex_color], ' ')
      elseif &t_Co == 256
        exec join(['hi', group, 'ctermfg='.s:Rgb2xtermList(fg), 'ctermbg='.s:Rgb2xtermList(rgb_color)], ' ')
      endif

    endif

    " INSERT MATCH PATTERN FOR HIGHLIGHT
    if !exists('w:colormatches') || !has_key(w:colormatches, pat)
      let w:colormatches[pat] = matchadd(group, pat)
    endif

  endwhile

endfunction

function! s:CursorMoved() "{{{1
  if !exists('w:colormatches')
    return
  endif
  if exists('b:colorizer_last_update')
    if b:colorizer_last_update == b:changedtick
      " Nothing changed
      return
    endif
  endif
  call s:PreviewColorInLine('.', '.')
  let b:colorizer_last_update = b:changedtick
endfunction

function! s:TextChanged() "{{{1
  if !exists('w:colormatches')
    return
  endif
  echomsg "TextChanged"
  call s:PreviewColorInLine('.', '.')
endfunction

" TODO: investigate frequency/necessity of autocmds
function! colorizer#ColorHighlight(update, ...) "{{{1
  if exists('w:colormatches')
    if !a:update
      return
    endif
    call s:ClearMatches()
  endif
  if (g:colorizer_maxlines > 0) && (g:colorizer_maxlines <= line('$'))
    return
  end
  let w:colormatches = {}
  if g:colorizer_fgcontrast != s:saved_fgcontrast || (exists("a:1") && a:1 == '!')
    let s:force_group_update = 1
  endif
  call s:PreviewColorInLine(1, '$')
  let s:force_group_update = 0
  let s:saved_fgcontrast = g:colorizer_fgcontrast
  augroup Colorizer
    au!
    if exists('##TextChanged')
      autocmd TextChanged * silent call s:TextChanged()
      if v:version > 704 || v:version == 704 && has('patch143')
        autocmd TextChangedI * silent call s:TextChanged()
      else
        " TextChangedI does not work as expected
        autocmd CursorMovedI * silent call s:CursorMoved()
      endif
    else
      autocmd CursorMoved,CursorMovedI * silent call s:CursorMoved()
    endif
    " rgba handles differently, so need updating
    autocmd GUIEnter * silent call colorizer#ColorHighlight(1)
    autocmd BufEnter * silent call colorizer#ColorHighlight(1)
    autocmd WinEnter * silent call colorizer#ColorHighlight(1)
    autocmd ColorScheme * let s:force_group_update=1 | silent call colorizer#ColorHighlight(1)
  augroup END
endfunction

function! colorizer#ColorClear() "{{{1
  augroup Colorizer
    au!
  augroup END
  augroup! Colorizer
  let save_tab = tabpagenr()
  let save_win = winnr()
  tabdo windo call s:ClearMatches()
  exe 'tabn '.save_tab
  exe save_win . 'wincmd w'
endfunction

function! s:ClearMatches() "{{{1
  if !exists('w:colormatches')
    return
  endif
  for i in values(w:colormatches)
    try
      call matchdelete(i)
    catch /.*/
      " matches have been cleared in other ways, e.g. user has called clearmatches()
    endtry
  endfor
  unlet w:colormatches
endfunction

function! colorizer#ColorToggle() "{{{1
  if exists('#Colorizer')
    call colorizer#ColorClear()
    echomsg 'Disabled color code highlighting.'
  else
    call colorizer#ColorHighlight(0)
    echomsg 'Enabled color code highlighting.'
  endif
endfunction

function! colorizer#AlphaPositionToggle() "{{{1
  if exists('#Colorizer')
    if get(g:, 'colorizer_hex_alpha_first') == 1
      let g:colorizer_hex_alpha_first = 0
    else
      let g:colorizer_hex_alpha_first = 1
    endif
    call colorizer#ColorHighlight(1)
  endif
endfunction

function! s:GetXterm2rgbTable() "{{{1
  if !exists('s:table_xterm2rgb')
    let s:table_xterm2rgb = []
    for c in range(0, 254)
      let s:color = s:Xterm2rgb(c)
      call add(s:table_xterm2rgb, s:color)
    endfor
  endif
  return s:table_xterm2rgb
endfun

" Setups {{{1
"let s:ColorFinder = [function('s:HexCode'), function('s:RgbColor')] ", function('s:RgbaColor')]
let s:force_group_update = 0
let s:predefined_fgcolors = {}
let s:predefined_fgcolors['dark']  = ['#444444', '#222222', '#000000']
let s:predefined_fgcolors['light'] = ['#bbbbbb', '#dddddd', '#ffffff']
if !exists("g:colorizer_fgcontrast")
  " Default to black / white
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
elseif g:colorizer_fgcontrast >= len(s:predefined_fgcolors['dark'])
  echohl WarningMsg
  echo "g:colorizer_fgcontrast value invalid, using default"
  echohl None
  let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
endif
let s:saved_fgcontrast = g:colorizer_fgcontrast

" Restoration and modelines {{{1
let &cpo = s:keepcpo
unlet s:keepcpo
" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:et
