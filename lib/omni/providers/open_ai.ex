defmodule Omni.Providers.OpenAI do
  @moduledoc """
  Provider implementation for the [OpenAI Chat API](https://platform.openai.com/docs/api-reference/chat).
  Use this Provider to chat with any of the [Chat GPT](https://platform.openai.com/docs/models)
  models.

  ## Authorization

  Obtain an API key from the [OpenAI Developer Dashboard](https://platform.openai.com/api-keys)
  and add it to your application's `config.exs`:

  ```elixir
  config :omni, Omni.Providers.OpenAI, "sk-proj-notarealkey"
  ```

  Alternatively, pass the API key to `Onmi.init/2`:

  ```elixir
  iex> Omni.init(:openai, api_key: api_key)
  %Omni.Provider{mod: Omni.Providers.OpenAI, req: %Req.Request{}}
  ```

  ## OpenAI configuration

  This Provider accepts the following initialization options:

  - `:organization_id` - When given, sets the `openai-organization` header.
  - `:project_id` - When given, sets the `openai-project` header.

  ## Base URL

  Many LLM providers mirror OpenAI's API. In such cases, you can use this
  Provider module and pass the `:base_url` option to `Omni.init/2`:

  ```elixir
  iex> Omni.init(:ollama, base_url: "https://api.together.xyz/v1")
  %Omni.Provider{mod: Omni.Providers.OpenAI, req: %Req.Request{}}
  ```
  """
  use Omni.Provider

  @api_key Application.compile_env(:omni, [__MODULE__, :api_key], System.get_env("OPENAI_API_KEY"))
  @base_url "https://api.openai.com/v1"

  endpoint "/chat/completions"
  stream_endpoint "/chat/completions", stream: true

  schema [
    model: [
      type: :string,
      required: true,
      doc: "Name of the model to use.",
    ],
    messages: [
      type: {:list, {:map, [
        role: [
          type: {:in, ["system", "user", "assistant", "tool"]},
          required: true,
          doc: "The role of the message author.",
        ],
        content: [
          type: :string,
          required: true,
          doc: "The contents of the message.",
        ],
        name: [
          type: :string,
          doc: "An optional name for the participant.",
        ],
        tool_calls: [
          type: {:list, {:map, [
            id: [
              type: :string,
              required: true,
              doc: "The ID of the tool call.",
            ],
            type: [
              type: {:in, ["function"]},
              required: true,
              doc: "The type of the tool.",
            ],
            function: [
              type: :map,
              keys: [
                name: [
                  type: :string,
                  required: true,
                  doc: "The name of the function to call.",
                ],
                arguments: [
                  type: :string,
                  required: true,
                  doc: "JSON encoded arguments to call the function with.",
                ]
              ],
              required: true,
              doc: "The function that the model called.",
            ]
          ]}},
          doc: "The tool calls generated by the model",
        ],
        tool_call_id: [
          type: :string,
          doc: "Tool call that this message is responding to.",
        ]
      ]}},
      required: true,
      doc: "A list of messages comprising the conversation so far.",
    ],
    logit_bias: [
      type: {:map, :string, :integer},
      doc: "Modify the likelihood of specified tokens appearing in the completion.",
    ],
    log_probs: [
      type: :boolean,
      doc: "Whether to return log probabilities of the output tokens or not.",
    ],
    top_logprobs: [
      type: {:in, 0..20},
      doc: "An integer between 0 and 20 specifying the number of most likely tokens to return at each token position.",
    ],
    max_tokens: [
      type: :non_neg_integer,
      doc: "The maximum number of tokens that can be generated in the chat completion.",
    ],
    n: [
      type: :non_neg_integer,
      doc: "How many chat completion choices to generate for each input message.",
    ],
    frequency_penalty: [
      type: :float,
      doc: "Number between -2.0 and 2.0.",
    ],
    presence_penalty: [
      type: :float,
      doc: "Number between -2.0 and 2.0.",
    ],
    response_format: [
      type: :map,
      keys: [
        type: [type: {:in, ["text", "json_object"]}]
      ],
      doc: "An object specifying the format that the model must output."
    ],
    seed: [
      type: :integer,
      doc: "If specified, system will make a best effort to sample deterministically.",
    ],
    stop: [
      type: {:or, [:string, {:list, :string}]},
      doc: "Up to 4 sequences where the API will stop generating further tokens.",
    ],
    stream: [
      type: :boolean,
      doc: "If set, partial message deltas will be sent.",
    ],
    stream_options: [
      type: :map,
      keys: [
        include_usage: [
          type: :boolean,
          doc: "If set, an additional usage stats chunk will be streamed.",
        ]
      ],
      doc: "Options for streaming response.",
    ],
    temperature: [
      type: :float,
      doc: "What sampling temperature to use, between 0 and 2.",
    ],
    top_p: [
      type: :float,
      doc: "An alternative to sampling with temperature, called nucleus sampling.",
    ],
    tools: [
      type: {:list, {:map, [
        type: [
          type: {:in, ["function"]},
          required: true,
          doc: "The type of the tool.",
        ],
        function: [
          type: :map,
          required: true,
          keys: [
            name: [
              type: :string,
              required: true,
              doc: "The name of the function to be called.",
            ],
            description: [
              type: :string,
              doc: "The name of the function to be called.",
            ],
            parameters: [
              type: :map,
              doc: "The parameters the functions accepts, described as a JSON Schema object.",
            ]
          ],
        ]
      ]}},
      doc: "A list of tools the model may call.",
    ],
    tool_choice: [
      type: {:or, [{:in, ["none", "auto", "required"]}, {:map, [
        type: [
          type: {:in, ["function"]},
          required: true,
          doc: "The type of the tool.",
        ],
        function: [
          type: :map,
          required: true,
          keys: [
            name: [type: :string, required: true],
          ],
        ],
      ]}]},
      doc: "Controls which (if any) tool is called by the model."
    ],
    user: [
      type: :string,
      doc: "A unique identifier representing your end-user.",
    ]
  ]

  @impl true
  def base_url(opts), do: Keyword.get(opts, :base_url, @base_url)

  @impl true
  def headers(opts \\ []) do
    headers =
      %{content_type: "application/json"}
      |> header(opts, :organization_id, & {:openai_organization, &1})
      |> header(opts, :project_id, & {:openai_project, &1})

    case Keyword.get(opts, :api_key, @api_key) do
      key when is_binary(key) ->
        Map.put(headers, :authorization, "Bearer #{key}")
      _ ->
        headers
    end
  end

  @spec header(
    Omni.Provider.headers(),
    keyword(),
    atom(),
    (term() -> {atom() | String.t(), String.t()})
  ) :: Omni.Provider.headers()
  defp header(headers, opts, key, pusher) do
    case Keyword.get(opts, key) do
      val when val not in [false, nil] ->
        {header_name, header_val} = pusher.(val)
        Map.put(headers, header_name, header_val)
      _ ->
        headers
    end
  end

  @impl true
  def parse_stream(data) do
    chunks =
      Regex.scan(~r/data:\s*({.+})\n/, data)
      |> Enum.reject(fn [_, data] -> data == "[DONE]" end)
      |> Enum.map(fn [_, data] -> Jason.decode!(data) end)

    {:cont, chunks}
  end

  @impl true
  def merge_stream("", data) do
    update_in(data, ["choices"], fn choices ->
      Enum.map(choices, fn %{"delta" => message} = choice ->
        choice
        |> Map.delete("delta")
        |> Map.put("message", message)
      end)
    end)
  end

  def merge_stream(body, data) do
    Map.merge(body, data, fn
      "choices", prev, next ->
        # This code is a little hairy but it handles the scenario where n > 1 and multiple
        # choices are returned in a stream. This code handles them coming out of order.
        choices = Enum.reduce(next, prev, fn %{"index" => index, "delta" => message} = choice, choices ->
          # Rename delta key
          choice =
            choice
            |> Map.delete("delta")
            |> Map.put("message", message)

          # As chunks come out of order, the real index may not be the supposed index
          # If we havne't seen the choice before, we just insert an empty map at index 0
          {choices, index} = case Enum.find_index(choices, & &1["index"] == index) do
            nil -> {[%{} | choices], 0}
            i -> {choices, i}
          end

          # Update the list of choices at our known real index
          List.update_at(choices, index, fn src ->
            Map.merge(src, choice, fn
              "message", m1, m2 ->
                Map.merge(m1, m2, fn
                  "content", c1, c2 -> c1 <> c2
                  _key, _a, b -> b
                end)
              _key, _a, b -> b
            end)
          end)
        end)

        # Finally sort by index so ordering is nmormalised
        Enum.sort_by(choices, & &1["index"])

      _key, _prev, next -> next
    end)
  end

end
