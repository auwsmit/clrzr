" colorizer.vim	Colorize all text in the form #rrggbb or #rgb; entrance
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
if exists("loaded_colorizer") || v:version < 700 || !(has('termguicolors') && &termguicolors)
  finish
endif
let loaded_colorizer = 1

let s:save_cpo = &cpo
set cpo&vim

"Define commands {{{1
if !exists('g:colorizer_maxlines')
  let g:colorizer_maxlines = -1
endif

command! -bar -bang ColorHighlight call colorizer#ColorHighlight(1, "<bang>")
command! -bar ColorClear call colorizer#ColorClear()
command! -bar ColorToggle call colorizer#ColorToggle()
command! -bar ColorAlphaPosToggle call colorizer#AlphaPositionToggle()

nnoremap <silent> <Plug>Colorizer :ColorToggle<CR>
if !hasmapto("<Plug>Colorizer") && (!exists("g:colorizer_nomap") || g:colorizer_nomap == 0)
  nmap <unique> <Leader>tc <Plug>Colorizer
endif
if !exists('g:colorizer_startup') || g:colorizer_startup
  call colorizer#ColorHighlight(0)
endif

" Cleanup and modelines {{{1
let &cpo = s:save_cpo
" vim:ft=vim:fdm=marker:fmr={{{,}}}:ts=8:sw=2:sts=2:
