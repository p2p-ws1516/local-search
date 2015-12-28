# local-search

##Iteration 1

* Setup *Elixir* project
* Implement CLI 
* Implement simple Gnutella 0.4 using location (radius) as a simple filtering criterion.
* Note: Requests are simply flooded and without respect to the location.

##Iteration 2

* Try to optimize joining of peers w.r.t. the location, i.e. try to find peers that are nearby.
* Maybe it will be necessary to have addititional random links as well, in order to achieve small world characteristics.
* Still, do not make routing decisions based on locations (may be stuck in local optima)

##Iteration 3
* Try to optimize routing w.r.t the location, e.g. do not flood requests further than necessary
* Note: considered hard by Prof. because we may get stuck in local optima
