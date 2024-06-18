defmodule Omni.Providers.OllamaGen do
  @moduledoc """
  An alternative Provider implementation for [Ollama](https://ollama.com/), using the
  [Ollama Completion API](https://github.com/ollama/ollama/blob/main/docs/api.md#generate-a-completion).
  This Provider is preferred when you need fine grained control over the prompt
  templates, that isn't possible using the normal chat API.

  This Provider extends tha `Omni.Providers.Ollama` Provider, and so the [base URL](`Omni.Providers.Ollama#module-base-url`)
  can be configured in the same way.
  """
  use Omni.Provider

  extends Omni.Providers.Ollama, except: [:endpoint, :stream_endpoint, :schema, :merge_stream]

  endpoint "/generate"
  stream_endpoint "/generate", stream: true

  schema [
    model: [
      type: :string,
      required: true,
      doc: "The ollama model name.",
    ],
    prompt: [
      type: :string,
      required: true,
      doc: "Prompt to generate a response for.",
    ],
    images: [
      type: {:list, :string},
      doc: "A list of Base64 encoded images to be included with the prompt (for multimodal models only).",
    ],
    system: [
      type: :string,
      doc: "System prompt, overriding the model default.",
    ],
    template: [
      type: :string,
      doc: "Prompt template, overriding the model default.",
    ],
    context: [
      type: {:list, {:or, [:integer, :float]}},
      doc: "The context parameter returned from a previous call (enabling short conversational memory).",
    ],
    format: [
      type: :string,
      doc: "Set the expected format of the response (`json`).",
    ],
    raw: [
      type: :boolean,
      doc: "Set `true` if specifying a fully templated prompt. (`:template` is ingored)",
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
  def merge_stream("", data), do: merge_stream(%{}, data)
  def merge_stream(body, data) do
    Map.merge(body, data, fn
      "response", prev, next -> prev <> next
      _key, _prev, next -> next
    end)
  end

end
