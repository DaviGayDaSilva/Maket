#!/data/data/com.termux/files/usr/bin/bash
#
# maket completion - Bash completion for maket
#

_maket_completion() {
    local cur prev words cword
    _init_completion || return
    
    local commands="run list mount umount status install-deps cleanup"
    local iso_dir="${HOME}/.maket/isomnt"
    
    case "${cword}" in
        1)
            COMPREPLY=($(compgen -W "${commands}" -- "${cur}"))
            return
            ;;
        2)
            case "${prev}" in
                run)
                    # Complete with ISO files or rootfs directories
                    local isos roots
                    isos=$(find "${HOME}/storage/shared" "${HOME}/storage/downloads" "/sdcard/Download" \
                        -maxdepth 2 -name "*.iso" -type f 2>/dev/null | sed 's|.*/||')
                    roots=$(find "${HOME}/storage/shared" "${HOME}/storage/downloads" "/sdcard/Download" \
                        -maxdepth 2 -type d -name "*rootfs*" 2>/dev/null | sed 's|.*/||')
                    COMPREPLY=($(compgen -W "${isos} ${roots}" -- "${cur}"))
                    return
                    ;;
                umount)
                    # Complete with mounted ISOs
                    local mounted
                    mounted=$(ls -1 "${iso_dir}" 2>/dev/null)
                    COMPREPLY=($(compgen -W "${mounted}" -- "${cur}"))
                    return
                    ;;
            esac
            ;;
        3)
            case "${words[2]}" in
                run)
                    if [[ "${words[1]}" == "--iso" ]]; then
                        local isos
                        isos=$(find "${HOME}/storage/shared" "${HOME}/storage/downloads" "/sdcard/Download" \
                            -maxdepth 2 -name "*.iso" -type f 2>/dev/null | sed 's|.*/||')
                        COMPREPLY=($(compgen -W "${isos}" -- "${cur}"))
                    elif [[ "${words[1]}" == "--rootfs" ]]; then
                        local roots
                        roots=$(find "${HOME}/storage/shared" "${HOME}/storage/downloads" "/sdcard/Download" \
                            -maxdepth 2 -type d 2>/dev/null | sed 's|.*/||')
                        COMPREPLY=($(compgen -W "${roots}" -- "${cur}"))
                    fi
                    return
                    ;;
            esac
            ;;
    esac
    
    # Options completion
    if [[ "${cur}" == -* ]]; then
        local options="-h --help -v --version -d --display -m --memory -c --cpu --no-vnc --vnc-passwd --iso --rootfs"
        COMPREPLY=($(compgen -W "${options}" -- "${cur}"))
        return
    fi
}

complete -F _maket_completion maket