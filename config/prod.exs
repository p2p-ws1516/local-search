use Mix.Config

config :logger, format: "[$level] $message\n",
  backends: [{LoggerFileBackend, :error_log}]

config :logger, :error_log,
  path: "log.log",
  level: :info