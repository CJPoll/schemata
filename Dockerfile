FROM elixir:1.8-alpine

RUN apk update
RUN apk add alpine-sdk curl tar xz git bash

RUN mix local.hex --force
RUN mix local.rebar --force

WORKDIR /code

COPY config/ config/
COPY mix.exs mix.exs
COPY mix.lock mix.lock

RUN mix deps.get
RUN mix deps.compile

COPY . .

RUN mix compile
