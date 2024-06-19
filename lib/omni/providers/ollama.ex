defmodule Omni.Providers.Ollama do
  @moduledoc """
  Provider implementation for [Ollama](https://ollama.com/), using the
  [Ollama Chat API](https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-chat-completion).
  Use this Provider to chat with pretty much any local and open model (Llama 3,
  Mistral, Gemma, and [many more](https://ollama.com/library)).

  ## Base URL

  By default the Ollama Provider uses the base URL of `"http://localhost:11434/api"`.
  If you need to change this, pass the `:base_url` option to `Omni.init/2`:

  ```elixir
  iex> Omni.init(:ollama, base_url: "https://ollama.mydomain.com/api")
  %Omni.Provider{mod: Omni.Providers.Ollama, req: %Req.Request{}}
  ```
  """
  use Omni.Provider

  @base_url "http://localhost:11434/api"

  headers %{content_type: "application/json"}
  endpoint "/chat"
  stream_endpoint "/chat", stream: true

  schema [
    model: [
      type: :string,
      required: true,
      doc: "The ollama model name.",
    ],
    messages: [
      type: {:list, {:map, [
        role: [
          type: {:in, ["user", "assistant", "system"]},
          required: true,
          doc: "The role of the message, either `system`, `user` or `assistant`."
        ],
        content: [
          type: :string,
          required: true,
          doc: "The content of the message.",
        ],
        images: [
          type: {:list, :string},
          doc: "List of Base64 encoded images (for multimodal models only).",
        ]
      ]}},
      required: true,
      doc: "List of messages - used to keep a chat memory.",
    ],
    format: [
      type: :string,
      doc: "Set the expected format of the response (`json`).",
    ],
    stream: [
      type: :boolean,
      default: false,
      doc: "Whether to stream the response.",
    ],
    keep_alive: [
      type: {:or, [:integer, :string]},
      doc: "How long to keep the model loaded.",
    ],
    options: [
      type: {:map, {:or, [:atom, :string]}, :any},
      doc: "Additional advanced [model parameters](https://github.com/jmorganca/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values).",
    ],
  ]

  @impl true
  def base_url(opts), do: Keyword.get(opts, :base_url, @base_url)

  @impl true
  def parse_stream(data) do
    data = case Application.get_env(:omni, :testing) do
      true -> String.split(data, ~r/}(?<boundary>\B){/, on: [:boundary])
      _ -> [data]
    end

    {:cont, Enum.map(data, &Jason.decode!/1)}
  end

  @impl true
  def merge_stream("", data), do: merge_stream(%{}, data)
  def merge_stream(body, data) do
    Map.merge(body, data, fn
      "message", prev, next ->
        update_in(prev, ["content"], & &1 <> next["content"])
      _key, _prev, next -> next
    end)
  end

end
