defmodule Omni.Provider do
  @moduledoc """
  A Provider represents an LLM provider service. By fully implementing the
  Provider behaviour, a module can be made to support any LLM backend available.

  Out of the box, Omni ships Providers for:

  - [`Anthropic`](`Omni.Providers.Anthropic`) - chat with any of of the Claude models
  - [`Google`](`Omni.Providers.Google`) - chat with any of of the Gemini models
  - [`Ollama`](`Omni.Providers.Ollama`) - use Ollama to chat with any local model
  - [`OpenAI`](`Omni.Providers.OpenAI`) - configurable with any other OpenAI compatible chat API

  ## Implementing a Provider

  This module also provides a number of macros that streamline creating a
  Provider implementation. Most callbacks can be implemented simply by calling
  the relevant macro.

  ```elixir
  defmodule MyLLM do
    use Omni.Provider
    @api_key Application.compile_env(:omni, [__MODULE__, :api_key])

    # Macros

    base_url "http://localhost:1234/api"
    headers %{authorization: "Bearer \#{@api_key}"}
    endpoint "/chat"
    stream_endpoint "/chat", stream: true

    schema [
      # define NimbleOptions schema for chat request params
    ]

    # Callbacks

    @impl true
    def parse_stream(data) do
      # parse binary data stream into chunks
      {:cont, [chunks]}
    end

    @impl true
    def merge_stream(body, data) do
      # merge stream data chunks into single response
      body
    end
  end
  ```

  ## Extending a Provider

  The `extend/2` macro can be used to inherit from an already implemented
  Provider. For example, if you were implementing a LLM service that was OpenAI
  compatible, but required a different kind of authorization header.

  ```elixir
  defmodule MyLLM do
    use Omni.Provider
    @api_key Application.compile_env(:omni, [__MODULE__, :api_key])

    extends Omni.Providers.OpenAI, except: [:headers]
    headers %{x_auth_token: @api_key}
  end
  ```
  """
  @enforce_keys [:mod, :req]
  defstruct mod: nil, req: nil

  @typedoc """
  Provider struct

  Once initialized, is used to make subsequent API requests.
  """
  @type t() :: %__MODULE__{
    mod: module(),
    req: Req.Request.t()
  }

  @typedoc """
  Alt name

  Accepted aliases for the built in Provider modules.
  """
  @type alt() :: :anthropic | :google | :openai | :ollama

  @typedoc """
  Request headers

  Can be any Enumerable containing keys and values. Handled by `Req` as follows:

  - atom header names are turned into strings, replacing _ with -. For example, :user_agent becomes "user-agent".
  - string header names are downcased.
  """
  @type headers() :: Enumerable.t({atom() | String.t(), String.t() | list(String.t())})

  @typedoc """
  Initialization options.

  An arbitrary keyword list of options to initialize the Provider.
  """
  @type init_opts() :: keyword()

  @typedoc """
  An arbitrary keyword list of request options for the LLM.

  Whilst there are some similarities across providers, refer to the
  documentation for each provider to ensure you construct a valid request.
  """
  @type request() :: keyword()

  @typedoc """
  An arbitrary map representing the response from the LLM provider.

  Refer to the documentation for each provider to understand the expected
  response format.
  """
  @type response() :: map()

  @providers %{
    anthropic: Omni.Providers.Anthropic,
    google: Omni.Providers.Google,
    ollama: Omni.Providers.Ollama,
    openai: Omni.Providers.OpenAI
  }

  @provider_keys Map.keys(@providers)

  @version Keyword.fetch!(Mix.Project.config(), :version)

  @doc """
  Initializes a new instance of a Provider, using the given module or `t:alt/0`
  alias.

  Accepts a list of initialization options. Refer to the Provider module docs
  for details of the accepted options.

  ## Example

  ```elixir
  iex> Omni.Provider.init(:openai)
  %Omni.Provider{mod: Omni.Providers.OpenAI, req: %Req.Request{}}
  ```
  """
  @spec init(alt() | module(), init_opts()) :: t()
  def init(provider, opts \\ [])

  def init(alt, opts) when alt in @provider_keys,
    do: Map.get(@providers, alt) |> init(opts)

  def init(module, opts) when is_atom(module) do
    base_url = apply(module, :base_url, [opts])
    headers = apply(module, :headers, [opts])

    req =
      opts
      |> Keyword.get(:req, [])
      |> Keyword.merge(method: :post, base_url: base_url)
      |> Keyword.put_new(:receive_timeout, 60_000)
      |> Req.new()
      |> Req.merge(headers: %{user_agent: "omni/#{@version}"})
      |> Req.merge(headers: headers)

    struct!(__MODULE__,
      mod: module,
      req: req
    )
  end

  # ===== Callbacks =====

  @doc """
  Invoked to return the Provider base URL as a string.

  For a simple implementation, prefer the `base_url/1` macro. Manually
  implementing the callback allows using the initialization options to
  dynamically generate the return value.
  """
  @callback base_url(opts :: init_opts()) :: String.t()

  @doc """
  Invoked to return the Provider request `t:headers/0`.

  For a simple implementation, prefer the `headers/1` macro. Manually
  implementing the callback allows using the initialization options to
  dynamically generate the return value.

  This callback is optional. If not implemented, the default implementaion
  returns an empty set of headers.
  """
  @callback headers(opts :: init_opts()) :: headers()

  @doc """
  Invoked to return the Provider chat endpoint and any default request options
  for that endpoint. Returns a tuple.

  For a simple implementation, prefer the `endpoint/2` macro. Manually
  implementing the callback allows using the user `t:request/0` options to
  dynamically generate the return value.
  """
  @callback endpoint(opts :: request()) :: {String.t(), request()}

  @doc """
  Invoked to return the Provider chat streaming endpoint and any default request
  options for that endpoint. Returns a tuple.

  For a simple implementation, prefer the `stream_endpoint/2` macro. Manually
  implementing the callback allows using the user `t:request/0` options to
  dynamically generate the return value.
  """
  @callback stream_endpoint(opts :: request()) :: {String.t(), request()}

  @doc """
  Invoked to return the Provider request body as a map.

  This callback is optional. If not implemented, the default implementaion
  returns the user `t:request/0` options as a `t:map/0`.
  """
  @callback body(opts :: request()) :: map()

  @doc """
  Invoked to return the Provider chat schema, used to validate the `t:request/0`
  options.

  Prefer the `schema/1` macro over a manual implementation.
  """
  @callback schema() :: NimbleOptions.t()

  @doc """
  Invoked to parse a streaming request data chunk into a list of one or more
  structured messages.

  Receives a binary data chunk.

  Returning `{:cont, messages}` emits each of the messages and continues
  streaming chunks.

  Returning `{:halt, messages}` emits each of the messages and cancels the
  streaming request.
  """
  @callback parse_stream(data :: binary()) :: {:cont, list()} | {:halt, list()}

  @doc """
  Invoked to reconstruct a streaming data chunk back into a full response body.

  Receives the response body and a single streaming message. The body should
  be returned with the message merged into it.

  This callback is optional. If not implemented, the default implementaion
  always returns the body as an empty string. If a Provider does not implement
  this callback, calling `Task.await(stream_request_task)` will return the body
  as an empty string, but will still send streaming messages to the specified
  process.
  """
  @callback merge_stream(body :: binary() | map(), data :: term()) :: map()

  # ===== Macros =====

  defmacro __using__(_) do
    quote do
      @behaviour Omni.Provider
      import Omni.Provider, only: [
        base_url: 1,
        endpoint: 1,
        endpoint: 2,
        headers: 1,
        push_if: 3,
        stream_endpoint: 1,
        stream_endpoint: 2,
        schema: 1,
        extends: 1,
        extends: 2,
      ]

      @impl true
      def body(opts), do: Enum.into(opts, %{})

      @impl true
      def headers(_opts), do: []

      @impl true
      def merge_stream(body, _data), do: body

      defoverridable body: 1, headers: 1, merge_stream: 2
    end
  end

  @doc """
  Defines the base URL for the Provider.
  """
  @spec base_url(String.t()) :: Macro.t()
  defmacro base_url(url) when is_binary(url) do
    quote do
      @impl true
      def base_url(_opts), do: unquote(url)
    end
  end

  @doc """
  Defines the request `t:headers/0` for the Provider.
  """
  @spec headers(headers()) :: Macro.t()
  defmacro headers(headers) do
    quote do
      @impl true
      def headers(_opts), do: unquote(headers)
    end
  end

  @doc """
  Defines the chat endpoint for the Provider.

  Optionally accepts list of default `t:request/0` options for this endpoint.
  """
  @spec endpoint(String.t(), request()) :: Macro.t()
  defmacro endpoint(path, opts \\ []) when is_binary(path) do
    quote do
      @impl true
      def endpoint(_opts), do: {unquote(path), unquote(opts)}
    end
  end

  @doc """
  Defines the streaming chat endpoint for the Provider.

  Optionally accepts list of default `t:request/0` options for this endpoint.
  """
  @spec stream_endpoint(String.t(), request()) :: Macro.t()
  defmacro stream_endpoint(path, opts \\ []) when is_binary(path) do
    quote do
      @impl true
      def stream_endpoint(_opts), do: {unquote(path), unquote(opts)}
    end
  end

  @doc """
  Defines the schema for the Provider `t:request/0` options.

  Schemas should be defined as a `t:NimbleOptions.schema/0`.
  """
  @spec schema(NimbleOptions.schema()) :: Macro.t()
  defmacro schema(opts) when is_list(opts) do

    quote do
      @schema NimbleOptions.new!(unquote(opts))

      @doc """
      Returns the schema for this Provider.

      ## Schema

      #{NimbleOptions.docs(@schema)}
      """
      @impl true
      def schema(), do: @schema
    end
  end

  @doc """
  Extends an existing Provider module by delegating all callbacks to the parent
  module.

  Use the `:except` option to specify which callbacks shouldn't be delegated to
  the parent, allowing you to override with a tailored implementation.
  """
  @spec extends(module(), keyword()) :: Macro.t()
  defmacro extends(mod, opts \\ []) do
    except = Keyword.get(opts, :except, [])

    delegatable = [
      base_url: 1,
      headers: 1,
      endpoint: 1,
      stream_endpoint: 1,
      body: 1,
      schema: 0,
      parse_stream: 1,
      merge_stream: 2,
    ]

    for {name, arity} <- Keyword.drop(delegatable, except) do
      args = case arity do
        0 -> []
        _ -> Enum.map(0..arity-1, & Macro.var(:"arg_#{&1}", nil))
      end
      quote do
        @impl true
        defdelegate unquote(name)(unquote_splicing(args)), to: unquote(mod)
      end
    end
  end

  @doc false
  @spec push_if(list(), term(), (term() -> term())) :: list()
  def push_if(list, val, pusher) when is_list(list) and is_function(pusher, 1) do
    unless val in [nil, false],
      do: List.insert_at(list, -1, pusher.(val)),
      else: list
  end

end
