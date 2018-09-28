" Use vim mode instead of vi mode. Must be first line.
set nocompatible

filetype off " enable file type detection
filetype plugin indent on    " required

" Display settings
set encoding=utf-8 " encoding used for displaying file
set ruler " show the cursor position all the time
set showmatch " highlight matching braces
set showmode " show insert/replace/visual mode

set noerrorbells
set novisualbell

" Write settings
set fileencoding=utf-8 " encoding used when saving file
set nobackup " do not keep the backup~ file
set noswapfile

" Edit settings
set backspace=indent,eol,start " backspacing over everything in insert mode
set expandtab " fill tabs with spaces
set nojoinspaces " no extra space after '.' when joining lines
set shiftwidth=2 " set indentation depth to 2 columns
set softtabstop=2 " backspacing over 2 spaces like over tabs
set tabstop=2 " set tabulator length to 2 columns
set textwidth=80 " wrap lines automatically at 80th column
set number " adds line numbers

" file type specific settings
filetype plugin on " load the plugins for specific file types
filetype indent on " automatically indent code

set modeline
set modelines=1

" Syntax highlighting and that jazz
syntax enable " Actually enable the syntax highlighting

