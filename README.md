# Colorizer

A Vim plugin to colorize all text in the form #rgb, #rgba, #rrggbb, #rrgbbaa, rgb(...), rgba(...).
See the comment at the beginning of the [plugin](plugin/colorizer.vim) for more options.

### True Color Support

Works in gVim or any terminal with true-color support.  If your terminal is true-color, but
you are not seeing the colors, add the following to your `vimrc` and restart:

```vim

  " sets foreground color (ANSI, true-color mode)
  let &t_8f = "\e[38;2;%lu;%lu;%lum"

  " sets background color (ANSI, true-color mode)
  let &t_8b = "\e[48;2;%lu;%lu;%lum"

  set termguicolors

```

### Screenshots

![screenshot](screenshot.png)

![screenshot](screenshot-2.png)
The left screen shows `colortest.txt` in Vim in xfce4-terminal.
The right screen shows `colortest.txt` in gVim.

### Installation

    cd ~/.vim/pack/plugins/start
    git clone https://github.com/BourgeoisBear/colorizer

### Origin

This version is based on https://github.com/lilydjwg/colorizer, also found as
[colorizer.vim on vim.org](http://www.vim.org/scripts/script.php?script_id=3567)
