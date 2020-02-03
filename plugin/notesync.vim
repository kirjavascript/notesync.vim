let s:endpoint = get(g:, 'notesURL', 'http://kirjava.xyz') . ':4096'
let s:path = expand('<sfile>:p:h') . '/notes/'
let s:keypath = expand('<sfile>:p:h') . '/.key'
let s:helpLines = 3

function! s:Curl()
    if filereadable(s:keypath)
        let l:creds = shellescape('vim:' . join(readfile(s:keypath), ''))
        return 'curl --user ' . l:creds . ' '
    else
        echoerr 'secret key missing'
        return 'curl '
    endif
endfunction

function! s:Fetch(url)
    let l:url = s:endpoint . a:url
    return system(s:Curl() . '--silent ' . l:url)
endfunction

function! s:Post(url, body)
    let l:url = s:endpoint . a:url
    let l:exec = s:Curl() . '-H "Content-Type: text/plain" -s --data-binary @- ' . l:url
    return system(l:exec, a:body)
endfunction

function! s:GetBuffer(name)
    let l:name = expand('%')
    if l:name != a:name
        silent execute 'edit ' . a:name
    endif
    setlocal noswapfile
    setlocal nowrap
    setlocal filetype=notesync
    setlocal modifiable
    keepjumps normal! gg"_dG
endfunction

function! s:DrawListing(help)
    setlocal modifiable
    keepjumps normal! gg"_dG
    put = '📝 notes - ' . s:endpoint
    put = ' ' . a:help . ' '
    put = repeat('-', len(a:help) + 2)

    syntax match Include /📝/
    syntax match Comment /\%3l-/
    syntax match Constant /\%1l.*/
    syntax match Type /\%2l\(\S\):/
    syntax match Error /\- .*/
    syntax match String /+ .*/

    keepjumps normal! gg"_ddG
endfunction

function! s:LockBuffer()
    keepjumps normal! gg
    let &modified = 0
    setlocal nomodifiable
    setlocal buftype=nofile
endfunction

function! notesync#List()
    if !filereadable(s:path)
        call mkdir(s:path, 'p')
    endif
    call s:GetBuffer('.notes')
    call s:DrawListing('o:open a:add d:diff D:delete h:help')
    for note in readdir(s:path)
        put = note
    endfor
    call s:LockBuffer()

    noremap <buffer> <silent> o :call notesync#Open()<cr>
    noremap <buffer> <silent> a :call notesync#Add()<cr>
    noremap <buffer> <silent> d :call notesync#ListDiff()<cr>
    noremap <buffer> <silent> D :call notesync#Delete()<cr>
    noremap <buffer> <silent> h :call notesync#Help()<cr>
endfunction

function! notesync#ListDiff()
    let l:newlist = s:Post('/list', join(readdir(s:path), '/'))
    call s:GetBuffer('.notes.diff')
    call s:DrawListing('o:open c:clone d:local p:push D:delete h:help')
    put = l:newlist
    call s:LockBuffer()

    noremap <buffer> <silent> o :call notesync#Open()<cr>
    noremap <buffer> <silent> c :call notesync#Clone()<cr>
    noremap <buffer> <silent> d :call notesync#List()<cr>
    noremap <buffer> <silent> p :call notesync#PushLocal()<cr>
    noremap <buffer> <silent> D :call notesync#DeleteRemote()<cr>
    noremap <buffer> <silent> h :call notesync#Help()<cr>
endfunction

function! notesync#Help()
    call mkdir(s:path, 'p')
    call s:GetBuffer('.notes.help')
    call s:DrawListing('d:local')
    put = 'specify a URL with let g:notesURL = ' . shellescape('https://something.cool')
    put = ''
    put = 'put your secret key in  ' . s:path . '.key'
    put = ''
    put = 'you can only remotely delete something you already have locally'
    put = ''
    put = 'mapped commands in notes'
    put = ''
    put = '<leader>ns view a remote diff'
    put = '<leader>nd view force merge'
    put = '<leader>nf view added lines'
    put = '<leader>ng view removed lines'
    put = '<leader>nh view remote file'
    put = '<leader>nw push changes to remote'
    syntax match Function /<\(.*\)>/
    call s:LockBuffer()
endfunction

function! notesync#PushLocal()
    let l:name = getline('.')
    if line('.') > s:helpLines && l:name[0] == '-'
        set modifiable
        keepjumps normal! "_x"_x
        call notesync#Open()
        call notesync#Push()
    endif
endfunction


function! notesync#DeleteRemote()
    let l:name = getline('.')
    let l:normal = l:name[0] != '+' && l:name[0] != '-'
    if line('.') > s:helpLines && l:normal && confirm('delete remote copy of ' . l:name . '?', "&Ok\n&Cancel") == 1
        call s:Fetch('/d/' . s:UrlConv(l:name))
        call notesync#ListDiff()
    endif
endfunction

function! notesync#Clone()
    let l:name = getline('.')
    if line('.') > s:helpLines && l:name[0] == '+'
        let l:name = l:name[2:]
        call writefile(split(s:Fetch('/n/' . s:UrlConv(l:name)), '\n'), s:path . l:name)
        call notesync#ListDiff()
    endif
endfunction

function! notesync#Open()
    let l:name = getline('.')
    let l:normal = l:name[0] != '+' && l:name[0] != '-'
    if line('.') > s:helpLines && l:normal
        call s:GetBuffer('.notes/' . l:name)
        put = readfile(s:path . l:name)
        keepjumps normal! gg"_dd
        let &modified = 0
        setlocal fileformat=unix
        setlocal buftype=acwrite

        syntax match Error /\- .*/
        syntax match String /+ .*/

        noremap <buffer> <silent> <leader>ns :call notesync#View('/ns/')<cr>
        noremap <buffer> <silent> <leader>nd :call notesync#View('/nd/')<cr>
        noremap <buffer> <silent> <leader>nf :call notesync#View('/nf/')<cr>
        noremap <buffer> <silent> <leader>ng :call notesync#View('/ng/')<cr>
        noremap <buffer> <silent> <leader>nh :call notesync#View('/nh/')<cr>
        noremap <buffer> <silent> <leader>nw :call notesync#Push()<cr>
        augroup Open
            autocmd!
            autocmd! BufWriteCmd <buffer> call notesync#Save()
        augroup END
    endif
endfunction

function s:GetNoteName()
    return substitute(expand('%'), '^.notes/', '', '')
endfunction

function! notesync#View(path)
    let l:name = s:GetNoteName()
    let l:diff = s:Post(a:path . s:UrlConv(l:name), readfile(s:path . l:name))
    keepjumps normal! gg"_dG
    put = l:diff
    keepjumps normal! gg"_dd
endfunction

function! notesync#Push()
    if confirm('push local changes remotely? ', "&Ok\n&Cancel") == 1
        call notesync#Save()
        let l:name = s:GetNoteName()
        call s:Post('/nw/' . s:UrlConv(l:name), readfile(s:path . l:name))
        echo 'pushed ' . l:name
    endif
endfunction

function! notesync#Save()
    let l:name = s:GetNoteName()
    call writefile(getline(1, '$'), s:path . l:name)
    let &modified = 0
endfunction

function! notesync#Delete()
    let l:name = getline('.')
    if line('.') > s:helpLines && confirm('are you sure you want to delete ' . l:name, "&Ok\n&Cancel") == 1
        call delete(s:path . l:name)
        setlocal modifiable
        keepjumps normal! "_dd
        setlocal nomodifiable
    endif
endfunction

function! notesync#Add()
    let l:name = substitute(input('name: '), '[^a-zA-Z0-9 ]*', '', 'g')
    normal! :<ESC>
    if index(readdir(s:path), l:name) > -1
        echo 'note already exists'
    else
        if line('.') < s:helpLines
            normal! jjj
        endif
        setlocal modifiable
        put = l:name
        setlocal nomodifiable
        call writefile([], s:path . l:name)
        call notesync#Open()
    endif
endfunction

function! s:UrlConv(string)
    return substitute(a:string, ' ', '+', 'g')
endfunction

command! NSync call notesync#List()
