" clrzr.vim	Colorize all text in the form #rrggbb or #rgb; entrance
" Licence:	Vim license. See ':help license'
" Maintainer:   Jason Stewart <support@eggplantsd.com>
" Derived From:	https://github.com/lilydjwg/colorizer
"               lilydjwg <lilydjwg@gmail.com>
" Derived From: css_color.vim
" 		http://www.vim.org/scripts/script.php?script_id=2150
" Thanks To:	Niklas Hofer (Author of css_color.vim), Ingo Karkat, rykka,
"		KrzysztofUrban, blueyed, shanesmith, UncleBill
" Usage:
"

" Reload guard and 'compatible' handling {{{1
if exists("loaded_clrzr") || v:version < 700 || !(has('termguicolors') && &termguicolors)
  finish
endif
let loaded_clrzr = 1

let s:save_cpo = &cpo
set cpo&vim

"Define commands {{{1
if !exists('g:clrzr_maxlines')
  let g:clrzr_maxlines = -1
endif

command! ClrzrOn      call clrzr#Enable()
command! ClrzrOff     call clrzr#Disable()
command! ClrzrAposTog call clrzr#AlphaPosToggleWindow()
command! ClrzrRefresh call clrzr#Refresh()
command! ClrzrTog     call clrzr#ToggleWindow()

if !exists('g:clrzr_startup') || g:clrzr_startup
  call clrzr#Enable()
endif

" Cleanup and modelines {{{1
let &cpo = s:save_cpo
" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:
