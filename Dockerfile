FROM nifty/elixir

COPY . local-search/
 
WORKDIR local-search/

RUN mix local.hex --force

EXPOSE 9999 9999

CMD mix escript.build && ./localsearch --port=9999 --init
