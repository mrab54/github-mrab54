if &term =~ "xterm"
  "256 color --
   let &t_Co=256
   " restore screen after quitting
   set t_ti=ESC7ESC[rESC[?47h t_te=ESC[?47lESC8
   if has("terminfo")
      let &t_Sf="\ESC[3%p1%dm"
      let &t_Sb="\ESC[4%p1%dm"
   else
      let &t_Sf="\ESC[3%dm"
      let &t_Sb="\ESC[4%dm"
   endif
endif

"colorscheme clarity
"colorscheme zenburn
"colorscheme blue
"colorscheme darkblue
"colorscheme default
"colorscheme delek
"colorscheme desert
colorscheme elflord
sy on

":abbreviate :Abbreviations for all modes
":iabbrev    :Abbreviations for insert mode
":cabbrev    :Abbreviations for the command line only
" Abbreviations
"iabbrev r return
iabbr forx for (x = 0; x < 10; x++)<cr>{<cr><t><cr>}
inoremap jj <Esc>
nnoremap <tab> %
vnoremap <tab> %
nnoremap <leader>w <C-w>s<C-w>l
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

set pastetoggle=<F2>
set number
" map's
":imap for Insert mode only
":cmap for Command-line mode only
":nmap for Normal mode only
":vmap for Visual mode only
map <C-s> <esc>:w<cr>a
"
" The GTK+/Gnome GUI typically has a white or light gray background, while
" people typically configure terminal windows with a dark background
" (often known for historical purposes as 'reverse video').
"if has("gui_running")
"    set background=light " doesn't actually set bg color, but tells vim what
                         " the background color of the terminal or GUI window
                         " is, so vim can pick appropriate colors to display
                         " *on top* of that background
"    set lines=43
"else
"    set background=dark
"endif
" Most of these things are options documented at
" http://vimdoc.sourceforge.net/htmldoc/options.html
set nocompatible  " don't be compatbile with vi (should be set already...)
set backspace=2   " can backspace past insert point, and will move up at
                  " beginning-of-line
set whichwrap=b,s,h,l,<,>,[,] " enable all, lets you arrow left/right and
                              " 'x'/del from line to line when at EOL
set expandtab     " convert tabs to spaces (do CTRL-V Tab if you need real tab)
set shiftwidth=4  " distance to indent by default
set tabstop=4
set softtabstop=4
set smarttab      " Tab at start of line will use shiftwidth instead of 'ts'
set autoindent    " when starting new line, put cursor at indent of prev line
set showmatch     " bounce the cursor between open/close paren, bracket, brace
"set visualbell    " flash the terminal window rather than beep
set ruler         " enable position indication (line/column & file percentage)

set modelines=0

set encoding=utf-8
set scrolloff=3
set showmode
set showcmd
set hidden
set wildmenu
set wildmode=list:longest
set ttyfast
set laststatus=2
"set relativenumber
"set undofile
