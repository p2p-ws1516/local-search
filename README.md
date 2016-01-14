# local-search

##Iteration 1

* Setup *Elixir* project
* Implement CLI (REPL)
* Implement simple Gnutella 0.4 using location (radius) as a simple filtering criterion.
* Note: Requests are simply flooded and without respect to the location.

###Iteration 1.1

* mix / build -> Flo -> **done** 
    * use *mix escript.build* to create executable *localsearch* file
* TCP / UDP -> Flo -> **done**
    * run *./localsearch --port 9999 --init* to start initial peer
    * run *./localsearch --port 8888 --bootstrap * to connect to this peer
    * **Note**: everything (including ports) is hardcoded in *localsearch.ex*, so it works only with these port numbers and on a single machine
* Test-Driven / Unit tests -> Denis
* REPL / CLI -> Denis **done** 
    * open client
        * if not present: ask for bootstrap IP
        * if not present: ask for location (lat / lon) 
    * options: 
        * query
            - radius (default: 10 km)
            - item
            - ...
        * add item
        * remove item
        * leave
    * handle responses
* Goal: by 2016-01-14

### Iteration 1.2

* Deal with partial failure (e.g. broken TCP connections)
* Make ports, lat/lon, etc. configurable, so we don't need to pass it as a command line argument

##Iteration 2

* Try to optimize joining of peers w.r.t. the location, i.e. try to find peers that are nearby.
* Maybe it will be necessary to have addititional random links as well, in order to achieve small world characteristics.
* Still, do not make routing decisions based on locations (may be stuck in local optima)

##Iteration 3
* Try to optimize routing w.r.t the location, e.g. do not flood requests further than necessary
* Note: considered hard by Prof. because we may get stuck in local optima
