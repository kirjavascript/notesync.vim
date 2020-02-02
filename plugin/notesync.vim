let s:endpoint = get(g:, 'notesURL', 'http://localhost') . ':4096'
let s:path = expand('<sfile>:p:h') . '/notes/'
let s:password = ''
let s:helpLines = 3

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
    call mkdir(s:path, 'p')
    call s:GetBuffer('.notes')
    call s:DrawListing('o:open a:add d:diff D:delete')
    for note in readdir(s:path)
        put = note
    endfor
    call s:LockBuffer()

    noremap <buffer> <silent> o :call notesync#Open()<cr>
    noremap <buffer> <silent> a :call notesync#Add()<cr>
    noremap <buffer> <silent> d :call notesync#ListDiff()<cr>
    noremap <buffer> <silent> D :call notesync#Delete()<cr>
endfunction

function! notesync#ListDiff()
    let l:newlist = s:Post('/list', join(readdir(s:path), '/'))
    call s:GetBuffer('.notes.diff')
    call s:DrawListing('d:local')
    put = l:newlist
    call s:LockBuffer()

    noremap <buffer> <silent> d :call notesync#List()<cr>

    " open should open & merge
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

function! notesync#View(path)
    let l:name = expand('%')
    let l:diff = s:Post(a:path . l:name, readfile(s:path . l:name))
    keepjumps normal! gg"_dG
    put = l:diff
    keepjumps normal! gg"_dd
endfunction

function! notesync#Push()
    if confirm('push local changes remotely? ' . l:name, "&Ok\n&Cancel") == 1
        call notesync#Save()
        let l:name = expand('%')
        call s:Post('/nw/' . l:name, readfile(s:path . l:name))
        echo 'pushed ' . l:name
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
