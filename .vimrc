" Pairing station VIM configuration

"set t_ts=]0;
"set t_fs=
"set title

set encoding=utf-8 " default encoding for files
set hidden
set nocompatible
set noswapfile  " it's 2012, vim
set modeline    " read mode line
set modelines=10
set vb		" use a visual flash instead of beeping
set ru		" display column, line info
set ai		" always do autoindenting
set sw=4	" indent 4 spaces
set sts=4	" tabstop 4 spaces
set tw=78	" limit text to 78 spaces
syn on		" enable syntax highlighting

" Search options
set gdefault    " :%s/foo/bar should replace in whole file not just current line
set hlsearch	" incremental search highlighting

" Enable bashisms in *.sh scripts.
let g:is_bash=1

"let g:inkpot_black_background=1
"colo inkpot
colo sri                " use sri's colorscheme: https://github.com/tempire/dotvim/blob/master/colors/sri.vim (modified)
                        "
                        " ... except the shitty distracting cyan brace matching
highlight MatchParen cterm=bold ctermfg=cyan ctermbg=black

set ignorecase          " ignore case in search patterns ...
set smartcase           " ... unless pattern contains uppercase
set incsearch           " do incremental searching
set listchars=tab:^.,trail:·
set scrolloff=2         " always leave 2 lines above/below cursor
set ruler               " show line numbers

set wildmenu            " pop menu with completions
set wildmode=list:longest,full

set backspace=indent,eol,start

if has("autocmd")
  filetype plugin indent on

  " Turn off line wrap for common files
  au BufNewFile,BufRead db.*	setlocal nowrap
  au BufNewFile,BufRead /etc/*	setlocal nowrap

  au BufNewFile,BufRead,StdinReadPost *
    \ let s:l1 = getline(1) |
    \ if s:l1 =~ '^Return-Path: ' |
    \   setf mail |
    \ endif

  au BufReadPost *
    \ if line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  au BufRead,BufNewFile *.go      set filetype=go

  au FileType eruby               setl sw=2 sts=2 expandtab list tw=0 nowrap
  au FileType html                setl sw=2 sts=2 expandtab list tw=0 nowrap
  au FileType scss,css            setl sw=2 sts=2 expandtab list tw=0
  au FileType ruby                setl sw=2 sts=2 expandtab list
  au FileType javascript          setl sw=2 sts=2 expandtab list
endif

"
" Keyboard shortcuts
"

" Move up and down by screen lines not file lines
nnoremap j gj
nnoremap k gk

" If you hit F1 accidentally, this should be the same as escape!
inoremap <f1> <esc>
nnoremap <f1> <esc>
vnoremap <f1> <esc>

" start leader commands with comma instead of the default backslash
let mapleader = ","

" Strip all trailing while space by pressing ,w
nnoremap <leader>w :%s/\s\+$//<cr>:let @/=''<CR>

" Fold HTML tags using ,ft
nnoremap <leader>ft Vatzf
" Fold paragraphs using ,fp
nnoremap <leader>fp Vapzf

" Split window and move to new pane using ,v
nnoremap <leader>v <C-w>v<C-w>l<cr>
" Horizontal split using ,s
nnoremap <leader>s <C-w>s<C-w>j<cr>

" Clear annoying search highlighting with ', '
map <leader><space> :noh<cr>

" Center the current diff hunk when navigating diffs
nmap ]c ]czz
nmap [c [czz

" :W should save as well
command W w
command Wq wq
command WQ wq
command Q q

"
" Bundle options
"

" Initialise pathogen to allow loading plugins from ~/.vim/bundle
execute pathogen#infect()

" vim-slime options
let g:slime_target = "tmux"

" Rainbow parentheses!
let g:rbpt_colorpairs = [
    \ ['magenta',     'purple1'],
    \ ['cyan',        'magenta1'],
    \ ['green',       'slateblue1'],
    \ ['yellow',      'cyan1'],
    \ ['red',         'springgreen1'],
    \ ['magenta',     'green1'],
    \ ['cyan',        'greenyellow'],
    \ ['green',       'yellow1'],
    \ ['yellow',      'orange1'],
    \ ]
let g:rbpt_max = 9

"au VimEnter * RainbowParenthesesToggle
au BufEnter * RainbowParenthesesToggle
au BufLeave * RainbowParenthesesToggle
au Syntax * RainbowParenthesesLoadRound
au Syntax * RainbowParenthesesLoadSquare
au Syntax * RainbowParenthesesLoadBraces

if filereadable($HOME . "/.vimrc_custom")
  source $HOME/.vimrc_custom
endif
