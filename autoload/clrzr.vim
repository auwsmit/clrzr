" clrzr.vim     Highlights common color representations
" Licence:	Vim license. See ':help license'
" Maintainer:   Jason Stewart <support@eggplantsd.com>
" Derived From:	https://github.com/lilydjwg/colorizer
"               lilydjwg <lilydjwg@gmail.com>
" Derived From: css_color.vim
" 		http://www.vim.org/scripts/script.php?script_id=2150
" Thanks To:	Niklas Hofer (Author of css_color.vim), Ingo Karkat, rykka,
"		KrzysztofUrban, blueyed, shanesmith, UncleBill

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


function! s:WriteDebugBuf(object)

  let s:debug_buf_num = bufnr('Test', 1)
  call setbufvar(s:debug_buf_num, "&buflisted", 1)
  call bufload(s:debug_buf_num)

  let nt = type(a:object)
  if (nt == v:t_string) || (nt == v:t_float) || (nt == v:t_number)
    call appendbufline(s:debug_buf_num, '$', a:object)
  else
    call appendbufline(s:debug_buf_num, '$', js_encode(a:object))
  endif

endfunction


" WRITE AUTOCMD EVENTS TO QUICKFIX LIST (for event inspection)
function! s:SnoopEvent(evt)
  echomsg [bufnr('%'), win_getid(), a:evt]
endfunction


function! s:Debug(var)
  if 0 | echomsg a:var | endif
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
  let fgc = g:clrzr_fgcontrast
  if (a:bg[0]*30 + a:bg[1]*59 + a:bg[2]*11) > 12000
    return s:predefined_fgcolors['dark'][fgc][1:]
  else
    return s:predefined_fgcolors['light'][fgc][1:]
  end
endfunction


" ---------------------------  COLOR/PATTERN EXTRACTORS  ---------------------------

function! s:IsAlphaFirst()
  let is_alpha_first = get(w:, 'clrzr_hex_alpha_first', get(g:, 'clrzr_hex_alpha_first', 0))
  return (is_alpha_first == 1)
endfunction


" DECONSTRUCTS
" RGB: #00f #0000ff
" RGBA: #00f8 #0000ff88
" or ARGB: #800f #880000ff
function! s:HexCode(color_text_in, rgb_bg) "{{{2

  let rx_color_prefix = '%(#|0x)'
  let is_alpha_first = s:IsAlphaFirst()

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
    if empty(a:rgb_bg)
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
    if empty(a:rgb_bg)
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
  if !empty(a:rgb_bg)
    let lColor = s:IntAlphaMix(lColor, a:rgb_bg)
  endif

  " RETURN [SYNTAX PATTERN, RGB COLOR LIST]
  let sz_pat = join([rx_color_prefix, matchcolor, '>'], '')
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
        \ [ '<rgb\(\s*%s%s\s*,\s*%s%s\s*,\s*%s%s\s*\)'] + rgb_matches[1:6]
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
        \ [ '<hsl\(\s*%s\s*,\s*%s\%%\s*,\s*%s\%%\s*\)'] + hsl_matches[1:3]
      \ )

  return [sz_pat, lColor]

endfunction


" HANDLES ALPHA VERSIONS OF RGB/HSL
function! s:AlphaColor(Color_Func, pat_search, pat_replace, color_text_in, rgb_bg) "{{{2

  " GET BASE COLOR
  let [pat_hsl, lColor] = a:Color_Func(a:color_text_in)
  if empty(pat_hsl) || empty(lColor)
    return ['', []]
  endif

  let pat_hsl = substitute(pat_hsl, a:pat_search, a:pat_replace, '')

  " SKIP MIXING WHEN BGCOLOR UNSPECIFIED
  if empty(a:rgb_bg)
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
  let lColor = s:IntAlphaMix(lColor, a:rgb_bg)

  " UPDATE HIGHLIGHT PATTERN
  " escape decimal point, then escape all slashes in the suffix
  let hsl_suff = escape(escape(alpha_suff, '.'), '\')
  " replace alpha suffix into pattern
  let pat_hsl = substitute(pat_hsl, '\\)', ',\\s*' . hsl_suff . '\\s*\\)','')

  return [pat_hsl, lColor]

endfunction


" PLUGIN IS EFFECTIVELY OFF FOR THE CURRENT WINDOW
" WHEN `w:clrzr_matches` IS NOT A DICT
function! s:IsEnabledInWindow()
  return exists('w:clrzr_matches') && (type(w:clrzr_matches) == v:t_dict)
endfunction


" BUILDS HIGHLIGHTS (COLORS+PATTERNS) FOR THE CURRENT BUFFER
" FROM l_first TO l_last
function! s:PreviewColorInLine(l_first, l_last) "{{{1

  if !s:IsEnabledInWindow() | return | endif

  " SKIP PROCESSING HELPFILES (usually large)
  if getbufvar('%', '&syntax') ==? 'help' | return | endif

  let l_range = sort([
        \ (type(a:l_first) == v:t_string) ? line(a:l_first) : a:l_first,
        \ (type(a:l_last) == v:t_string) ? line(a:l_last) : a:l_last,
        \ ])

  " ONLY PARSE UP TO g:clrzr_maxlines
  if g:clrzr_maxlines > 0
    if l_range[0] > g:clrzr_maxlines | return | endif
    if l_range[1] > g:clrzr_maxlines | let l_range[1] = g:clrzr_maxlines | endif
  endif

  " GET LINES FROM CURRENT BUFFER
  let lines = getline(l_range[0], l_range[1])
  if empty(lines) | return | endif

  " CACHE CURRENT BACKGROUND COLOR FOR ALPHA BLENDING
  let s:rgb_bg = s:RgbBgColor()

  " WRITE LINES TO AWK CHANNEL
  if exists('w:clrzr_awk_chan')
    let sts = ch_status(w:clrzr_awk_chan)
    if sts == 'open'
      call s:Debug(['WRITE LINES', len(lines), 'WIN', win_getid(), w:clrzr_awk_chan])
      for line in lines
        call ch_sendraw(w:clrzr_awk_chan, line . "\n")
      endfor
    else
      echomsg "AWK CHANNEL STATUS = " . sts
    endif
  else
    echomsg "AWK CHANNEL NOT SET!"
  endif

endfunction


" EXTRACTS COLOR DATA FROM MATCHES & CREATES HIGHLIGHT GROUPS
function! s:ProcessMatch(match)

  if !s:IsEnabledInWindow() | return | endif

  " EXTRACT COLOR INFORMATION FROM SYNTAX
  " RETURNS [syntax_pattern, rgb_color_list]
  let pat = ''
  let rgb_color = []
  if a:match[0] == '#' || a:match[0] == '0'
    let [pat, rgb_color] = s:HexCode(a:match, s:rgb_bg)
  elseif a:match[0:3] ==? 'rgba'
    let [pat, rgb_color] = s:AlphaColor(function('s:RgbColor'), 'rgb', 'rgba', a:match, s:rgb_bg)
  elseif a:match[0:3] ==? 'hsla'
    let [pat, rgb_color] = s:AlphaColor(function('s:HslColor'), 'hsl', 'hsla', a:match, s:rgb_bg)
  elseif a:match[0:2] ==? 'rgb'
    let [pat, rgb_color] = s:RgbColor(a:match)
  elseif a:match[0:2] ==? 'hsl'
    let [pat, rgb_color] = s:HslColor(a:match)
  else
    return
  endif

  if empty(pat) || empty(rgb_color)
    return
  endif

  " FOR NEW PATTERNS
  if has_key(w:clrzr_matches, pat) | return | endif

  " NOTE: pattern & color must be tracked independently, since
  "       multiple alpha patterns may map to the same highlight color
  let hex_color = call('printf', ['%02x%02x%02x'] + rgb_color)

  " INSERT HIGHLIGHT
  " NOTE: always do this (even when :hl group exists) to accommodate
  "       :colorscheme changes, since highlight groups are never
  "       truly deleted -- there goes my hlexists() optimization
  let group = 'Clrzr' . hex_color
  let fg = g:clrzr_fgcontrast < 0 ? hex_color : s:FGforBGList(rgb_color)
  exec join(['hi', group, 'guifg=#'.fg, 'guibg=#'.hex_color], ' ')

  " INSERT MATCH PATTERN FOR HIGHLIGHT
  let w:clrzr_matches[pat] = matchadd(group, '\v\c' . pat)

endfunction


function s:ForeachWindow(Func)

  let lInf = getwininfo()
  for inf in lInf
    call win_execute(inf.winid, 'call a:Func()')
  endfor

  " let save_tab = tabpagenr()
  " let save_win = winnr()
  " tabdo windo call a:Func()
  " execute 'tabn ' . save_tab
  " execute save_win . 'wincmd w'

endfunction


" CLEAR HIGHLIGHTS IN CURRENT WINDOW
function! s:ClearWindow() "{{{1

  if !s:IsEnabledInWindow() | return | endif

  " DELETE MATCHES
  for i in values(w:clrzr_matches)
    try
      call matchdelete(i)
    catch /.*/
      " matches have been cleared in other ways, e.g. user has called clearmatches()
    endtry
  endfor

  let w:clrzr_matches = {}

endfunction


function! s:AwkErr(chan, msg)
  " TODO: disable window w/ error
  echomsg ['ERR', a:msg, 'WIN', win_getid()]
endfunction

function! s:AwkExit(job_id, exit)
  " TODO: disable window w/ error
  call s:Debug(['EXIT', a:job_id, a:exit, 'WIN', win_getid()])
endfunction


function! s:AwkOut(chan, msg)
  " SEND a:msg TO COLOR MATCHER FOR THE CORRECT WINDOW
  let win_id = g:clrzr_chanid2winid[a:chan]
  call win_execute(win_id, 'call s:ProcessMatch(a:msg)')
  return
endfunction


const s:CLRZR_AWK_SCRIPT_PATH = expand('<sfile>:p:h') . '/clrzr.awk'
let g:clrzr_chanid2winid = {}
function! s:EnableWindow()

  if s:IsEnabledInWindow() | return | endif

  call s:Debug(['ENABLE', win_getid()])

  "let awk_cmd = join(['/usr/bin/awk', '-f', s:CLRZR_AWK_SCRIPT_PATH], ' ')
  "let w:clrzr_awk_job = job_start(['/bin/sh', '-c', awk_cmd, '|', 'sort', '|', 'uniq'], {

  let w:clrzr_awk_job = job_start(['awk', '-f', s:CLRZR_AWK_SCRIPT_PATH], {
        \ 'in_mode': 'nl',
        \ 'out_mode': 'nl',
        \ 'err_mode': 'nl',
        \ 'err_cb': function('s:AwkErr'),
        \ 'exit_cb': function('s:AwkExit'),
        \ 'out_cb': function('s:AwkOut'),
        \ 'noblock': 0,
        \ 'drop': 'auto',
        \ 'stoponexit': 'term',
        \ 'pty': 0,
      \ })

  " NOTE: string(chan) == 'channel fail' is error
  let w:clrzr_awk_chan = job_getchannel(w:clrzr_awk_job)
  if string(w:clrzr_awk_chan) == 'channel fail'
    unlet w:clrzr_awk_chan
  endif

  let g:clrzr_chanid2winid[w:clrzr_awk_chan] = win_getid()
  let w:clrzr_matches = {}
  call clrzr#ColorHighlight(0)

endfunction


function! s:DisableWindow()

  call s:ClearWindow()

  " END JOB, REMOVE chan2winid MAPPING
  if exists('w:clrzr_awk_job')
    call remove(g:clrzr_chanid2winid, w:clrzr_awk_chan)
    call job_stop(w:clrzr_awk_job)
  endif

  " REMOVE clrzr_ WINDOW STATE
  for wk in keys(w:)
    if match(wk, '^clrzr_') > -1
      call remove(w:, wk)
    endif
  endfor

endfunction


function! s:ReparseWindow()
  call s:PreviewColorInLine(1, '$')
endfunction


function! clrzr#ColorHighlight(rebuild_all)

  if !s:IsEnabledInWindow() | return | endif

  if a:rebuild_all || (g:clrzr_fgcontrast != s:saved_fgcontrast)
    call s:ForeachWindow(function('s:ClearWindow'))
  endif

  if a:rebuild_all
    call s:ForeachWindow(function('s:ReparseWindow'))
  else
    call s:ReparseWindow()
  endif

  let s:saved_fgcontrast = g:clrzr_fgcontrast

endfunction


function! clrzr#Refresh()
  call s:DisableWindow()
  call s:EnableWindow()
endfunction


" TOGGLES COLOR HIGHLIGHTING IN CURRENT WINDOW
function! clrzr#ToggleWindow()
  if s:IsEnabledInWindow()
    call s:DisableWindow()
  else
    call s:EnableWindow()
  endif
endfunction


" TOGGLES ALPHA COMPONENT POSITION FOR HEX COLORS IN CURRENT WINDOW
function! clrzr#AlphaPosToggleWindow()
  if s:IsAlphaFirst()
    let w:clrzr_hex_alpha_first = 0
  else
    let w:clrzr_hex_alpha_first = 1
  endif
  call s:ClearWindow()
  call clrzr#ColorHighlight(0)
endfunction


function! clrzr#Enable()

  augroup Clrzr

    autocmd!

    " NOTE: for event investigations
    " if 0
    "   autocmd WinNew * call s:SnoopEvent('WinNew')
    "   autocmd WinEnter * call s:SnoopEvent('WinEnter')
    "   autocmd BufReadPost * call s:SnoopEvent('BufReadPost')
    "   autocmd FileReadPost * call s:SnoopEvent('FileReadPost')
    "   autocmd StdinReadPost * call s:SnoopEvent('StdinReadPost')
    "   autocmd FileChangedShellPost * call s:SnoopEvent('FileChangedShellPost')
    "   autocmd ShellFilterPost * call s:SnoopEvent('ShellFilterPost')
    "   autocmd ColorScheme * call s:SnoopEvent('ColorScheme')
    " endif

    " HIGHLIGHTS ARE PER-WINDOW, SO RE-BUILD HIGHLIGHTS,
    " EVEN WITH FILES PREVIOUSLY LOADED IN DIFFERENT WINDOWS
    autocmd WinNew * call s:EnableWindow()

    " RESCAN ON WINDOW SWITCH (case: edit to one buffer in mulitple splits)
    autocmd WinEnter * call clrzr#ColorHighlight(0)

    " REBUILD HIGHLIGHTS AFTER READS
    autocmd BufReadPost,FileReadPost,StdinReadPost,FileChangedShellPost * call clrzr#ColorHighlight(0)

    " NOTE: FilterReadPost isn't triggered when `shelltemp` is off,
    "       but ShellFilterPost is
    autocmd ShellFilterPost * call clrzr#ColorHighlight(0)

    " FORCE-REBUILD HIGHLIGHTS AFTER COLORSCHEME CHANGE
    " (to re-blend alpha colors with new background color)
    " NOTE: refreshes all windows in case bg color changed
    autocmd ColorScheme * call clrzr#ColorHighlight(1)

    " TODO: allowed filetypes list?
    " TODO: sign_column (bigger pls, :h sign-commands)?
    " TODO: matchaddpos() instead of matchadd()?

    autocmd TextChangedI * call s:TextChanged()
    autocmd InsertLeave * call s:InsertLeave()

  augroup END

  call s:ForeachWindow(function('s:EnableWindow'))

endfunction


" UPDATE EDITED LINE RANGE AFTER LEAVING INSERT MODE
function! s:InsertLeave()
  if exists('w:clrzr_min_max') && (type(w:clrzr_min_max) == v:t_list)
    call call('s:PreviewColorInLine', w:clrzr_min_max)
    unlet w:clrzr_min_max
  endif
endfunction


" TRACK RANGE OF EDITED LINES IN INSERT MODE
" FOR DELAYED UPDATE
function! s:TextChanged()
  let pos = line('.')
  if !exists('w:clrzr_min_max') || (type(w:clrzr_min_max) != v:t_list)
    let w:clrzr_min_max = [pos,pos]
  endif
  if pos < w:clrzr_min_max[0]
    let w:clrzr_min_max[0] = pos
  elseif pos > w:clrzr_min_max[1]
    let w:clrzr_min_max[1] = pos
  endif
endfunction


" REMOVE AUTOGROUP & CLEAR HIGHLIGHTS ACROSS ALL WINDOWS
function! clrzr#Disable()
  augroup Clrzr
    au!
  augroup END
  augroup! Clrzr
  call s:ForeachWindow(function('s:DisableWindow'))
endfunction


" ---------------------------  SETUP  ---------------------------

let s:predefined_fgcolors = {
  \ 'dark':  ['#444444', '#222222', '#000000'],
  \ 'light': ['#bbbbbb', '#dddddd', '#ffffff'],
\}

if !exists("g:clrzr_fgcontrast")

  " Default to black / white
  let g:clrzr_fgcontrast = len(s:predefined_fgcolors['dark']) - 1

elseif g:clrzr_fgcontrast >= len(s:predefined_fgcolors['dark'])

  echohl WarningMsg
  echo "g:clrzr_fgcontrast value invalid, using default"
  echohl None
  let g:clrzr_fgcontrast = len(s:predefined_fgcolors['dark']) - 1

endif

let s:saved_fgcontrast = g:clrzr_fgcontrast

" Restoration and modelines
let &cpo = s:keepcpo
unlet s:keepcpo

" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:et
