defmodule Omni.Providers.Google do
  @moduledoc """
  Provider implementation for the [Google Gemini API](https://ai.google.dev/gemini-api/docs).
  Use this Provider to chat with any of the Gemini models.

  ## Authorization

  Obtain an API key from the [Google AI Studio](https://aistudio.google.com)
  and add it to your application's `config.exs`:

  ```elixir
  config :omni, Omni.Providers.Google, "NotaRealKey"
  ```

  Alternatively, pass the API key to `Onmi.init/2`:

  ```elixir
  iex> Omni.init(:google, api_key: api_key)
  %Omni.Provider{mod: Omni.Providers.Google, req: %Req.Request{}}
  ```
  """
  use Omni.Provider

  @api_key Application.compile_env(:omni, [__MODULE__, :api_key])

  @function_calling_mode [
    "AUTO",	                            # Default, model decides to predict either a function call or a natural language response.
    "ANY",	                            # Model is constrained to always predicting a function call only.
    "NONE",	                            # Model will not predict any function call.
  ]

  @harm_category [
    "HARM_CATEGORY_UNSPECIFIED",	      # Category is unspecified.
    "HARM_CATEGORY_DEROGATORY",	        # Negative or harmful comments targeting identity and/or protected attribute.
    "HARM_CATEGORY_TOXICITY",	          # Content that is rude, disrespectful, or profane.
    "HARM_CATEGORY_VIOLENCE",	          # Describes scenarios depicting violence against an individual or group, or general descriptions of gore.
    "HARM_CATEGORY_SEXUAL",	            # Contains references to sexual acts or other lewd content.
    "HARM_CATEGORY_MEDICAL",	          # Promotes unchecked medical advice.
    "HARM_CATEGORY_DANGEROUS",	        # Dangerous content that promotes, facilitates, or encourages harmful acts.
    "HARM_CATEGORY_HARASSMENT",	        # Harasment content.
    "HARM_CATEGORY_HATE_SPEECH",	      # Hate speech and content.
    "HARM_CATEGORY_SEXUALLY_EXPLICIT",  # Sexually explicit content.
    "HARM_CATEGORY_DANGEROUS_CONTENT",
  ]

  @harm_threshold [
    "HARM_BLOCK_THRESHOLD_UNSPECIFIED", # Threshold is unspecified.
    "BLOCK_LOW_AND_ABOVE", 	            # Content with NEGLIGIBLE will be allowed.
    "BLOCK_MEDIUM_AND_ABOVE", 	        # Content with NEGLIGIBLE and LOW will be allowed.
    "BLOCK_ONLY_HIGH", 	                # Content with NEGLIGIBLE, LOW, and MEDIUM will be allowed.
    "BLOCK_NONE", 	                    # All content will be allowed.
  ]

  base_url "https://generativelanguage.googleapis.com/v1beta"

  schema [
    model: [
      type: :string,
      required: true,
      doc: "Name of the model to use.",
    ],
    contents: [
      type: {:list, {:map, [
        role: [
          type: {:in, ["model", "user"]},
          required: true,
          doc: "The producer of the content.",
        ],
        parts: [
          type: {:list, {:map, [
            text: [type: :string, doc: "Inline text."],
            inline_data: [
              type: :map,
              keys: [
                mime_type: [type: :string, required: true, doc: "The IANA standard MIME type of the source data."],
                data: [type: :string, required: true, doc: "Base64-encoded raw bytes."],
              ],
              doc: "Inline media bytes.",
            ],
            file_data: [
              type: :map,
              keys: [
                mime_type: [type: :string, doc: "The IANA standard MIME type of the source data."],
                file_uri: [type: :string, required: true, doc: "File URI."],
              ],
              doc: "URI based data.",
            ],
            function_call: [
              type: :map,
              keys: [
                name: [type: :string, required: true, doc: "The name of the function to call."],
                args: [type: :map, doc: "The function parameters and values in JSON object format."],
              ],
              doc: "A predicted FunctionCall returned from the model.",
            ],
            function_response: [
              type: :map,
              keys: [
                name: [type: :string, required: true, doc: "The name of the function called."],
                response: [type: :map, required: true, doc: "The function response in JSON object format."],
              ],
              doc: "The result output of a FunctionCall.",
            ]
          ]}},
          required: true,
          doc: "Ordered Parts that constitute a single message.",
        ]
      ]}},
      required: true,
      doc: "The base structured datatype containing multi-part content of a message.",
    ],
    system: [
      type: :map,
      keys: [
        text: [
          type: :string,
          required: true,
          doc: "System text.",
        ],
      ],
      doc: "Developer set system instruction."
    ],
    tools: [
      type: {:list, {:map, [
        function_declarations: [
          type: {:list, {:map, [
            name: [type: :string, required: true, doc: "The name of the function."],
            description: [type: :string, required: true, doc: "A brief description of the function."],
            parameters: [type: :map, doc: "Describes the parameters to this function."],
          ]}},
          doc: "A list of FunctionDeclarations available to the model that can be used for function calling.",
        ]
      ]}},
      doc: "A list of Tools the model may use to generate the next response.",
    ],
    tool_config: [
      type: :map,
      keys: [
        function_calling_config: [
          type: :map,
          keys: [
            mode: [
              type: {:in, @function_calling_mode},
              doc: "Specifies the mode in which function calling should execute.",
            ],
            allowed_function_names: [
              type: {:list, :string},
              doc: "A set of function names that, when provided, limits the functions the model will call.",
            ]
          ],
          doc: "Function calling config.",
        ]
      ],
      doc: "Tool configuration for any Tool specified in the request.",
    ],
    generation: [
      type: :map,
      keys: [
        stop_sequences: [
          type: {:list, :string},
          doc: "Set of character sequences that will stop output generation.",
        ],
        response_mime_type: [
          type: {:in, ["text/plain", "application/json"]},
          doc: "Output response mimetype of the generated candidate text.",
        ],
        response_schema: [
          type: :map, # todo - expand this
          doc: "Output response schema of the generated candidate text.",
        ],
        candidate_count: [
          type: :integer,
          doc: "Number of generated responses to return.",
        ],
        max_output_tokens: [
          type: :integer,
          doc: "The maximum number of tokens to include in a candidate.",
        ],
        temperature: [
          type: :float,
          doc: "Controls the randomness of the output. Between 0.0 and 2.0.",
        ],
        top_p: [
          type: :float,
          doc: "The maximum cumulative probability of tokens to consider when sampling.",
        ],
        top_k: [
          type: :integer,
          doc: "The maximum number of tokens to consider when sampling.",
        ]
      ],
      doc: "Configuration options for model generation and outputs.",
    ],
    safety: [
      type: {:list, {:map, [
        category: [
          type: {:in, @harm_category},
          required: true,
          doc: "The category for this setting.",
        ],
        threshold: [
          type: {:in, @harm_threshold},
          required: true,
          doc: "Controls the probability threshold at which harm is blocked.",
        ],
      ]}},
      doc: "A list of unique SafetySetting instances for blocking unsafe content.",
    ]
  ]

  @impl true
  def endpoint(opts) do
    model = Keyword.fetch!(opts, :model)
    {"/models/#{model}:generateContent", []}
  end

  @impl true
  def stream_endpoint(opts) do
    model = Keyword.fetch!(opts, :model)
    {"/models/#{model}:streamGenerateContent?alt=sse", []}
  end

  @impl true
  def headers(opts) do
    headers = %{content_type: "application/json"}

    case Keyword.get(opts, :api_key, @api_key) do
      key when is_binary(key) ->
        Map.put(headers, :x_goog_api_key, key)
      _ ->
        headers
    end
  end

  @impl true
  def body(opts) do
    opts
    |> Keyword.take([:contents, :tools, :tool_config])
    |> push_if(Keyword.get(opts, :system), & {:system_instruction, &1})
    |> push_if(Keyword.get(opts, :safety), & {:safety_settings, &1})
    |> push_if(Keyword.get(opts, :generation), & {:generation_config, &1})
    |> Enum.into(%{})
    |> Recase.Enumerable.stringify_keys(&Recase.to_camel/1)
  end

  @impl true
  def parse_stream(data) do
    chunks =
      Regex.scan(~r/data:\s*({.+})(?:\n\n|\r\r|\r\n\r\n)/, data)
      |> Enum.map(fn [_, data] -> Jason.decode!(data) end)
    {:cont, chunks}
  end

  @impl true
  def merge_stream("", data), do: data
  def merge_stream(body, data) do
    Map.merge(body, data, fn
      "candidates", prev, next ->
        choices = Enum.reduce(next, prev, fn %{"index" => index} = choice, choices ->
          # As chunks come out of order, the real index may not be the supposed index
          # If we havne't seen the choice before, we just insert an empty map at index 0
          {choices, index} = case Enum.find_index(choices, & &1["index"] == index) do
            nil -> {[%{} | choices], 0}
            i -> {choices, i}
          end

          # Update the list of choices at our known real index
          List.update_at(choices, index, fn src ->

            update_in(choice, ["content", "parts"], fn parts ->
              src
              |> get_in(["content", "parts"])
              |> Enum.concat(parts)
              |> Enum.reduce([], fn part, parts ->
                [{key, val}] = Enum.into(part, [])
                case Enum.find_index(parts, & Map.has_key?(&1, key)) do
                  nil -> List.insert_at(parts, -1, part)
                  i ->
                    List.update_at(parts, i, fn existing ->
                      Map.update!(existing, key, & &1 <> val)
                    end)
                end
              end)
            end)
          end)
        end)

        # Finally sort by index so ordering is nmormalised
        Enum.sort_by(choices, & &1["index"])

      _key, _prev, next -> next
    end)
  end

end
