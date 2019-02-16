# freeboxos-bash-api

**Status:** Working draft

## Description

Fork de : https://github.com/JrCs/freeboxos-bash-api

Pour une traduction de cette documentation en Français créer une Issue, SVP.

Ce fork ajoute de nouvelles fonctionnalités, et utilise un parser
JSON différent : [jq](http://stedolan.github.io/jq/manual/)

`jq` remplace totalement [JSON.sh](https://github.com/dominictarr/JSON.sh) qui était trop lent.

Vous pouvez piper le json dans `| jq .` pour un joli formatage du JSON.

Désolé pour cette doc succinte, il faut lire le code...

## Pourquoi faire ça en bash ? 
Ben, ça existait déjà, et du coup on peut le faire en interactif dans le shell:

```bash
$ . freeboxos_bash_api.sh 
resty is in PATH
jq is in PATH
logged_in?=false
login successful
SESSION_TOKEN='secret_token_here'
resty_H='X-Fbx-App-Auth: secret_token_here'
http://mafreebox.freebox.fr*

$ fb_ls
0:< . >
1:< .. >
2:< Disque dur >

# oui, la complétion bash fonctionne ! car il y un cache des dossiers en local.
$ fb_ls ./cache_fs/Disque\ dur/
base64path=L0Rpc3F1ZSBkdXI=
0:< . >
1:< .. >
2:< Enregistrements >
3:< Musiques >
4:< Photos >
5:< Téléchargements >
6:< Vidéos >
```


La documentation originale en Anglais + ajout des nouvelles commandes :

=======================================================================


Bash API for Freebox revoluion [FreeboxOS API](http://dev.freebox.fr/sdk/os/#api-list)

Quick Start
-----------

You need to have `curl`, `openssl` and `jq` installed.

on ubuntu/debian

```
sudo apt install curl openssl jq
```

Get the source:

```
git clone this_repos_URL
```

## Initialize your APP Grants on the freebox (once)

You may need to login to your freeboxos web interface and allow new app to register.

At, Thu Feb 14 2019 it was:
`Paramètres de la Freebox` > `Divers / Gestion des Accès` > `Paramètres` > `Applications : Permettre les nouvelles demandes d'association` *checked*

From your terminal, request a new application association with the Freebox:

(See bellow for API description `authorize_application`)

```bash
$ source ./freeboxos_bash_api.sh
$ authorize_application  'MyWonderfull.app'  'Full description'  '1.0.0'  'computer_name'

# Please grant/deny access to the app on the Freebox LCD...
# Yes, walk to physically touch the ">" key "Oui" on the Freebox!
#
# Authorization granted

# something like, will be displayed on the terminal
# save that to a file: auth.sh
SAVED_APP_ID="MyWonderfull.app"
SAVED_APP_TOKEN="4uZTLMMwSyiPB42tSCWLpSSZbXIYi+d+F32tVMx2j1p8oSUUk4Awr/OMZne4RRlY"
```

On the FreeboxOS web:
Still in `Gestion des Accès`, tab `Session`, you should see your new application with its privileges listed.

Good, you can go on!


Example
-------

Let's read some Data

```bash
#!/bin/bash

# APP_ID and APP_TOKEN are those given by authorize_application

# source the freeboxos-bash-api
source ./freeboxos_bash_api.sh

SAVED_APP_ID="MyWonderfull.app"
SAVED_APP_TOKEN="4uZTLMMwSyiPB42tSCWLpSSZbXIYi+d+F32tVMx2j1p8oSUUk4Awr/OMZne4RRlY"
# login
login_freebox "$SAVED_APP_ID" "$SAVED_APP_TOKEN"

# get xDSL data
answer=$(call_freebox_api '/connection/xdsl')

# extract max upload xDSL rate
up_max_rate=$(get_json_value_for_key "$answer" 'result.up.maxrate')

echo "Max Upload xDSL rate: $up_max_rate kbit/s"
```

API
---

#### authorize_application *app_id* *app_name* *app_version* *device_name*
It is used to obtain a token to identify a new application (need to be done only once)
##### Example
```bash
$ source ./freeboxos_bash_api.sh
$ authorize_application  'MyWonderfull.app'  'My Wonderfull App'  '1.0.0'  'Mac OSX'
Please grant/deny access to the app on the Freebox LCD...
Authorization granted

MY_APP_ID="MyWonderfull.app"
MY_APP_TOKEN="4uZTLMMwSyiPB42tSCWLpSSZbXIYi+d+F32tVMx2j1p8oSUUk4Awr/OMZne4RRlY"
```

#### login_freebox *app_id* *app_token*
It is used to log the application (you need the application token obtain from authorize_application function)
##### Example
```bash
#!/bin/bash

MY_APP_ID="MyWonderfull.app"
MY_APP_TOKEN="4uZTLMMwSyiPB42tSCWLpSSZbXIYi+d+F32tVMx2j1p8oSUUk4Awr/OMZne4RRlY"

# source the freeboxos-bash-api
source ./freeboxos_bash_api.sh

# login
login_freebox "$MY_APP_ID" "$MY_APP_TOKEN"
```

#### call_freebox_api [DELETE|PUT] *api_path* [DATA]
It is used to call a freebox API. The function will return a json string with an exit code of 0 if successfull. Otherwise it will return an empty string with an exit code of 1 and the reason of the error output to STDERR.
You can find the list of all available api [here](http://dev.freebox.fr/sdk/os/#api-list)

API call are shorted from what it can be viewed in the doc:

`GET /api/v4/fs/ls/{path}` becomes `call_freebox_api /fs/ls/${base64_path}`

etc.

If you call it with *DELETE* or *PUT* you change the behavior of the HTTP method. 

*DATA* can be JSON to send, if present, it become a *POST* HTTP call.

`$answer` is modified at each call, a glocal variable storing the last JSON returned by the API.  

##### Example
```bash
# $answer also contains what will be assigned in $json
json=$(call_freebox_api '/connection/xdsl')

# delete a torrent
call_freebox_api DELETE '/downloads/1234'

# restart a torrent
call_freebox_api PUT "/downloads/$task_id" "{\"status\" : \"retry\"}"       
```

#### get_json_value_for_key *json_string* *key*
This function will return the value for the *key* from the *json_string*

This is a compatibility function kept from the fork.

##### Example
```bash
value=$(get_json_value_for_key "$answer" 'result.down.maxrate')

# can also be accomplished by `jq` directly, of course:
value=$(jq '.result.down.maxrate'  <<< "$answer")
```

#### dump_json_keys_values *json_string*
This function will dump on stdout all the keys values pairs from the *json_string*
##### Example
```bash
answer=$(call_freebox_api '/connection/')
dump_json_keys_values "$answer"
echo
bytes_down=$(get_json_value_for_key "$answer" 'result.bytes_down')
echo "bytes_down: $bytes_down"
```
<pre>
success = true
result.type = rfc2684
result.rate_down = 40
result.bytes_up = 945912
result.rate_up = 0
result.bandwidth_up = 412981
result.ipv6 = 2a01:e35:XXXX:XXX::1
result.bandwidth_down = 3218716
result.media = xdsl
result.state = up
result.bytes_down = 2726853
result.ipv4 = XX.XXX.XXX.XXX
result = {"type":rfc2684,"rate_down":40,"bytes_up":945912,"rate_up":0,"bandwidth_up":412981,"ipv6":2a01:e35:XXXX:XXXX::1,"bandwidth_down":3218716,"media":xdsl,"state":up,"bytes_down":2726853,"ipv4":XX.XXX.XXX.XXX}

bytes_down: 2726853</pre>

#### reboot_freebox
This function will reboot your freebox. Return code will be 0 if the freebox is rebooting, 1 otherwise.
The application must be granted to modify the setup of the freebox (from freebox web interface).
##### Example
```bash
reboot_freebox
```

### Other available Commands

```bash
fb_dl_grep : list downloads matching a regexp pattern (JSON list)
fb_ls      : create a directory cache_fs/ and list remote file with call_freebox_api 'fs/ls/'
fb_list_dl : list download in json format caching the result (-f to force cache reload)
```
+ see Code.

## JQ hack

embedded grep: fisrt list names matching 'fred', then reselect the whole json result
```bash
jq ".result[] | select(.name == $(jq '.result[] | .name '  < dl.json  | grep -i fred))" dl.json
```

Better accomplished with actual `jq`:

```bash
pattern=fred
fb_list_dl | \
    jq -r "[ .result[]|select(.name|test(\"$pattern\")) ]"
```


finished downloads
```bash
fb_list_dl | jq '.result[] | select(.pct_compl >= 100)'
```
