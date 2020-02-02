let s:endpoint = get(g:, 'notesURL', 'http://localhost:4096')
let s:path = expand('<sfile>:p:h') . '/notes/'
let s:password = ''
let s:help="📝 notes - " . s:endpoint ."
         \\n o:open a:add d:diff D:delete
         \\n------------------------------"
let s:helpLines = 3
let s:list = []

function! s:Curl()
    if len(s:password)
        let l:creds = shellescape('vim:' . s:password)
        return 'curl --user ' . l:creds . ' '
    else
        return 'curl '
    endif
endfunction

function! s:Fetch(url)
    let l:url = s:endpoint . a:url
    return system(s:Curl() . '--silent ' . l:url)
endfunction

function! s:Post(url, body)
    let l:url = s:endpoint . a:url
    let l:exec = s:Curl() . '-H "Content-Type: application/json" -s -d @- ' . l:url
    return system(l:exec, a:body)
endfunction

function! s:GetBuffer(name)
    let l:name = expand('%')
    if l:name != a:name
        " if bufwinnr(a:name) > 0
        "     enew
        "     silent execute 'file ' . a:name
        " else
            silent execute 'edit ' . a:name
        " endif
    endif
    setlocal noswapfile
    setlocal nowrap
    setlocal filetype=notesync
    setlocal modifiable
    keepjumps normal! gg"_dG
endfunction

function! s:DrawList()
    setlocal modifiable
    keepjumps normal! gg"_dG
    put = s:help
    keepjumps normal! gg"_ddG
    for note in readdir(s:path)
        put = note
    endfor
    keepjumps normal! gg
    let &modified = 0
    setlocal nomodifiable
endfunction

function! notesync#List()
    call mkdir(s:path, 'p')
    call s:GetBuffer('.notes')
    call s:DrawList()
    setlocal buftype=nofile

    syntax match Include /📝/
    syntax match Constant /^\(\S*\)/
    syntax match Comment /\%3l-/
    syntax match String /\%1l.*/
    syntax match Type /\%2l\(\S\):/

    noremap <buffer> <silent> o :call notesync#Open()<cr>
    noremap <buffer> <silent> a :call notesync#Add()<cr>
    " noremap <buffer> <silent> d :call notesync#ListDiff()<cr>
    noremap <buffer> <silent> D :call notesync#Delete()<cr>

    augroup List
        autocmd!
        autocmd FocusGained <buffer> call s:DrawList()
    augroup END
endfunction

function! notesync#Open()
    if line('.') > s:helpLines
        let l:name = getline('.')
        call s:GetBuffer(l:name)
        put = readfile(s:path . l:name)
        keepjumps normal! gg"_dd
        let &modified = 0
        setlocal fileformat=unix
        setlocal buftype=acwrite
        augroup Open
            autocmd!
            autocmd! BufWriteCmd <buffer> call notesync#Save()
        augroup END
    endif
endfunction

function! notesync#Save()
    let l:name = expand('%')
    call writefile(getline(1, '$'), s:path . l:name)
    let &modified = 0
endfunction

function! notesync#Delete()
    let l:name = getline('.')
    if line('.') > s:helpLines && confirm('are you sure you want to delete ' . l:name, "&Ok\n&Cancel") == 1
        call delete(s:path . l:name)
        call notesync#List()
    endif
endfunction

function! notesync#Add()
    let l:name = input('name: ')
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


function! notesync#Sudo()
    let l:password = inputsecret('password: ')
    normal! :<ESC>
    if len(l:password) && l:password != s:password
        echo 'notesync: password changed'
        let s:password = l:password
    else
        echo 'notesync: password not changed'
    endif
endfunction


function! s:RenderLine(command)
    let l:line = a:command.name . repeat(' ', 44 - len(a:command.name))
    if has_key(a:command, 'starred') && a:command.starred
        let l:line .= '★'
    else
        let l:line .= ' '
    endif
    if has_key(a:command, 'locked') && a:command.locked
        let l:line .= ' 🔒'
    endif
    return l:line
endfunction

function! s:UrlEncode(string)
    let l:result = ""

    let l:characters = split(a:string, '.\zs')
    for l:character in l:characters
        let l:ascii_code = char2nr(l:character)
        if l:character == " "
            let l:result = l:result . "+"
        elseif (l:ascii_code >= 48 && l:ascii_code <= 57) || (l:ascii_code >= 65 && l:ascii_code <= 90) || (l:ascii_code >= 97 && l:ascii_code <= 122) || (l:character == "-" || l:character == "_" || l:character == "." || l:character == "~")
            let l:result = l:result . l:character
        else
            let i = 0
            while i < strlen(l:character)
                let byte = strpart(l:character, i, 1)
                let decimal = char2nr(byte)
                let l:result = l:result . "%" . printf("%02x", decimal)
                let i += 1
            endwhile
        endif
    endfor

    return l:result
endfunction

command! NSync call notesync#List()
