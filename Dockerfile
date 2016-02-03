FROM nifty/elixir

COPY . local-search/
 
WORKDIR local-search/

# CMD ls -lisa
RUN mix local.hex --force

CMD mix test test/joining_test.exs
