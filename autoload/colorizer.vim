" colorizer.vim	Colorize all text in the form #rrggbb or #rgb; autoload functions
" Licence:	Vim license. See ':help license'
" Maintainer:   Jason Stewart <support@eggplantsd.com>
" Derived From:	https://github.com/lilydjwg/colorizer
"               lilydjwg <lilydjwg@gmail.com>
" Derived From: css_color.vim
" 		http://www.vim.org/scripts/script.php?script_id=2150
" Thanks To:	Niklas Hofer (Author of css_color.vim), Ingo Karkat, rykka,
"		KrzysztofUrban, blueyed, shanesmith, UncleBill

" TODO: more comprehensive screenshot

let s:keepcpo = &cpo
set cpo&vim


" ---------------------------  CONSTANTS  ---------------------------


" USAGE: HUE
const s:RXFLT = '%(\d*\.)?\d+'

" USAGE: SAT / LGHTNESS
const s:RXPCT = '%(\d*\.)?\d+\%'

" USAGE: RGB / ALPHA
const s:RXPCTORFLT = '%(\d*\.)?\d+\%?'

" USAGE: PARAM SEPARATOR
const s:CMMA = '\s*,\s*'


" ---------------------------  DEBUG HELPERS  ---------------------------


function! s:OpenDebugBuf()
  let s:debug_buf_num = bufnr('Test', 1)
  call setbufvar(s:debug_buf_num, "&buflisted", 1)
  call bufload(s:debug_buf_num)
endfunction


function! s:WriteDebugBuf(object)
  if !exists('s:debug_buf_num') | call s:OpenDebugBuf() | endif
  let nt = type(a:object)
  if (nt == v:t_string) || (nt == v:t_float) || (nt == v:t_number)
    call appendbufline(s:debug_buf_num, '$', a:object)
  else
    call appendbufline(s:debug_buf_num, '$', js_encode(a:object))
  endif
endfunction


" ---------------------------  COLOR HELPERS  ---------------------------


" GET RGB BACKGROUND COLOR (R,G,B int list)
function! s:RgbBgColor()
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


" ALPHA MIX RGBA COLOR INTO RGB BACKGROUND COLOR
" (int lists)
function! s:IntAlphaMix(rgba_fg, rgb_bg)
  if len(a:rgba_fg) < 4
    return a:rgba_fg
  endif

  let fa = a:rgba_fg[3] / 255.0
  let fb = (1.0 - fa)
  let l_blended = map(range(3), {ix, _ -> (a:rgba_fg[ix] * fa) + (a:rgb_bg[ix] * fb)})
  return map(l_blended, {_, v -> float2nr(round(v))})
endfunction


" CHOOSES A REASONABLE FOREGROUND COLOR FOR A GIVEN BACKGROUND COLOR
" takes an [R,G,B] int color list
" returns an 'RRGGBB' hex color string
function! s:FGforBGList(bg) "{{{1

  " TODO: needs some work
  let fgc = g:colorizer_fgcontrast
  if (a:bg[0]*30 + a:bg[1]*59 + a:bg[2]*11) > 12000
    return s:predefined_fgcolors['dark'][fgc][1:]
  else
    return s:predefined_fgcolors['light'][fgc][1:]
  end
endfunction


" ---------------------------  COLOR/PATTERN EXTRACTORS  ---------------------------


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
  let rx_colors = join(map(range(3), {i, _ -> '(' . s:RXFLT . ')(\%?)'}), s:CMMA)

  " EXTRACT COLOR COMPONENTS
  let rgb_matches = matchlist(a:color_text_in, '\v\(\s*' . rx_colors)
  if empty(rgb_matches) | return ['',[]] | endif

  " NORMALIZE TO NUMBER
  let lColor = []
  for ix in [1,3,5]
    let c_cmpnt = str2float(rgb_matches[ix])
    if rgb_matches[ix+1] == '%'
      let rgb_matches[ix+1] = '\%' " ESCAPE FOR FOLLOWING MATCH REGEX
      let c_cmpnt = (c_cmpnt * 255.0) / 100.0
    endif
    if (c_cmpnt < 0.0) || (c_cmpnt > 255.0) | return ['',[]] | endif
    call add(lColor, float2nr(round(c_cmpnt)))
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


" DECONSTRUCTS: hsl(195, 100%, 50%)
function! s:HslColor(color_text_in) "{{{2

  " REGEX: COLOR EXTRACT
  let parts = [
        \ '(' . s:RXFLT . ')',
        \ '(' . s:RXFLT . ')\%',
        \ '(' . s:RXFLT . ')\%',
      \ ]

  let rx_colors = '\v\(\s*' . join(parts, s:CMMA)

  " EXTRACT COLOR COMPONENTS
  let hsl_matches = matchlist(a:color_text_in, rx_colors)
  if empty(hsl_matches) | return ['',[]] | endif

  " HUE TO NUMBER
  let hue = fmod(str2float(hsl_matches[1]), 360.0)
  if hue < 0.0 | let hue += 360.0 | endif
  let lColor = [hue]

  " SATURATION & LIGHTNESS TO NUMBER
  for ix in [2,3]
    let c_cmpnt = str2float(hsl_matches[ix]) / 100.0
    if (c_cmpnt < 0.0) || (c_cmpnt > 1.0) | return ['',[]] | endif
    call add(lColor, c_cmpnt)
  endfor

  " SKIP INVALID COLORS
  if len(lColor) < 3 | continue | endif

  " HSL -> RGB
  let chroma = (1.0 - abs((2.0*lColor[2]) - 1.0)) * lColor[1]
  let hprime = hue / 60.0
  let xval = chroma * (1.0 - abs(fmod(hprime,2.0) - 1))
  let mval = lColor[2] - (chroma / 2.0)

  if hprime < 1.0
    let lColor = [chroma, xval, 0.0]
  elseif hprime < 2.0
    let lColor = [xval, chroma, 0.0]
  elseif hprime < 3.0
    let lColor = [0.0, chroma, xval]
  elseif hprime < 4.0
    let lColor = [0.0, xval, chroma]
  elseif hprime < 5.0
    let lColor = [xval, 0.0, chroma]
  elseif hprime < 6.0
    let lColor = [chroma, 0.0, xval]
  endif

  let lColor = map(lColor, {_, v -> float2nr(round((v+mval) * 255.0))})

  " BUILD HIGHLIGHT PATTERN
  let sz_pat = call(
        \ 'printf',
        \ [ '\v<hsl\(\s*%s\s*,\s*%s\%%\s*,\s*%s\%%\s*\)'] + hsl_matches[1:3]
      \ )

  return [sz_pat, lColor]

endfunction


" HANDLES ALPHA VERSIONS OF RGB/HSL
function! s:AlphaColor(Color_Func, pat_search, pat_replace, color_text_in) "{{{2

  let hsl_bg = s:RgbBgColor()

  " GET BASE COLOR
  let [pat_hsl, lColor] = a:Color_Func(a:color_text_in)
  if empty(pat_hsl) || empty(lColor)
    return ['', []]
  endif

  let pat_hsl = substitute(pat_hsl, a:pat_search, a:pat_replace, '')

  " SKIP MIXING WHEN BGCOLOR UNSPECIFIED
  if empty(hsl_bg)
    let pat_hsl = substitute(pat_hsl, '\\)', ',', '')
    return [pat_hsl, lColor]
  endif

  " EXTRACT ALPHA COMPONENT
  let alpha_match = matchlist(a:color_text_in, '\v(' . s:RXPCTORFLT . ')\s*\)')
  if empty(alpha_match) | return ['', []] | endif
  let alpha_suff = alpha_match[1]

  " PARSE ALPHA TO [0.0, 1.0]
  let ix_pct = match(alpha_suff, '%')
  let alpha = 2.0
  if ix_pct > -1
    let alpha = str2float(alpha_suff[:ix_pct-1]) / 100.0
    " escape trailing percent sign
    let alpha_suff = escape(alpha_suff, '%')
  else
    let alpha = str2float(alpha_suff)
  endif

  " SCALE TO [0, 255]
  if alpha <= 1.0
    call add(lColor, float2nr(round(alpha * 255.0)))
  else
    return ['',[]]
  endif

  " MIX COLOR WITH BACKGROUND
  let lColor = s:IntAlphaMix(lColor, hsl_bg)

  " UPDATE HIGHLIGHT PATTERN
  " escape decimal point, then escape all slashes in the suffix
  let hsl_suff = escape(escape(alpha_suff, '.'), '\')
  " replace alpha suffix into pattern
  let pat_hsl = substitute(pat_hsl, '\\)', ',\\s*' . hsl_suff . '\\s*\\)','')

  return [pat_hsl, lColor]

endfunction


" BUILDS HIGHLIGHTS (COLORS+PATTERNS) FOR THE CURRENT BUFFER
" FROM line_start TO line_finish
function! s:PreviewColorInLine(line_start, line_finish) "{{{1

  " SKIP PROCESSING HELPFILES (usually large)
  if getbufvar('%', '&syntax') ==? 'help' | return | endif

  " GET LINES FROM CURRENT BUFFER
  " TODO: g:colorizer_maxlines?
  let lines = getline(a:line_start, a:line_finish)
  if empty(lines) | return | endif

  " SWITCH ON FULL GRAMMAR
  let rgb_nums = join(map(range(3), {i,_ -> s:RXPCTORFLT}), s:CMMA)
  let rx_grammar = [
        \ '%(#|0x)%(\x{8}|\x{6}|\x{4}|\x{3})',
        \ '<rgb\(\s*' . rgb_nums . '\s*\)',
        \ '<rgba\(\s*' . rgb_nums . s:CMMA . s:RXPCTORFLT . '\s*\)',
        \ '<hsl\(\s*' . join([s:RXFLT, s:RXPCT, s:RXPCT], s:CMMA) . '\s*\)',
        \ '<hsla\(\s*' . join([s:RXFLT, s:RXPCT, s:RXPCT, s:RXPCTORFLT], s:CMMA) . '\s*\)',
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
      let [pat, rgb_color] = s:AlphaColor(function('s:RgbColor'), 'rgb', 'rgba', foundcolor)
    elseif foundcolor[0:3] ==? 'hsla'
      let [pat, rgb_color] = s:AlphaColor(function('s:HslColor'), 'hsl', 'hsla', foundcolor)
    elseif foundcolor[0:2] ==? 'rgb'
      let [pat, rgb_color] = s:RgbColor(foundcolor)
    elseif foundcolor[0:2] ==? 'hsl'
      let [pat, rgb_color] = s:HslColor(foundcolor)
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
      exec join(['hi', group, 'guifg=#'.fg, 'guibg=#'.hex_color], ' ')
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

" TODO: global enable/disable, cleanup w:colormatches across windows
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
