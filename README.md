# Zurl #

Zurl is a command-line tool written in Zig, designed to provide a simplified interface to perform HTTP requests, inspired by the functionality of `curl`. Zurl aims to offer additional features and ease of use, including the ability to save and replay requests, automatic management of authentication requests, and more.

Zurl uses libcurl under the hood to handle HTTP requests and responses.
Zurl uses sqlite3 to save the requests.


### Building from source

Zurl can be built using devbox to create a dev shell with all the necessary dependencies.

``` bash
git clone git@github.com:iskyd/zurl.git
cd zurl
zig build
```

### Usage

Executing a GET request
``` bash
zurl --method GET --header Content-type=application/json https://pokeapi.co/api/v2/pokemon/mewtwo | jq .stats
```

Zurl supports headers, query (query params) and json.
``` bash
zurl --method GET --query key=value --header Content-type=application/json https://pokeapi.co/api/v2/pokemon/mewtwo | jq .stats
zurl --method POST --json '{"key": "value"}' --query key=value --header Content-type=application/json https://api.example.com
```

Initialize the sqlite database to save the requests.
``` bash
zurl --init --db zurl.db
```

Save the current request.
``` bash
zurl --save pokemon/mewtwo --db zurl.db --method GET https://pokeapi.co/api/v2/pokemon/mewtwo
```

Execute a saved request.
``` bash
zurl --find pokemon/mewtwo --db zurl.db
```

List all the saved requests (support --filter)
``` bash
zurl --db zurl.db --list
zurl --db zurl.db --list --filter pokemon%
```

