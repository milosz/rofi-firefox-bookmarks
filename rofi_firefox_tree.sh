#!/usr/bin/env bash
# rofi - list bookmarks tree
# rofi -show firefox_tree -modi "firefox_tree:/path/to/rofi_firefox_tree.sh"

# places.sqlite location
places_file="$(find ~/.mozilla/firefox/*.default*/ -name "places.sqlite" -print -quit)"

# places.sqlite copy
places_backup="$(dirname "${places_file}")/places.rofi.sqlite"

# path to the sqlite3 binary
sqlite_path="$(which sqlite3)"

# sqlite3 parameters (define separator character)
sqlite_params="-separator ^"

# browser path
browser_path="$(which firefox)"

# functions

# create a backup file
create_backup() {
  if [ "$#" -eq 2 ] && [ -n "$1" ] && [ -n "$2" ]; then
    if [ ! -f "$2" ] || [ "$1" -nt "$2" ]; then
      cp "$1" "$2"
    fi
  fi
}

# get current folder id
get_current_folder_id() {
  if [ "$#" -eq 1 ]; then
    if [ -z "$1" ]; then
      query="select id from moz_bookmarks where parent=0 and position=0 and type=2"
    else
      id="$(echo "$1" | sed "s|.*{id:\(.*\)}$|\1|")"
      query="select id from moz_bookmarks where type=2 and id='$id'"
    fi
    echo "$($sqlite_path $sqlite_params "$places_backup" "$query")"
  fi
}

# display parent
display_parent() {
  if [ "$#" = 1 ] && [ -n "$1" ]; then
    query="select parent from moz_bookmarks where id=$1 and type=2"
    result="$($sqlite_path $sqlite_params "$places_backup" "$query")"
    if [ -n "$result" ] && [ "$result" -ne "0" ]; then
      printf "%-500s {id:%s}\n" ".." "$result"
    fi
  fi
}

# process folder
process_folder() {
  if [ "$#" = 1 ] && [ -n "$1" ]; then

    display_parent "$1"

    query="select id, title from moz_bookmarks where parent=$1 and type=2 and (select count(*) from moz_bookmarks as b2 where b2.parent=moz_bookmarks.id)>0"
    $sqlite_path $sqlite_params "$places_backup" "$query" | while IFS=^ read id title; do
      if [ "$title" == "tags" ]; then
        continue
      fi

      if [ -z "$title" ]; then
        title="(no title)"
      fi

      printf "%-500s {id:%s}\n" "$title" "$id"
    done
  fi
}

# process bookmarks
process_bookmarks() {
  if [ "$#" = 1 ] && [ -n "$1" ]; then
    query="select b.title, p.url, b.id, SUBSTR(SUBSTR(p.url, INSTR(url, '//') + 2), 0, INSTR(SUBSTR(p.url, INSTR(p.url, '//') + 2), '/')) from moz_bookmarks as b left outer join moz_places as p on b.fk=p.id where b.type = 1 and p.hidden=0 and b.title not null and parent=$1"
	$sqlite_path $sqlite_params "$places_backup" "$query" | while IFS=^ read title url id domain; do
      if [ -z "$title" ]; then
        title="$url"
      fi
      printf "%-500s {id:%s}\n" "$title [$domain]" "$id"
    done
  fi
}

# process bookmark
process_bookmark() {
  if [ "$#" = 1 ] && [ -n "$1" ]; then
    id="$(echo $1 | sed "s|.*{id:\(.*\)}$|\1|")"
    query="select p.url from moz_bookmarks as b left outer join moz_places as p on b.fk=p.id where b.type = 1 and p.hidden=0 and b.title not null and b.id=$id"
    url="$($sqlite_path $sqlite_params "$places_backup" "$query")"
    nohup $browser_path "$url" >/dev/null 2>&1 &
  fi
}

# application

parameter="$1"

# create a backup, as we cannot operate on a places.sqlite file directly due to exclusive lock
create_backup "$places_file" "$places_backup"

# determine current folder
folder_id=$(get_current_folder_id "$parameter")

# open a bookmark when id is not a folder
if [ -z "$folder_id" ]; then
  process_bookmark "$parameter"
  exit
fi

# process current folder
process_folder "$folder_id"

# process bookmarks
process_bookmarks "$folder_id"
