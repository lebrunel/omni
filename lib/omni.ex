defmodule Omni do
  @version Keyword.fetch!(Mix.Project.config(), :version)
  @moduledoc """
  ![Omni](https://raw.githubusercontent.com/lebrunel/omni/main/media/poster.png)

  ![License](https://img.shields.io/github/license/lebrunel/omni?color=informational)

  Omni focusses on one thing only - being a chat interface to *any* LLM provider.
  If you want a full featured client for a specific provider, supporting all
  available API endpoints, this is probably not it. If you want a single client
  to generate chat completions with literally any LLM backend, Omni is for you.

  - 🧩 `Omni.Provider` behaviour to create integrations with any LLM provider.
  Built-in providers for:
    - [`Anthropic`](`Omni.Providers.Anthropic`) - chat with any of of the Claude models.
    - [`Google`](`Omni.Providers.Google`) - chat with any of of the Gemini models.
    - [`Ollama`](`Omni.Providers.Ollama`) - use Ollama to chat with any local model.
    - [`OpenAI`](`Omni.Providers.OpenAI`) - chat with ChatGPT or **any** other OpenAI compatible API.
  - 🛜 Streaming API requests
    - Stream to an Enumerable
    - Or stream messages to any Elixir process
  - 💫 Simple to use and easily customisable

  ## Installation

  The package can be installed by adding `omni` to your list of dependencies
  in `mix.exs`.

  ```elixir
  def deps do
    [
      {:omni, "#{@version}"}
    ]
  end
  ```
  ## Quickstart

  To chat with an LLM, initialize a [`t:provider/0`](`t:Omni.Provider.t/0`) with
  `init/2`, and then send a [`t:request/0`](`t:Omni.Provider.request/0`), using
  one of `generate/2`, `async/2` or `stream/2`. Refer to the schema
  documentation for each provider to ensure you construct a valid request.

  ```elixir
  iex> provider = Omni.init(:openai)
  iex> Omni.generate(provider, model: "gpt-4o", messages: [
  ...>   %{role: "user", content: "Write a haiku about the Greek Gods"}
  ...> ])
  {:ok, %{"object" => "chat.completion", "choices" => [...]}}
  ```

  ## Streaming

  Omni supports streaming request through `async/2` or `stream/2`.

  Calling `async/2` returns a `t:Task.t/0`, which asynchronously sends text
  delta messages to the calling process. Using the `:stream_to` request option
  allows you to control the receiving process.

  The example below demonstrates making a streaming request in a LiveView event,
  and sends each of the streaming messages back to the same LiveView process.

  ```elixir
  defmodule MyApp.ChatLive do
    use Phoenix.LiveView

    # When the client invokes the "prompt" event, create a streaming request and
    # asynchronously send messages back to self.
    def handle_event("prompt", %{"message" => prompt}, socket) do
      {:ok, task} = Omni.async(Omni.init(:openai), [
        model: "gpt-4o",
        messages: [
          %{role: "user", content: "Write a haiku about the Greek Gods"}
        ]
      ])

      {:noreply, assign(socket, current_request: task)}
    end

    # The streaming request sends messages back to the LiveView process.
    def handle_info({_request_pid, {:data, _data}} = message, socket) do
      pid = socket.assigns.current_request.pid
      case message do
        {:omni, ^pid, {:chunk, %{"choices" => choices, "finish_reason" => nil}}} ->
          # handle each streaming chunk

        {:omni, ^pid, {:chunk, %{"choices" => choices}}} ->
          # handle the final streaming chunk
      end
    end

    # Tidy up when the request is finished
    def handle_info({ref, {:ok, _response}}, socket) do
      Process.demonitor(ref, [:flush])
      {:noreply, assign(socket, current_request: nil)}
    end
  end
  ```

  Alternatively, use `stream/2` to collect the streaming responses into an
  `t:Enumerable.t/0` that can be used with Elixir's `Stream` functions.

  ```elixir
  iex> provider = Omni.init(:openai)
  iex> {:ok, stream} = Omni.stream(provider, model: "gpt-4o", messages: [
  ...>   %{role: "user", content: "Write a haiku about the Greek Gods"}
  ...> ])

  iex> stream
  ...> |> Stream.each(&IO.inspect/1)
  ...> |> Stream.run()
  ```

  Because this function builds the `t:Enumerable.t/0` by calling `receive/1`,
  take care using `stream/2` inside `GenServer` callbacks as it may cause the
  GenServer to misbehave.
  """
  alias Omni.{APIError, Provider}

  defdelegate init(provider, opts \\ []), to: Provider

  @doc """
  Asynchronously generates a chat completion using the given [`t:provider/0`](`t:Omni.Provider.t/0`)
  and [`t:request/0`](`t:Omni.Provider.request/0`). Returns a `t:Task.t/0`.

  Within your code, you should manually define a `receive/1` block (or setup
  `c:GenServer.handle_info/2` callbacks) to receive the message stream.

  ## Additional request options

  In addition to the [`t:request/0`](`t:Omni.Provider.request/0`) options for
  the given [`t:provider/0`](`t:Omni.Provider.t/0`), this function accepts the
  following options:

  - `:stream-to` - Pass a `t:pid/0` to control the receiving process.

  ## Example

  ```elixir
  iex> provider = Omni.init(:openai)
  iex> Omni.async(provider, model: "gpt-4o", messages: [
    %{role: "user", content: "Write a haiku about the Greek Gods"}
  ])
  {:ok, %Task{pid: pid, ref: ref}}

  # Somewhere in your code
  receive do
    {:omni, ^pid, {:chunk, chunk}} ->  # handle chunk
    {^ref, {:ok, res}} ->              # handle final response
    {^ref, {:error, error}} ->         # handle error
    {:DOWN, _ref, _, _pid, _reason} -> # handle DOWN signal
  end
  ```
  """
  @spec async(Provider.t(), Provider.request()) ::
    {:ok, Task.t()} |
    {:error, term()}
  def async(%Provider{mod: mod, req: req}, opts) do
    {local_opts, opts} = Keyword.split(opts, [:stream_to])
    pid = Keyword.get(local_opts, :stream_to, self())

    with {:ok, opts} <- NimbleOptions.validate(opts, apply(mod, :schema, [])),
         {url, defaults} <- apply(mod, :stream_endpoint, [opts])
    do
      {:ok, Task.async(fn ->
        body = apply(mod, :body, [Keyword.merge(opts, defaults)])
        request(req, url, body, into: collect(mod, pid))
      end)}
    end
  end

  @doc """
  As `async/2` but raises in the case of an error.
  """
  @spec async!(Provider.t(), Provider.request()) :: Task.t()
  def async!(%Provider{} = provider, opts) do
    case async(provider, opts) do
      {:ok, task} -> task
      {:error, err} -> raise err
    end
  end

  @doc """
  Generates a chat completion using the given [`t:provider/0`](`t:Omni.Provider.t/0`)
  and [`t:request/0`](`t:Omni.Provider.request/0`). Synchronously returns a
  [`t:response/0`](`t:Omni.Provider.response/0`).

  ## Example

  ```elixir
  iex> provider = Omni.init(:openai)
  iex> Omni.generate(provider, model: "gpt-4o", messages: [
    %{role: "user", content: "Write a haiku about the Greek Gods"}
  ])
  {:ok, %{"message" => %{
    "content" => "Mount Olympus stands,\\nImmortal whispers echo—\\nZeus reigns, thunder roars."
  }}}
  ```
  """
  @spec generate(Provider.t(), Provider.request()) ::
    {:ok, Provider.response()} |
    {:error, term()}
  def generate(%Provider{mod: mod, req: req}, opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, apply(mod, :schema, [])),
         {url, defaults} <- apply(mod, :endpoint, [opts])
    do
      body = apply(mod, :body, [Keyword.merge(opts, defaults)])
      request(req, url, body)
    end
  end

  @doc """
  As `generate/2` but raises in the case of an error.
  """
  @spec generate!(Provider.t(), Provider.request()) :: Provider.response()
  def generate!(%Provider{} = provider, opts) do
    case generate(provider, opts) do
      {:ok, resp} -> resp
      {:error, err} -> raise err
    end
  end

  @doc """
  Asynchronously generates a chat completion using the given [`t:provider/0`](`t:Omni.Provider.t/0`)
  and [`t:request/0`](`t:Omni.Provider.request/0`). Returns an `t:Enumerable.t/0`.

  Because this function builds the `t:Enumerable.t/0` by calling `receive/1`,
  using this function inside `GenServer` callbacks may cause the GenServer to
  misbehave. In such cases, use `async/2` instead.

  ## Example

  ```elixir
  iex> provider = Omni.init(:openai)
  iex> {:ok, stream} = Omni.stream(provider, model: "gpt-4o", messages: [
    %{role: "user", content: "Write a haiku about the Greek Gods"}
  ])

  iex> stream
  ...> |> Stream.each(&IO.inspect/1)
  ...> |> Stream.run()
  ```
  """
  @spec stream(Provider.t(), Provider.request()) ::
    {:ok, Enumerable.t()} |
    {:error, term()}
  def stream(%Provider{mod: mod, req: req}, opts) do
    with {:ok, opts} <- NimbleOptions.validate(opts, apply(mod, :schema, [])),
         {url, defaults} <- apply(mod, :stream_endpoint, [opts])
    do
      {:ok, Stream.resource(
        fn ->
          pid = self()
          Task.async(fn ->
            body = apply(mod, :body, [Keyword.merge(opts, defaults)])
            request(req, url, body, into: collect(mod, pid))
          end)
        end,
        fn %Task{pid: pid, ref: ref} = task ->
          receive do
            {:omni, ^pid, {:chunk, chunk}} ->
              {[chunk], task}

            {^ref, {:ok, _res}} ->
              {:halt, task}

            {^ref, {:error, error}} ->
              raise error

            {:DOWN, _ref, _, _pid, _reason} ->
              {:halt, task}

          after
            30_000 -> {:halt, task}
          end
        end,
        fn %Task{ref: ref} -> Process.demonitor(ref, [:flush]) end
      )}
    end
  end

  @doc """
  As `stream/2` but raises in the case of an error.
  """
  @spec stream!(Provider.t(), Provider.request()) :: Enum.t()
  def stream!(%Provider{} = provider, opts) do
    case stream(provider, opts) do
      {:ok, resp} -> resp
      {:error, err} -> raise err
    end
  end

  # Makes an HTTP request and returns a response or an error.
  @spec request(Req.Request.t(), String.t(), map(), keyword()) ::
    {:ok, Provider.response()} |
    {:error, term()}
  defp request(%Req.Request{} = req, url, body, opts \\ []) do
    with {:ok, resp} <- Req.request(req, Keyword.merge(opts, url: url, json: body)) do
      case resp do
        %Req.Response{status: status, body: body} when status in 200..299 ->
          {:ok, body}
        %Req.Response{status: status, body: body} ->
          {:error, APIError.exception(status: status, error: body["error"])}
      end
    end
  end

  # Returns a function to collect streaming response
  defp collect(mod, pid) do
    fn {:data, data}, {req, res} ->
      {signal, chunks} = apply(mod, :parse_stream, [data])
      res = Enum.reduce(chunks, res, fn chunk, res ->
        send(pid, {:omni, self(), {:chunk, chunk}})
        body = apply(mod, :merge_stream, [res.body, chunk])
        put_in(res.body, body)
      end)
      {signal, {req, res}}
    end
  end

end
