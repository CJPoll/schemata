use Mix.Config

config :schemata, Schemata.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "thunder_corp_test",
  ownership_timeout: 10_000,
  hostname: if(System.get_env("CI"), do: "postgres", else: "localhost"),
  pool: Ecto.Adapters.SQL.Sandbox
