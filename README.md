freeboxos-bash-api
==================

Fork de : https://github.com/JrCs/freeboxos-bash-api

Une traduction de la documentation en Français sera disponible. Ce fork ajoute des fonctionnalités, et utilise un parser
JSON différent [jq](http://stedolan.github.io/jq/manual/) au lieu de [JSON.sh](https://github.com/dominictarr/JSON.sh),
pour des raisons de performances.

Vous pouvez piper le json dans `| jq .` pour un joli formatage du JSON.

Regarder le code pour une version à jour de la doc…

La documentation originale en Anglais :


Access [FreeboxOS API](http://dev.freebox.fr/sdk/os/#api-list) from bash

Quick Start
-----------

You need to have `curl`, `openssl` and `jq` installed.

Get the source:

    $ curl -L http://github.com/JrCs/freeboxos-bash-api/raw/master/freeboxos_bash_api.sh > freeboxos_bash_api.sh


JQ : http://stedolan.github.io/jq/manual/

Example
-------
```bash
#!/bin/bash

MY_APP_ID="MyWonderfull.app"
MY_APP_TOKEN="4uZTLMMwSyiPB42tSCWLpSSZbXIYi+d+F32tVMx2j1p8oSUUk4Awr/OMZne4RRlY"

# source the freeboxos-bash-api
source ./freeboxos_bash_api.sh

# login
login_freebox "$MY_APP_ID" "$MY_APP_TOKEN"

# get xDSL data
answer=$(call_freebox_api '/connection/xdsl')

# extract max upload xDSL rate
up_max_rate=$(get_json_value_for_key "$answer" 'result.up.maxrate')

echo "Max Upload xDSL rate: $up_max_rate kbit/s"
```

API
---

#### *  authorize_application *app_id* *app_name* *app_version* *device_name*
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

#### *  login_freebox *app_id* *app_token*
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

#### *  call_freebox_api *api_path*
It is used to call a freebox API. The function will return a json string with an exit code of 0 if successfull. Otherwise it will return an empty string with an exit code of 1 and the reason of the error output to STDERR.
You can find the list of all available api [here](http://dev.freebox.fr/sdk/os/#api-list)
##### Example
```bash
answer=$(call_freebox_api '/connection/xdsl')
```

#### *  get_json_value_for_key *json_string* *key*
This function will return the value for the *key* from the *json_string*
##### Example
```bash
value=$(get_json_value_for_key "$answer" 'result.down.maxrate')
```

#### *  dump_json_keys_values *json_string*
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

#### *  reboot_freebox
This function will reboot your freebox. Return code will be 0 if the freebox is rebooting, 1 otherwise.
The application must be granted to modify the setup of the freebox (from freebox web interface).
##### Example
```bash
reboot_freebox
```

Available Commands
------------------

```bash
fb_help : list all available commands
fb_ls   : create ls_cache and list remote file with call_freebox_api 'fs/ls/'
fb_list_dl : list download in json format caching the résult -f to force cache reload
```

JQ hack
-------

embedded grep: fisrt list names matching 'fred' and reselect the whole json result
```bash
jq ".result[] | select(.name == $(jq '.result[] | .name '  < dl.json  | grep -i fred))" dl.json
```

finished downloads
```bash
fb_list_dl | jq '.result[] | select(.pct_compl >= 100)'
```
