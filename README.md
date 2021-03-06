# local-search

**local-search** is a location aware Gnutella implementation.

Peers join the overlay with their geographical location (latitude / longitude). Each peer maintains an inventory of *items*. Other peers can look for items of interest in a particular radius around their own location. These queries can be arbitrary regular expressions that are matched against the inventory of other peers. Location awareness should allow for a more efficient overlay structure and query routing.

## Install 

1. install [Elixir](http://elixir-lang.org/install.html) programming language
2. install [Hex](https://hex.pm/) package manager with `mix local.hex --force`
3. get the dependencies with `mix deps.get`
4. build the binary with `mix escript.build`

## Run

**Note:** the order of command line options *matters*

To show log messages (including responses to queries) run `./logger`.

`./localsearch --port=9999 --init --lat=53.548077 --lon=9.962151` starts a bootstrap peer with listening port 9999 at the location given by latitude / longitude

`./localsearch --port=9999 --init --lat=53.548077 --lon=9.962151 --lip=188.226.178.57 --lport=9876` starts a bootstrap peer with listening port 9999 at the location given by latitude / longitude that periodically sends status updates to a central log server at 188.226.178.57:9876 (for testing)

`./localsearch --port=9998 --bip=127.0.0.1 --bport=9999 --lat=53.548077 --lon=9.962151` starts a normal peer using bootstrap node at 127.0.0.1:9999 at the location given by latitude / longitude

`./localsearch --port=9998 --bip=127.0.0.1 --bport=9999 --lat=53.548077 --lon=9.962151` starts a normal peer using bootstrap node at 127.0.0.1:9999 at the location given by latitude / longitude that periodically sends status updates to a central log server at 188.226.178.57:9876 (for testing)

A global log server is aviable at 188.226.178.57:9876 and can be inspected at http://188.226.178.57:3133/

The Implementation of the log-server can be found [here](https://github.com/mhhf/localsearch-viz).

## Test

Run `mix test` to run a set of unit tests.

## Examples

To start some peers copy, paste and run these commands:

```
./localsearch --port=8000 --init --lat=50.0 --lon=10.0 --lip=188.226.178.57 --lport=9876
./localsearch --port=9001 --bip=127.0.0.1 --bport=8000 --lat=52.22968 --lon=1.050072 --lip=188.226.178.57 --lport=9876 #Hamburg
./localsearch --port=9002 --bip=127.0.0.1 --bport=8000 --lat=39.062144 --lon=125.77113 --lip=188.226.178.57 --lport=9876 #Nordkorea
./localsearch --port=9003 --bip=127.0.0.1 --bport=8000 --lat=-23.668326 --lon=-46.666742 --lip=188.226.178.57 --lport=9876 #Brasilien
./localsearch --port=9004 --bip=127.0.0.1 --bport=8000 --lat=39.77299 --lon=-85.912236 --lip=188.226.178.57 --lport=9876 #USA
./localsearch --port=9005 --bip=127.0.0.1 --bport=8000 --lat=-36.698554 --lon=144.210930 --lip=188.226.178.57 --lport=9876 #Australien
./localsearch --port=9006 --bip=127.0.0.1 --bport=8000 --lat=10.226629 --lon=10.722805 --lip=188.226.178.57 --lport=9876 #Afrika
```

## Roadmap 
###Iteration 1 (done)

* Setup *Elixir* project
* Implement CLI (REPL)
* Implement simple Gnutella 0.4 using location (radius) as a simple filtering criterion.
* Note: Requests are simply flooded and without respect to the location.

####Iteration 1.1 (done)

* mix / build -> Flo -> **done** 
    * use *mix escript.build* to create executable *localsearch* file
* TCP / UDP -> Flo -> **done**
    * run *./localsearch --port 9999 --init* to start initial peer
    * run *./localsearch --port 8888 --bootstrap * to connect to this peer
    * **Note**: everything (including ports) is hardcoded in *localsearch.ex*, so it works only with these port numbers and on a single machine
* Test-Driven / Unit tests -> Denis **done**
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

#### Iteration 1.2 (done)

* Implement Gnutella 0.4 -> Flo
    * Joining algorithm **done**
    * Query algorithm **done**
        * very simple implementation based on exact strings and without location awareness 
* Deal with partial failure (e.g. broken TCP connections) **done**
    * some errors get caught    

#### Iteration 1.3 (done)

* Feature: Finish REPL **done**
* Queries:
    * Bug: Filter queries based on location **done**
    * Feature: Allow for more complex queries **done**
        - can query by regex and get back multiple results
* Examine / handle more partial failure scenarios **done**
    * Refactoring: find cleaner way to propagate TCP errors to peer's link list
* Test: Find way to examine overlay structure (e.g. supervisor) **done**

###Iteration 2 (unfinished)

* Try to optimize joining of peers w.r.t. the location, i.e. try to find peers that are nearby.
    * Maybe it will be necessary to have addititional random links as well, in order to achieve small world characteristics.
    * Still, do not make routing decisions based on locations (may get stuck in local optima)

###Iteration 3 (unfinished)

* Try to optimize routing w.r.t the location, e.g. do not flood requests further than necessary
    * Note: considered hard by Prof. because we may get stuck in local optima
