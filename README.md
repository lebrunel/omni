# Omni

![Hex.pm](https://img.shields.io/hexpm/v/omni?color=informational)
![License](https://img.shields.io/github/license/lebrunel/omni?color=informational)
![Build Status](https://img.shields.io/github/actions/workflow/status/lebrunel/omni/elixir.yml?branch=main)

Omni focusses on one thing only - being a chat interface to *any* LLM provider. If you want a full featured client for a specific provider, supporting all available API endpoints, this is probably not it. If you want a single client to generate chat completions with literally any LLM backend, Omni is for you.

- 🧩 `Omni.Provider` behaviour to create integrations with any LLM provider. Built-in providers for:
  - [`Anthropic`](`Omni.Providers.Anthropic`) - chat with any of of the Claude models.
  - [`Google`](`Omni.Providers.Google`) - chat with any of of the Gemini models.
  - [`Ollama`](`Omni.Providers.Ollama`) - use Ollama to chat with any local model.
  - [`OpenAI`](`Omni.Providers.OpenAI`) - configurable with any other OpenAI compatible chat API.
- 🛜 Streaming API requests
  - Stream to an Enumerable
  - Or stream messages to any Elixir process
- 💫 Simple to use and easily customisable

## Installation

The package can be installed by adding `omni` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:omni, "#{@version}"}
  ]
end
```

## Quickstart

To chat with an LLM, initialize a `t:provider/0` with `init/2`, and then send a `t:request/0`, using one of `generate/2`, `async/2` or `stream/2`. Refer to the schema documentation for each provider to ensure you construct a valid request.

```elixir
iex> provider = Omni.init(:openai)
iex> Omni.generate(provider, model: "gpt-4o", messages: [
...>   %{role: "user", content: "Write a haiku about the Greek Gods"}
...> ])
{:ok, %{"object" => "chat.completion", "choices" => [...]}}
```

## Streaming

Omni supports streaming request through `async/2` or `stream/2`.

Calling `async/2` returns a `t:Task.t/0`, which asynchronously sends text delta messages to the calling process. Using the `:stream_to` request option allows you to control the receiving process.

The example below demonstrates making a streaming request in a LiveView event, and sends each of the streaming messages back to the same LiveView process.

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

Alternatively, use `stream/2` to collect the streaming responses into an `t:Enumerable.t/0` that can be used with Elixir's `Stream` functions.

```elixir
iex> provider = Omni.init(:openai)
iex> {:ok, stream} = Omni.stream(provider, model: "gpt-4o", messages: [
...>   %{role: "user", content: "Write a haiku about the Greek Gods"}
...> ])

iex> stream
...> |> Stream.each(&IO.inspect/1)
...> |> Stream.run()
```

Because this function builds the `t:Enumerable.t/0` by calling `receive/1`, take care using `stream/2` inside `GenServer` callbacks as it may cause the GenServer to misbehave.

## License

This package is open source and released under the [Apache-2 License](https://github.com/lebrunel/omni/blob/master/LICENSE).

© Copyright 2024 [Push Code Ltd](https://www.pushcode.com/).