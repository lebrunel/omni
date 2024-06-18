import Config

if Mix.env() == :test do
  config :omni, :testing, true
end

if File.exists?("config/local.exs") do
  import_config "local.exs"
end
