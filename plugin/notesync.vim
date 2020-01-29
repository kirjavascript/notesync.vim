" let s:endpoint = get(g:, 'notesyncURL', 'http://nibblr.pw')
let s:endpoint = get(g:, 'notesURL', 'http://localhost:4096')
let s:password = ''
let s:help="notesync command editor - " . s:endpoint ."
         \\n o:open a:add D:delete l:lock s:star S:sudo
         \\n--------------------------------------------"
let s:helpLines = 3
let s:list = []

function! notesync#List()
    let l:list = s:GetJSON('command/list')
    if type(l:list) != v:t_list
        echom 'notesync: no listing returned from ' . s:endpoint
        return
    endif
    let s:list = l:list

    enew
    put=s:help
    keepjumps normal! gg"_ddG

    for command in s:list
        put = s:RenderLine(command)
    endfor
    keepjumps normal! gg

    let &modified = 0
    setlocal buftype=nofile
    setlocal noswapfile
    setlocal nowrap
    setlocal nomodifiable

    set filetype=notesync
    syntax match Type /★/
    syntax match Include /🔒/
    syntax match Operator /^\(\S*\)/
    syntax match Comment /\%3l-/
    syntax match String /\%1lnibblr/
    syntax match Constant /\%1ljr/
    syntax match Type /\%2l\(\S\):/

    noremap <buffer> <silent> o :call notesync#Get()<cr>
    noremap <buffer> <silent> S :call notesync#Sudo()<cr>
    noremap <buffer> <silent> D :call notesync#Delete()<cr>
    noremap <buffer> <silent> l :call notesync#Lock()<cr>
    noremap <buffer> <silent> s :call notesync#Star()<cr>
    noremap <buffer> <silent> a :call notesync#Add()<cr>
endfunction

function! notesync#Get()
    if line('.') > s:helpLines
        let l:name = s:GetCommandName()

        if bufwinnr(l:name) > 0
            enew
            silent execute 'file ' . l:name
        else
            silent execute 'edit ' . l:name
            keepjumps normal! gg"_dG
        endif

        let s:res = s:GetJSON('command/get/' . s:UrlEncode(l:name))

        if has_key(s:res, 'error')
            echo 'notesync: ' . s:res.error
        else
            put = s:res.command
            %s///e
            keepjumps normal! gg"_dd
            let &modified = 0
            setlocal filetype=javascript
            setlocal fileformat=unix
            setlocal buftype=acwrite
            setlocal noswapfile
            autocmd! BufWriteCmd <buffer> call notesync#Set()
        endif
    endif
endfunction

function! notesync#Set()
    let l:name = expand('%')
    let l:buf = join(getline(1, '$'), "\n")
    let l:obj = { 'command': l:buf }
    let s:res = s:PostJSON('command/set/' . s:UrlEncode(l:name), l:obj)
    if has_key(s:res, 'error')
        echo 'notesync: ' . s:res.error
    else
        let &modified = 0
    endif
endfunction

function! notesync#Delete()
    let l:name = s:GetCommandName()
    if line('.') > s:helpLines && confirm('are you sure you want to delete ' . l:name, "&Ok\n&Cancel") == 1

        let s:res = s:PostJSON('command/delete/' . s:UrlEncode(l:name), {})
        if has_key(s:res, 'error')
            echo 'notesync: ' . s:res.error
        else
            setlocal modifiable
            normal! "_dd
            setlocal nomodifiable
        endif
    endif
endfunction

function! notesync#Add()
    if line('.') < s:helpLines
        normal! jjj
    endif
    let l:name = input('new command name: ')
    " hack to clear the input prompt
    normal! :<ESC>
    let s:res = s:PostJSON('command/new/' . s:UrlEncode(l:name), {})
    if has_key(s:res, 'error')
        echo 'notesync: ' . s:res.error
    else
        setlocal modifiable
        put = s:RenderLine({ 'name' : l:name})
        setlocal nomodifiable
        call notesync#Get()
    endif
endfunction

function! notesync#Lock()
    call s:ToggleSetting('locked')
endfunction

function! notesync#Star()
    call s:ToggleSetting('starred')
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

function! s:ToggleSetting(setting)
    if line('.') > s:helpLines
        let l:name = s:GetCommandName()
        for command in s:list
            if command.name == l:name
                let l:config = { a:setting : s:Flip(command[a:setting]) }
                let s:res = s:PostJSON('command/set-config/' . s:UrlEncode(l:name), l:config)
                if has_key(s:res, 'error')
                    echo 'notesync: ' . s:res.error
                else
                    let command[a:setting] = s:Flip(command[a:setting])
                    setlocal modifiable
                    put = s:RenderLine(command)
                    normal! kdd
                    setlocal nomodifiable
                endif
                break
            endif
        endfor
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

function! s:GetCommandName()
    let l:name = getline('.')
    " strip everything after the first space
    return substitute(l:name, " .*", "", "")
endfunction

function! s:Curl()
    if len(s:password)
        let l:creds = shellescape('vim:' . s:password)
        return 'curl --user ' . l:creds . ' '
    else
        return 'curl '
    endif
endfunction

function! s:GetJSON(url)
    let l:url = s:endpoint . '/api/' . a:url
    return json_decode(system(s:Curl() . '--silent ' . l:url))
endfunction

function! s:PostJSON(url, obj)
    let l:url = s:endpoint . '/api/' . a:url
    let l:exec = s:Curl() . '-H "Content-Type: application/json" -s -d @- ' . l:url
    let json = system(l:exec, json_encode(a:obj))
    return json_decode(json)
endfunction

function s:Flip(var)
    return a:var ? v:false : v:true
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
