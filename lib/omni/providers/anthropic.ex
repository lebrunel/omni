defmodule Omni.Providers.Anthropic do
  @moduledoc """
  Provider implementation for the [Anthropic Messages API](https://docs.anthropic.com/en/api/messages).
  Use this Provider to chat with any of the [Claude 3](https://www.anthropic.com/news/claude-3-family)
  models.

  ## Authorization

  Obtain an API key from the [Anthropic Developer Console](https://console.anthropic.com)
  and add it to your application's `config.exs`:

  ```elixir
  config :omni, Omni.Providers.Anthropic, "sk-ant-api-notarealkey"
  ```

  Alternatively, pass the API key to `Onmi.init/2`:

  ```elixir
  iex> Omni.init(:anthropic, api_key: api_key)
  %Omni.Provider{mod: Omni.Providers.Anthropic, req: %Req.Request{}}
  ```
  """
  use Omni.Provider

  @api_key Application.compile_env(:omni, [__MODULE__, :api_key], System.get_env("ANTHROPIC_API_KEY"))

  @sse_events [
    "message_start",
    "content_block_start",
    "content_block_delta",
    "content_block_stop",
    "message_delta",
    "message_stop",
  ]

  base_url "https://api.anthropic.com/v1"
  endpoint "/messages"
  stream_endpoint "/messages", stream: true

  schema [
    model: [
      type: :string,
      required: true,
      doc: "The model that will complete your prompt.",
    ],
    messages: [
      type: {:list, {:map, [
        role: [
          type: {:in, ["user", "assistant"]},
          required: true,
          doc: "The role of the message author.",
        ],
        content: [
          # For some reason nimble_options throws a wobbly if we try to type the
          # map here - I assume this nested conditional type is a bit much for it
          type: {:or, [:string, {:list, :map}]},
          required: true,
          doc: "The contents of the message.",
        ]
      ]}},
      required: true,
      doc: "Input messages.",
    ],
    max_tokens: [
      type: :integer,
      default: 4096,
      doc: "The maximum number of tokens to generate before stopping.",
    ],
    metadata: [
      type: :map,
      keys: [
        user_id: [
          type: :string,
          doc: "An external identifier for the user who is associated with the request.",
        ]
      ],
      doc: "A map describing metadata about the request.",
    ],
    stop_sequences: [
      type: {:list, :string},
      doc: "Custom text sequences that will cause the model to stop generating.",
    ],
    stream: [
      type: :boolean,
      doc: "Whether to incrementally stream the response using server-sent events.",
    ],
    system: [
      type: :string,
      doc: "System prompt.",
    ],
    temperature: [
      type: :float,
      doc: "Amount of randomness injected into the response.",
    ],
    tools: [
      type: {:list, {:map, [
        name: [
          type: :string,
          required: true,
          doc: "Name of the tool."
        ],
        description: [
          type: :string,
          required: true,
          doc: "Description of the tool"
        ],
        input_schema: [
          type: :map,
          required: true,
          doc: "JSON schema for the tool input shape that the model will produce in tool_use output content blocks."
        ]
      ]}},
      doc: "A list of tools the model may call.",
    ],
    tool_choice: [
      type: :map,
      keys: [
        type: [
          type: {:in, ["auto", "any", "tool"]},
          required: true,
          doc: "How the model should use the provided tools."
        ],
        name: [
          type: :string,
          doc: "The name of the tool to use."
        ]
      ],
      doc: "How to use the provided tools."
    ],
    top_k: [
      type: :integer,
      doc: "Only sample from the top K options for each subsequent token."
    ],
    top_p: [
      type: :float,
      doc: "Amount of randomness injected into the response."
    ],
  ]

  @impl true
  def headers(opts) do
    headers = %{
      content_type: "application/json",
      anthropic_version: "2023-06-01",
    }

    case Keyword.get(opts, :api_key, @api_key) do
      key when is_binary(key) ->
        Map.put(headers, :x_api_key, key)
      _ ->
        headers
    end
  end

  @impl true
  def parse_stream(data) do
    chunks =
      Regex.scan(~r/event:\s*(\w+)\ndata:\s*({.+})\n/, data)
      |> Enum.filter(& match?([_, event, _data] when event in @sse_events, &1))
      |> Enum.map(fn [_, _event, data] -> Jason.decode!(data) end)

    {:cont, chunks}
  end

  @impl true
  def merge_stream(_body, %{"type" => "message_start", "message" => message}) do
    message
  end

  def merge_stream(body, %{"type" => "content_block_start", "index" => i, "content_block" => block}) do
    update_in(body, ["content"], & List.insert_at(&1, i, block))
  end

  def merge_stream(body, %{"type" => "content_block_delta", "index" => i, "delta" => delta}) do
    update_in(body, ["content"], fn content ->
      List.update_at(content, i, fn block ->
        update_in(block, ["text"], & &1 <> delta["text"])
      end)
    end)
  end

  def merge_stream(body, %{"type" => "message_delta", "delta" => delta}) do
    Map.merge(body, delta)
  end

  def merge_stream(body, _data), do: body

end
