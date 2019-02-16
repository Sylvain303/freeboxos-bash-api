#!/bin/bash
#
# Example: rename the tracker via Freebox API of one or ALL error torrent
# Usage:
#   ./rename_tracker.sh NUM_TASK
#   ./rename_tracker.sh ALL
#
# with ALL, the script will first fb_list_dl -f full list
# and select task_id in error
#
# NUM_TASK give the numeric ID of the task (See fb_list_dl output)

PATH=..:$PATH
source freeboxos_bash_api.sh

rename_tracker() {
  local task_id=$1
  local new_tracker=$2

  if [[ -z $new_tracker ]] ; then
    echo "rename_tracker:error: new_tracker is empty"
    return 1
  fi

  # get first tracker record from torrent $task_id
  local tracker_api="/downloads/$task_id/trackers"
  local tracker_json=$(call_freebox_api "$tracker_api")

  jq . <<< "$tracker_json"

  # get substitued tracker
  local new_url=$(jq -r ".result[0].announce|sub(\"^http://[^/]+\"; \"$new_tracker\")" \
    <<< "$tracker_json")

  local old_url=$(jq -r ".result[0].announce" <<< "$tracker_json")
  #echo "change $old_url => $new_url"

  # add the new tracker
  call_freebox_api "$tracker_api" "{\"announce\" : \"$new_url\"}"

  # remove old_url
  if _check_success "$answer" ; then
    echo "OK removing old tracker"
    call_freebox_api DELETE "$tracker_api/$(url_encode "$old_url")"
    # restart torrent
    call_freebox_api PUT "/downloads/$task_id" "{\"status\" : \"retry\"}"
  fi
}

# MAIN
ID=$1
NEW_TRACKER=$2

if [[ $ID == "ALL" ]] ; then
  # select torrent in error and build a new JSON
  fb_list_dl -f | jq '[ .result[]|select(.status == "error")|
    { name: .name, id: .id} ] ' \
      > dl_error.json
  if [[ $(wc -l < dl_error.json) -gt 0 ]] ;then
    for id in $(jq '.[].id' dl_error.json)
    do
      if ! rename_tracker $id ; then
        echo failed
      fi
    done
  fi
else
  rename_tracker $ID
fi
