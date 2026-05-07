#!/bin/sh

# StorageGraft
# Strict POSIX sh implementation skeleton.
#
# Current commands:
#   storagegraft check
#   storagegraft status [store]
#   storagegraft plan [store]
#
# This version is non-mutating:
#   no migration
#   no bind mounts
#   no cleanup
#   no generated units

PROGRAM=storagegraft
ETC_DIR=${STORAGEGRAFT_ETC:-/etc/storagegraft}
USER_DIR_NAME=.storagegraft

usage() {
    cat <<EOF
Usage:
  storagegraft check
  storagegraft status [store]
  storagegraft plan [store]

Environment:
  STORAGEGRAFT_ETC   Override system configuration root.
                     Default: /etc/storagegraft
EOF
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

trim() {
    printf '%s\n' "$1" | sed 's/^[	 ]*//; s/[	 ]*$//'
}

strip_comment_line() {
    case "$1" in
        ''|'#'*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

conf_value() {
    # Usage:
    #   conf_value FILE KEY DEFAULT
    #
    # Reads simple key=value files.
    # Sections are not interpreted in this POSIX MVP.
    file=$1
    key=$2
    default=$3

    if [ ! -f "$file" ]; then
        printf '%s\n' "$default"
        return 0
    fi

    awk -v want="$key" -v default="$default" '
        BEGIN { found = 0 }
        /^[ \t]*$/ { next }
        /^[ \t]*#/ { next }
        {
            line = $0
            eq = index(line, "=")
            if (eq == 0) next

            k = substr(line, 1, eq - 1)
            v = substr(line, eq + 1)

            gsub(/^[ \t]+/, "", k)
            gsub(/[ \t]+$/, "", k)
            gsub(/^[ \t]+/, "", v)
            gsub(/[ \t]+$/, "", v)

            if (k == want) {
                print v
                found = 1
                exit
            }
        }
        END {
            if (!found) print default
        }
    ' "$file"
}

store_name_from_conf() {
    base=`basename "$1"`
    case "$base" in
        *.conf)
            printf '%s\n' "${base%".conf"}"
            ;;
        *)
            printf '%s\n' "$base"
            ;;
    esac
}

normalize_slashes() {
    # Collapse repeated slashes.
    # Does not resolve symlinks.
    printf '%s\n' "$1" | sed 's:/\{1,\}:/:g'
}

resolve_entry() {
    # Usage:
    #   resolve_entry BASE ENTRY
    #
    # Relative entries are resolved against BASE.
    # Absolute entries are normalized as-is.
    base=$1
    entry=$2

    case "$entry" in
        /*)
            normalize_slashes "$entry"
            ;;
        .)
            normalize_slashes "$base"
            ;;
        ./*)
            rest=${entry#./}
            normalize_slashes "$base/$rest"
            ;;
        *)
            normalize_slashes "$base/$entry"
            ;;
    esac
}

store_subtree() {
    # Usage:
    #   store_subtree STORE_ROOT ORIGIN_ADDRESS
    #
    # store subtree = store root + origin address
    root=$1
    origin=$2

    origin_no_slash=${origin#/}
    normalize_slashes "$root/$origin_no_slash"
}

is_exact_mountpoint() {
    path=$1

    awk -v p="$path" '
        {
            if ($5 == p) found = 1
        }
        END {
            exit found ? 0 : 1
        }
    ' /proc/self/mountinfo 2>/dev/null
}

mount_source_for() {
    path=$1

    awk -v p="$path" '
        {
            if ($5 == p) {
                for (i = 1; i <= NF; i++) {
                    if ($i == "-") {
                        print $(i + 2)
                        exit
                    }
                }
            }
        }
    ' /proc/self/mountinfo 2>/dev/null
}

mount_fstype_for() {
    path=$1

    awk -v p="$path" '
        {
            if ($5 == p) {
                for (i = 1; i <= NF; i++) {
                    if ($i == "-") {
                        print $(i + 1)
                        exit
                    }
                }
            }
        }
    ' /proc/self/mountinfo 2>/dev/null
}

path_state() {
    path=$1

    if [ ! -e "$path" ]; then
        printf '%s\n' absent
        return 0
    fi

    if [ -L "$path" ]; then
        printf '%s\n' symlink
        return 0
    fi

    if [ ! -d "$path" ]; then
        printf '%s\n' not-directory
        return 0
    fi

    if has_command find; then
        found=`find "$path" -mindepth 1 -maxdepth 1 2>/dev/null | sed -n '1p'`
        if [ -n "$found" ]; then
            printf '%s\n' non-empty
        else
            printf '%s\n' empty
        fi
        return 0
    fi

    for item in "$path"/* "$path"/.[!.]* "$path"/..?*; do
        case "$item" in
            "$path"'/*'|"$path"'/.['*|"$path"'/..?'*)
                ;;
            *)
                if [ -e "$item" ] || [ -L "$item" ]; then
                    printf '%s\n' non-empty
                    return 0
                fi
                ;;
        esac
    done

    printf '%s\n' empty
}

print_store_summary() {
    plane=$1
    owner=$2
    conf=$3

    name=`store_name_from_conf "$conf"`
    root=`conf_value "$conf" root ""`
    activation=`conf_value "$conf" activation external`
    managed=`conf_value "$conf" managed false`
    kind=`conf_value "$conf" kind unknown`
    semantics=`conf_value "$conf" semantics unknown`
    durability=`conf_value "$conf" durability unknown`
    users=`conf_value "$conf" users deny`
    user_scope=`conf_value "$conf" user_scope home-only`

    printf 'STORE %s\n' "$name"
    printf '  plane: %s\n' "$plane"
    printf '  owner: %s\n' "$owner"
    printf '  config: %s\n' "$conf"

    if [ -z "$root" ]; then
        printf '  state: invalid\n'
        printf '  error: missing root\n'
        return 1
    fi

    printf '  root: %s\n' "$root"

    if is_exact_mountpoint "$root"; then
        printf '  state: mounted\n'
        src=`mount_source_for "$root"`
        fstype=`mount_fstype_for "$root"`
        [ -n "$src" ] && printf '  source: %s\n' "$src"
        [ -n "$fstype" ] && printf '  filesystem: %s\n' "$fstype"
    else
        printf '  state: not-mounted\n'
    fi

    printf '  activation: %s\n' "$activation"
    printf '  managed: %s\n' "$managed"
    printf '  kind: %s\n' "$kind"
    printf '  semantics: %s\n' "$semantics"
    printf '  durability: %s\n' "$durability"
    printf '  users: %s\n' "$users"
    printf '  user_scope: %s\n' "$user_scope"

    return 0
}

validate_declared_origin() {
    # Usage:
    #   validate_declared_origin PLANE HOME ORIGIN
    plane=$1
    home=$2
    origin=$3

    case "$origin" in
        /)
            printf '%s\n' invalid-root
            return 0
            ;;
        /dev|/dev/*|/proc|/proc/*|/sys|/sys/*|/run|/run/*)
            printf '%s\n' invalid-pseudo-runtime
            return 0
            ;;
    esac

    if [ "$plane" = user ]; then
        case "$origin" in
            "$home"/*)
                printf '%s\n' ok
                return 0
                ;;
            "$home")
                printf '%s\n' invalid-home-root
                return 0
                ;;
            *)
                printf '%s\n' invalid-outside-home
                return 0
                ;;
        esac
    fi

    printf '%s\n' ok
}

plan_one_origin() {
    plane=$1
    owner=$2
    home=$3
    conf=$4
    origin=$5
    source_file=$6
    line_no=$7

    store=`store_name_from_conf "$conf"`
    root=`conf_value "$conf" root ""`

    printf 'GRAFT %s\n' "$origin"
    printf '  plane: %s\n' "$plane"
    printf '  owner: %s\n' "$owner"
    printf '  declaration: %s:%s\n' "$source_file" "$line_no"
    printf '  store: %s\n' "$store"

    if [ -z "$root" ]; then
        printf '  action: refused\n'
        printf '  policy: invalid-store\n'
        printf '  error: store has no root\n'
        return 0
    fi

    subtree=`store_subtree "$root" "$origin"`

    printf '  store root: %s\n' "$root"
    printf '  store subtree: %s\n' "$subtree"

    validation=`validate_declared_origin "$plane" "$home" "$origin"`
    if [ "$validation" != ok ]; then
        printf '  action: refused\n'
        printf '  policy: %s\n' "$validation"
        return 0
    fi

    if ! is_exact_mountpoint "$root"; then
        printf '  origin state: %s\n' "`path_state "$origin"`"
        printf '  store subtree state: %s\n' "`path_state "$subtree"`"
        printf '  action: wait\n'
        printf '  policy: store-unavailable\n'
        return 0
    fi

    if is_exact_mountpoint "$origin"; then
        printf '  origin state: mount-point\n'
        printf '  store subtree state: %s\n' "`path_state "$subtree"`"
        printf '  action: inspect\n'
        printf '  policy: origin-already-mounted\n'
        return 0
    fi

    origin_state=`path_state "$origin"`
    subtree_state=`path_state "$subtree"`

    printf '  origin state: %s\n' "$origin_state"
    printf '  store subtree state: %s\n' "$subtree_state"

    case "$origin_state:$subtree_state" in
        absent:absent)
            printf '  action: create-and-bind\n'
            printf '  policy: safe\n'
            ;;
        absent:empty|empty:empty)
            printf '  action: bind\n'
            printf '  policy: safe\n'
            ;;
        absent:non-empty|empty:non-empty)
            printf '  action: bind\n'
            printf '  policy: safe\n'
            ;;
        non-empty:absent|non-empty:empty)
            printf '  action: migrate-verify-bind\n'
            printf '  policy: safe\n'
            ;;
        non-empty:non-empty)
            printf '  action: merge-or-conflict-check-required\n'
            printf '  policy: needs-conflict-scan\n'
            ;;
        symlink:*|*:symlink)
            printf '  action: refused\n'
            printf '  policy: symlink-hazard\n'
            ;;
        not-directory:*|*:not-directory)
            printf '  action: refused\n'
            printf '  policy: unsupported-object-type\n'
            ;;
        *)
            printf '  action: refused\n'
            printf '  policy: unknown-state\n'
            ;;
    esac
}

read_paths_for_store() {
    # Usage:
    #   read_paths_for_store PLANE OWNER HOME CONF PATHS_FILE
    plane=$1
    owner=$2
    home=$3
    conf=$4
    paths_file=$5

    if [ ! -f "$paths_file" ]; then
        return 0
    fi

    line_no=0

    while IFS= read -r raw || [ -n "$raw" ]; do
        line_no=`expr "$line_no" + 1`
        line=`trim "$raw"`

        strip_comment_line "$line" || continue

        if [ "$plane" = system ]; then
            base=/
        else
            base=$home
        fi

        origin=`resolve_entry "$base" "$line"`

        plan_one_origin "$plane" "$owner" "$home" "$conf" "$origin" "$paths_file" "$line_no"
        printf '\n'
    done < "$paths_file"
}

system_paths_file_for_conf() {
    conf=$1
    name=`store_name_from_conf "$conf"`
    printf '%s\n' "$ETC_DIR/paths.d/$name.paths"
}

user_paths_file_for_conf() {
    user_root=$1
    conf=$2
    name=`store_name_from_conf "$conf"`
    printf '%s\n' "$user_root/paths.d/$name.paths"
}

user_name_from_home() {
    home=$1

    awk -F: -v h="$home" '
        $6 == h { print $1; exit }
    ' /etc/passwd
}

process_user_paths_for_system_store() {
    mode=$1
    conf=$2
    selected_store=$3

    store=`store_name_from_conf "$conf"`
    users_policy=`conf_value "$conf" users deny`

    if [ "$users_policy" != allow ]; then
        return 0
    fi

    for user_root in /home/*/"$USER_DIR_NAME"; do
        [ -d "$user_root" ] || continue

        home=`dirname "$user_root"`
        owner=`user_name_from_home "$home"`
        [ -n "$owner" ] || owner=`basename "$home"`

        paths=`user_paths_file_for_conf "$user_root" "$conf"`

        case "$mode" in
            check)
                printf '  user paths for %s: %s\n' "$owner" "$paths"
                if [ -f "$paths" ]; then
                    printf '  user paths file for %s: present\n' "$owner"
                else
                    printf '  user paths file for %s: absent\n' "$owner"
                fi
                ;;
            plan)
                read_paths_for_store user "$owner" "$home" "$conf" "$paths"
                ;;
            status)
                if [ -f "$paths" ]; then
                    printf '  user paths for %s: present\n' "$owner"
                fi
                ;;
        esac
    done
}

process_system_stores() {
    mode=$1
    selected=$2

    stores_dir=$ETC_DIR/stores.d

    if [ ! -d "$stores_dir" ]; then
        [ "$mode" = check ] && printf 'system stores: none\n'
        return 0
    fi

    found=0

    for conf in "$stores_dir"/*.conf; do
        [ -f "$conf" ] || continue

        name=`store_name_from_conf "$conf"`
        if [ -n "$selected" ] && [ "$selected" != "$name" ]; then
            continue
        fi

        found=1

        case "$mode" in
            check)
                printf 'system store: %s\n' "$name"
                root=`conf_value "$conf" root ""`
                if [ -z "$root" ]; then
                    printf '  error: missing root\n'
                else
                    printf '  root: %s\n' "$root"
                fi
                paths=`system_paths_file_for_conf "$conf"`
                printf '  system paths: %s\n' "$paths"
                if [ -f "$paths" ]; then
                    printf '  system paths file: present\n'
                else
                    printf '  system paths file: absent\n'
                fi
                process_user_paths_for_system_store check "$conf" "$selected"
                ;;
            status)
                print_store_summary system root "$conf"
                process_user_paths_for_system_store status "$conf" "$selected"
                ;;
            plan)
                print_store_summary system root "$conf"
                printf '\n'
                paths=`system_paths_file_for_conf "$conf"`
                read_paths_for_store system root / "$conf" "$paths"
                process_user_paths_for_system_store plan "$conf" "$selected"
                ;;
        esac

        [ "$mode" = check ] || printf '\n'
    done

    if [ "$found" -eq 0 ] && [ -n "$selected" ]; then
        return 1
    fi

    return 0
}

process_user_stores() {
    mode=$1
    selected=$2

    for user_root in /home/*/"$USER_DIR_NAME"; do
        [ -d "$user_root" ] || continue

        home=`dirname "$user_root"`
        owner=`user_name_from_home "$home"`
        [ -n "$owner" ] || owner=`basename "$home"`

        stores_dir=$user_root/stores.d

        [ -d "$stores_dir" ] || continue

        for conf in "$stores_dir"/*.conf; do
            [ -f "$conf" ] || continue

            name=`store_name_from_conf "$conf"`
            if [ -n "$selected" ] && [ "$selected" != "$name" ]; then
                continue
            fi

            case "$mode" in
                check)
                    printf 'user store: %s\n' "$name"
                    printf '  user: %s\n' "$owner"
                    root=`conf_value "$conf" root ""`
                    if [ -z "$root" ]; then
                        printf '  error: missing root\n'
                    else
                        printf '  root: %s\n' "$root"
                    fi
                    paths=`user_paths_file_for_conf "$user_root" "$conf"`
                    printf '  paths: %s\n' "$paths"
                    if [ -f "$paths" ]; then
                        printf '  paths file: present\n'
                    else
                        printf '  paths file: absent\n'
                    fi
                    ;;
                status)
                    print_store_summary user "$owner" "$conf"
                    ;;
                plan)
                    print_store_summary user "$owner" "$conf"
                    printf '\n'
                    paths=`user_paths_file_for_conf "$user_root" "$conf"`
                    read_paths_for_store user "$owner" "$home" "$conf" "$paths"
                    ;;
            esac

            [ "$mode" = check ] || printf '\n'
        done
    done

    return 0
}

cmd_check() {
    printf 'configuration root: %s\n\n' "$ETC_DIR"

    if [ -f "$ETC_DIR/storagegraft.conf" ]; then
        printf 'system main config: present\n'
    else
        printf 'system main config: absent\n'
    fi

    printf '\n'
    process_system_stores check ""
    printf '\n'

    for user_root in /home/*/"$USER_DIR_NAME"; do
        [ -d "$user_root" ] || continue

        home=`dirname "$user_root"`
        owner=`user_name_from_home "$home"`
        [ -n "$owner" ] || owner=`basename "$home"`

        if [ -f "$user_root/storagegraft.conf" ]; then
            printf 'user main config for %s: present\n' "$owner"
        else
            printf 'user main config for %s: absent\n' "$owner"
        fi
    done

    printf '\n'
    process_user_stores check ""

    return 0
}

cmd_status() {
    selected=$1

    process_system_stores status "$selected"
    process_user_stores status "$selected"

    return 0
}

cmd_plan() {
    selected=$1

    process_system_stores plan "$selected"
    process_user_stores plan "$selected"

    return 0
}

command_name=${1:-}

case "$command_name" in
    check)
        shift
        cmd_check "$@"
        ;;
    status)
        shift
        cmd_status "${1:-}"
        ;;
    plan)
        shift
        cmd_plan "${1:-}"
        ;;
    -h|--help|'')
        usage
        ;;
    *)
        printf '%s: unknown command: %s\n' "$PROGRAM" "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac