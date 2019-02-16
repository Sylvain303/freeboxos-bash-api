#!/bin/bash
#
# Repostitory: https://github.com/Sylvain303/freeboxos-bash-api
# Forked from: https://github.com/JrCs/freeboxos-bash-api
#
# Usage:
#
# ==== ### NOTE ### ====
# The script will WRITE file in its own dir:
# - auth.sh   : [DOESN'T WORK YET] after the authorize process, store SAVED_APP_ID and SAVED_APP_TOKEN
# - resty     : a rest bash API downloaded bellow
# - cache_fs/ : a remote freebox HD folder cache used by fb_ls
#
# First: Call once the following registration step, requiring approval on the freebox
# LCD screen:
#
# $ source ./freeboxos_bash_api.sh
# $ authorize_application  'MyWonderfull.app'  \
#   'My Wonderfull App'  '1.0.0'  'xubuntu-laptop'
#
# After the registration store the MY_APP_ID and MY_APP_TOKEN outputed by the
# registration process. It will be required to authenticate again.
#
# You can modify this code to record the value bellow, See SAVED_APP_ID SAVED_APP_TOKEN
#
# Normal registered usage:
#
# $ source ./freeboxos_bash_api.sh
# $ MY_APP_ID="MyWonderfull.app"
# $ MY_APP_TOKEN="long string full of random char returned by the box above"
# $ login_freebox "$MY_APP_ID" "$MY_APP_TOKEN"
#
# After authentication the session is holded by the box during few mins. You
# can issue API command directly
#
# List the root of the box displaying connected and internal harddrive:
# $ call_freebox_api 'fs/ls/'

### Config
FREEBOX_URL="http://mafreebox.freebox.fr"
_API_VERSION=
_API_BASE_URL=
_SESSION_TOKEN=

# can be modified here or in the external file auth.sh (not under source control)
SAVED_APP_ID=""
SAVED_APP_TOKEN=""

# external tools required
downloads="
http://github.com/micha/resty/raw/master/resty::resty
apt-get==intstall==jq::jq
"
# alternative bash parser for json, but slower.
#https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh::JSON

# Tools
# resty: a rest bash shortcut wrapper for curl
RESTY=resty
# a realy fast binary JSON parser
JQ=jq

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))
PATH=$PATH:$SCRIPT_DIR

# loop over the subscript to download
for cmd in $downloads
do
  url=${cmd%%::*}
  exe=${cmd##*::}
  #echo $cmd $url $exe
  path=$(type -P "$exe")
  if [[ "$path" != "" ]]
  then
    echo "$exe is in PATH"
    # ${var^^} make it UPPERCASE bash 4
    eval "${exe^^}=$path"

  else
    echo "$exe is NOT in PATH"
    if [[ $url =~ ^http ]]
    then
      echo "downloading url in '$SCRIPT_DIR' $url"
      path=$SCRIPT_DIR/$exe
      curl -L "$url" > $path
      chmod a+x $path
      eval "${exe^^}=$path"
    else
      # don't perform install but notice the user
      echo "to install $exe use: $(echo "$url" | sed -e 's/==/ /g')"
      eval "${exe^^}=''"
    fi
  fi
done

# test the json parser
if [[ "$JQ" == "" ]]
then
  echo some error no JSON parser found.
  return 1
fi

######## FUNCTIONS ########

# read the json for the key in $2, "$1" hold the full json string
function get_json_value_for_key {
  local r=$(echo "$1" | jq -r ".$2")
  if [[ "$r" == "null" ]]
  then
    echo ""
    return 1
  fi
  echo "$r"
  # echo "debug:$2 = '$r'" >> log
  return 0
}

function _check_success {
    local value=$(get_json_value_for_key "$1" success)
    if [[ "$value" != true ]]; then
        echo "$(get_json_value_for_key "$1" msg): $(get_json_value_for_key "$1" error_code)" >&2
        return 1
    fi
    return 0
}

function _check_freebox_api {
    local answer=$(curl -s "$FREEBOX_URL/api_version")
    _API_VERSION=$(get_json_value_for_key "$answer" api_version | sed 's/\..*//')
    _API_BASE_URL=$(get_json_value_for_key "$answer" api_base_url)
}

# call API directly as specified in http://dev.freebox.fr/sdk/os/
# global $answer is modified
# Usage:
#  call_freebox_api /downloads
#  # POST
#  call_freebox_api /downloads/${id}/trackers "$POST_JSON"
function call_freebox_api {
    local options=("")
    if [[ $1 == "DELETE" || $1 == "PUT" ]] ; then
      options+=(-X $1)
      shift
    fi

    local api_url="$1"
    local data="${2-}"
    # remove mutltiple slashes
    local url="${FREEBOX_URL}$(echo "${_API_BASE_URL}v${_API_VERSION}/$api_url" | sed 's@/\+@/@g')"
    [[ -n "$_SESSION_TOKEN" ]] && options+=(-H "X-Fbx-App-Auth: $_SESSION_TOKEN")
    [[ -n "$data" ]] && options+=(-d "$data")
    answer=$(curl -s "$url" "${options[@]}")
    _check_success "$answer" || return 1
    echo "$answer"
}

function login_freebox {
    local APP_ID="$1"
    local APP_TOKEN="$2"
    local answer=

    answer=$(call_freebox_api 'login') || return 1
    local challenge=$(get_json_value_for_key "$answer" "result.challenge")
    local password=$(echo -n "$challenge" | openssl dgst -sha1 -hmac "$APP_TOKEN" | sed  's/^(stdin)= //')
    answer=$(call_freebox_api '/login/session/' "{\"app_id\":\"${APP_ID}\", \"password\":\"${password}\" }") || return 1
    _SESSION_TOKEN=$(get_json_value_for_key "$answer" "result.session_token")
    echo "login successful"
    echo "SESSION_TOKEN='$_SESSION_TOKEN'"
    echo "resty_H='X-Fbx-App-Auth: $_SESSION_TOKEN'"
    resty_H="X-Fbx-App-Auth: $_SESSION_TOKEN"
}

function authorize_application {
    local APP_ID="$1"
    local APP_NAME="$2"
    local APP_VERSION="$3"
    local DEVICE_NAME="$4"
    local answer=

    answer=$(call_freebox_api 'login/authorize' "{\"app_id\":\"${APP_ID}\", \"app_name\":\"${APP_NAME}\", \"app_version\":\"${APP_VERSION}\", \"device_name\":\"${DEVICE_NAME}\" }")
    local app_token=$(get_json_value_for_key "$answer" "result.app_token")
    local track_id=$(get_json_value_for_key "$answer" "result.track_id")

    echo 'Please grant/deny access to the application on the Freebox LCD...' >&2
    local status='pending'
    while [[ "$status" == 'pending' ]]; do
      sleep 5
      answer=$(call_freebox_api "login/authorize/$track_id")
      status=$(get_json_value_for_key "$answer" "result.status")
    done
    echo "Authorization $status" >&2
    [[ "$status" != 'granted' ]] && return 1
    echo >&2
    cat <<EOF
# TODO: Save it as auth.sh (will be used automatically)
SAVED_APP_ID="$APP_ID"
SAVED_APP_TOKEN="$app_token"
EOF
}

# short cut function which fetch data in $answer and export its value in the variable of
# the same name. For mutiple subkey export the last part.
# short version of:
# local loged_in=$(get_json_value_for_key "$answer" "result.logged_in")
jq_get()
{
  local varname=$1
  if [[ "$1" =~ \. ]]
  then
    varname=${1##*.}
  fi
  eval "$varname=\"$(echo "$answer" | jq -r ".result | .$1")\""
}

function fb_check_session() {
  answer=$(call_freebox_api login/)
  #local loged_in=$(get_json_value_for_key "$answer" "result.logged_in")
  ##echo loged_in=$loged_in
  #unset loged_in
  jq_get logged_in
  echo logged_in?=$logged_in
  if [[ "$logged_in" == "false" ]]
  then
    if [ -f $SCRIPT_DIR/auth.sh ]
    then
      source $SCRIPT_DIR/auth.sh
    fi
    login_freebox "$SAVED_APP_ID" "$SAVED_APP_TOKEN"
  fi
}

######## API free box tools  ########

function reboot_freebox {
    call_freebox_api '/system/reboot' '{}' >/dev/null
}

DLCACHE=$SCRIPT_DIR/dl.json
fb_dl_build_cache() {
  call_freebox_api 'downloads/' | jq . > $DLCACHE
}

# fb_list_dl: list all download as JSON ouput
# It will store result in  a cache file $DLCACHE
# JSON:
# "{
#     result: [
#       {
#         "name": "debian9.iso",
#         "size_MB": 2164.8406982421875,
#         "pct_compl": 5.58,
#         "ratio": 0.3359603524229075,
#         "stop_ratio": 6,
#         "id": 1374,
#         "status": "error",
#         "error": "bt_tracker_error"
#       },
#       { ... }
#    ],
#    "downloads": 77
#  }

# downloads : $count }" \
function fb_list_dl() {
  #dlcache=$(mktemp fbtmp_XXXXX_dl.json)
  local msg="use cached result: $DLCACHE"
  if [ ! -f $DLCACHE -o "$1" == "-f" ]
  then
    msg="rebuild cache : api call fb_dl_build_cache"
    fb_dl_build_cache
  fi

  local count=$(jq '.result[].id' $DLCACHE | wc -l)

  # this output is json compatible so it can be piped back into jq, .result[], .donwloads
  jq "{ result: [ .result[] |
      { name,
      size_MB : (.size / 1048576),
      pct_compl : (.tx_pct / 100),
      ratio : (.tx_bytes / .size),
      stop_ratio : (.stop_ratio / 100),
        id, status, error
      }
      ],
    msg: \"$msg\",
    downloads : $count }" \
    $DLCACHE
}

# helper apply and rewrap the result with a .result[] selector
function jq_filter_wrap() {
  jq "{result: [ .result[] | $1 ] }"
}

# ###################### ====>  useful jq combo <=================== ###################
# finished downloads : fb_list_dl | jq '.result[] | select(.pct_compl >= 100)
# list download_dir or cat path : jq -r '.result[] | if .download_dir == "L0Rpc3F1ZSBkdXIvVMOpbMOpY2hhcmdlbWVudHMv" then "L0Rpc3F1ZSBkdXIvVMOpbMOpY2hhcmdlbWVudHMv" + (.name | @base64)  else .download_dir end' < dl.json

function fb_dl_grep() {
  # grep inside the downloads
  fb_list_dl | \
    jq -r "[ .result[]|select(.name|test(\"$1\")) ]"
}

fb_ls() {
  # $cache_dir is a folder tree stored localy to allow bash file name completion
  # each dir as a .path file storing it base64 freebox path
  cache_dir=$SCRIPT_DIR/cache_fs
  LS_JSON=$SCRIPT_DIR/ls.json
  [ ! -d $cache_dir ] && mkdir $cache_dir

  # split on newline only
  OLDIFS=$IFS
  IFS=$'\n'
  i=-1

  local base64path=''
  if [[ "$1" != "" ]]
  then
    if [ -d "$1" ]
    then
      base64path=$(cat "$1/.path")
      echo "base64path=$base64path"
    else
      base64path=$1
    fi
  fi

  call_freebox_api fs/ls/$base64path > $LS_JSON
  for d in $(jq -r '.result[].name' $LS_JSON)
  do
    i=$(( $i + 1 ))
    echo "$i:< $d >"
    if [[ $d == '.' || $d == '..' ]]
    then
      continue
    fi

    # extract the json for the folder with prefix .result
    answer=$(jq "{result : .result[$i] }" $LS_JSON)

    jq_get type
    #echo "type=$type"
    if [[ $type == "dir" ]]
    then
      jq_get path
      lpath="$cache_dir/$(echo "$path" | base64 -d)"
      #echo $lpath
      mkdir -p "$lpath"
      echo "$path" > "$lpath/.path"
    fi
  done

  IFS=$OLDIFS
}

fb_get_dl_hash() {
  jq -r ".result[] | select(.id == $1) | .download_dir" < $DLCACHE
}

fb_test_file() {
  local base64path=''
  if [[ "$1" == "-b" ]]
  then
    base64path="$2"
  # # following test detects base64 but it involves 2 subcommands
  # elif [[ $(echo "$1" | base64 -d | base64 -w0) == "$1" ]]
  # then
  #   base64path="$1"
  else
    base64path=$(echo -n "$1" | base64 -w0)
  fi
  answer=$(call_freebox_api fs/info/$base64path)
}

## WARNING: the is a draft and may delete all your torrent
fb_dl_check_file() {
  # encoded base64 /Disque dur/Téléchargements
  local t=L0Rpc3F1ZSBkdXIvVMOpbMOpY2hhcmdlbWVudHMv
  local tot=0
  local ok=0
  local delete=false

  fb_dl_build_cache

  if [[ "$1" == "--delete" ]]
  then
    delete=true
    shift
  fi

  for id in $(jq -r '.result[] | .id' < $DLCACHE )
  do
    base64path=$(jq -r ".result[] | select(.id == $id) | if .download_dir == \"$t\" then \"$t\" + (.name | @base64)  else .download_dir end" < $DLCACHE)

    #echo "id=$id base64path=$base64path"
    tot=$(($tot + 1))

    if ! fb_test_file -b "$base64path" 2> /dev/null
    then
      # it is not always true because some filename are wrong
      # lets try the same path but the internal filename
      answer=$(call_freebox_api downloads/$id/files)
      jq_get '[0].name'
      if [[ "$name" == "" ]]
      then
        echo "$answer" | jq .
        return 1
      fi
      fullpath=$(echo -n "$base64path" | base64 -d)
      test_fname="$(dirname "$fullpath")/$name"
      if ! fb_test_file "$test_fname" 2> /dev/null
      then
        echo "id:$id not found: '$fullpath'"
        echo "test_fname=$test_fname"

        if $delete
        then
          DELETE ${_API_BASE_URL}v${_API_VERSION}/downloads/$id/erase
        fi
      else
        ok=$(($ok + 1))
      fi
    else
      ok=$(($ok + 1))
    fi
  done

  echo "ok=$ok/$tot"
}

url_encode() {
  echo "$1"|sed 's/%/%25/g
s/\[/%5B/g
s/\]/%5D/g
s/|/%7C/g
s/\$/%24/g
s/&/%26/g
s/+/%2B/g
s/,/%2C/g
s/:/%3A/g
s/;/%3B/g
s/=/%3D/g
s/?/%3F/g
s/@/%40/g
s/ /%20/g
s/#/%23/g
s/{/%7B/g
s/}/%7D/g
s/\\/%5C/g
s/\^/%5E/g
s/~/%7E/g
s/`/%60/g
s/\//%2F/g
'
}

######## MAIN ########

# fill _API_VERSION and _API_BASE_URL variables
_check_freebox_api
source $RESTY
fb_check_session
resty $FREEBOX_URL -H "$resty_H"
