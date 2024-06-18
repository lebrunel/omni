defmodule MockPlug do
  import Plug.Conn
  @behaviour Plug

  def wrap(%Omni.Provider{} = provider) do
    update_in(provider.req, & Req.merge(&1, plug: __MODULE__))
  end

  def init(opts), do: opts

  def call(conn, _opts) do
    opts = Plug.Parsers.init(parsers: [:json], json_decoder: Jason)
    conn = Plug.Parsers.call(conn, opts)

    case conn do
      %{params: %{"stream" => true}} = conn ->
        mock_stream(conn, conn.params)
      %{query_params: %{"alt" => "sse"}} = conn ->
        mock_stream(conn, conn.params)

      conn ->
        mock_request(conn, conn.params)
    end
  end

  # Mock blocking requests
  defp mock_request(%{host: "api.anthropic.com"} = conn, _params) do
    response =
      conn
      |> mock_response("Here is a haiku about the Greek Gods:\n\nMighty pantheon\nOlympian deities reign\nImmortal power")
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  defp mock_request(%{host: "api.openai.com"} = conn, _params) do
    response =
      conn
      |> mock_response("Mount Olympus stands,\nImmortal whispers echo—\nZeus reigns, thunder roars.")
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  defp mock_request(%{host: "generativelanguage.googleapis.com"} = conn, _params) do
    response =
      conn
      |> mock_response("Olympus' peak shines,\nGods with power, love, and wrath,\nMortals fear their gaze. \n")
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  defp mock_request(%{host: "localhost", request_path: "/api/chat"} = conn, _params) do
    response =
      conn
      |> mock_response("Here is a haiku about the Greek Gods:\n\nOlympus' grandeur\nZeus' thunderbolt crashes\nGods' eternal reign")
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end

  defp mock_request(%{host: "localhost", request_path: "/api/generate"} = conn, _params) do
    response =
      conn
      |> mock_response("Olympus' throne high\nZeus' lightning bolts strike fear\nMortal fate's grasp")
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, response)
  end


  # Mock stream requests
  defp mock_stream(%{host: "api.anthropic.com"} = conn, _params) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    conn
    |> mock_response_stream("Here is a haiku about the Greek Gods:\n\nMighty pantheon\nOlympian deities reign\nImmortal power")
    |> Enum.map(& "event: #{&1["type"]}\ndata: #{Jason.encode!(&1)}\n")
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, chunk)
      conn
    end)
  end

  defp mock_stream(%{host: "api.openai.com"} = conn, _params) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    conn
    |> mock_response_stream("Mount Olympus stands,\nImmortal whispers echo—\nZeus reigns, thunder roars.")
    |> Enum.map(& "data: #{Jason.encode!(&1)}\n")
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, chunk)
      conn
    end)
  end

  defp mock_stream(%{host: "generativelanguage.googleapis.com"} = conn, _params) do
    conn =
      conn
      |> put_resp_content_type("text/event-stream")
      |> send_chunked(200)

    conn
    |> mock_response_stream("Olympus' peak shines,\nGods with power, love, and wrath,\nMortals fear their gaze. \n")
    |> Enum.map(& "data: #{Jason.encode!(&1)}\n\n")
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, chunk)
      conn
    end)
  end

  defp mock_stream(%{host: "localhost", request_path: "/api/chat"} = conn, _params) do
    conn =
      conn
      |> put_resp_content_type("application/json")
      |> send_chunked(200)

    conn
    |> mock_response_stream("Here is a haiku about the Greek Gods:\n\nOlympus' grandeur\nZeus' thunderbolt crashes\nGods' eternal reign")
    |> Enum.map(&Jason.encode!/1)
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, chunk)
      conn
    end)
  end

  defp mock_stream(%{host: "localhost", request_path: "/api/generate"} = conn, _params) do
    conn =
      conn
      |> put_resp_content_type("application/json")
      |> send_chunked(200)

    conn
    |> mock_response_stream("Olympus' throne high\nZeus' lightning bolts strike fear\nMortal fate's grasp")
    |> Enum.map(&Jason.encode!/1)
    |> Enum.reduce(conn, fn chunk, conn ->
      {:ok, conn} = chunk(conn, chunk)
      conn
    end)
  end


  defp mock_response(%{host: "api.anthropic.com"}, text) do
    %{
      "content" => [%{"type" => "text", "text" => text}],
      "id" => "msg_01CGYTkwbg7Fd5utcvCs4J9S",
      "model" => "claude-3-haiku-20240307",
      "role" => "assistant",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{"input_tokens" => 15, "output_tokens" => 30}
    }
  end

  defp mock_response(%{host: "api.openai.com"}, text) do
    %{
      "choices" => [
        %{
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => text,
            "role" => "assistant"
          }
        }
      ],
      "created" => 1717023160,
      "id" => "chatcmpl-9UMRszNLvf5J5Qh9fWDJFSf0sdtR4",
      "model" => "gpt-4o-2024-05-13",
      "object" => "chat.completion",
      "system_fingerprint" => "fp_319be4768e",
      "usage" => %{
        "completion_tokens" => 18,
        "prompt_tokens" => 15,
        "total_tokens" => 33
      }
    }
  end

  defp mock_response(%{host: "generativelanguage.googleapis.com"}, text) do
    %{
      "candidates" => [
        %{
          "content" => %{
            "parts" => [
              %{
                "text" => text
              }
            ],
            "role" => "model"
          },
          "finishReason" => "STOP",
          "index" => 0,
          "safetyRatings" => [
            %{
              "category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT",
              "probability" => "NEGLIGIBLE"
            },
            %{
              "category" => "HARM_CATEGORY_HATE_SPEECH",
              "probability" => "NEGLIGIBLE"
            },
            %{
              "category" => "HARM_CATEGORY_HARASSMENT",
              "probability" => "NEGLIGIBLE"
            },
            %{
              "category" => "HARM_CATEGORY_DANGEROUS_CONTENT",
              "probability" => "NEGLIGIBLE"
            }
          ]
        }
      ],
      "usageMetadata" => %{
        "candidatesTokenCount" => 23,
        "promptTokenCount" => 8,
        "totalTokenCount" => 31
      }
    }
  end

  defp mock_response(%{host: "localhost", request_path: "/api/chat"}, text) do
    %{
      "created_at" => "2024-06-13T16:49:56.579997Z",
      "done" => true,
      "done_reason" => "stop",
      "eval_count" => 30,
      "eval_duration" => 1003146000,
      "load_duration" => 2041963666,
      "message" => %{"role" => "assistant", "content" => text},
      "model" => "llama3",
      "prompt_eval_count" => 17,
      "prompt_eval_duration" => 159021000,
      "total_duration" => 3206330833
    }
  end

  defp mock_response(%{host: "localhost", request_path: "/api/generate"}, text) do
    %{
      "context" => [128006, 882, 128007, 271, 8144, 264, 6520, 39342, 922, 279,
        18341, 44875, 128009, 128006, 78191, 128007, 271, 46, 14163, 355, 6,
        44721, 1579, 198, 60562, 355, 6, 33538, 49939, 13471, 8850, 198, 44,
        34472, 25382, 596, 34477, 128009],
      "created_at" => "2024-06-14T09:03:10.948386Z",
      "done" => true,
      "done_reason" => "stop",
      "eval_count" => 21,
      "eval_duration" => 695401000,
      "load_duration" => 8054914542,
      "model" => "llama3",
      "prompt_eval_count" => 17,
      "prompt_eval_duration" => 153638000,
      "response" => text,
      "total_duration" => 8909485584
    }
  end


  defp mock_response_stream(%{host: "api.openai.com"} = conn, text) do
    res = mock_response(conn, text)
    base = Map.take(res, ["created", "id", "model", "object", "system_fingerprint"])
    choice = %{"finish_reason" => nil, "index" => 0, "logprobs" => nil}

    content_blocks =
      text
      |> String.codepoints()
      |> Enum.chunk_every(5)
      |> Enum.map(&Enum.join/1)
      |> Enum.map(& Map.put(base, "choices", [Map.put(choice, "delta", %{"content" => &1})]))

    content_blocks
    |> List.insert_at(0, Map.put(base, "choices", [Map.put(choice, "delta", %{"role" => "assistant", "content" => ""})]))
    |> List.insert_at(-1, Map.put(base, "choices", [Map.merge(choice, %{"delta" => %{}, "finish_reason" => "stop"})]))
  end

  defp mock_response_stream(%{host: "api.anthropic.com"} = conn, text) do
    res = mock_response(conn, text)
    content_blocks =
      text
      |> String.codepoints()
      |> Enum.chunk_every(5)
      |> Enum.map(&Enum.join/1)
      |> Enum.map(& %{"type" => "content_block_delta", "index" => 0, "delta" => %{"type" => "text_delta", "text" => &1}})

    [
      %{"type" => "message_start", "message" => Map.merge(res, %{"content" => [], "stop_reason" => nil, "stop_sequence" => nil})},
      %{"type" => "content_block_start", "index" => 0, "content_block" => %{"type" => "text", "text" => ""}}
      | content_blocks
    ] ++ [
      %{"type" => "content_block_stop", "index" => 0},
      %{"type" => "message_delta", "delta" => Map.take(res, ["stop_reason", "stop_sequence", "usage"])},
      %{"type" => "message_stop"},
    ]
  end

  defp mock_response_stream(%{host: "generativelanguage.googleapis.com"} = conn, text) do
    res = mock_response(conn, text)
    text
    |> String.codepoints()
    |> Enum.chunk_every(5)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(fn text ->
      Map.update!(res, "candidates", fn candidates ->
        List.update_at(candidates, 0, & put_in(&1, ["content", "parts"], [%{"text" => text}]))
      end)
    end)
  end

  defp mock_response_stream(%{host: "localhost", request_path: "/api/chat"} = conn, text) do
    res = mock_response(conn, text)
    text
    |> String.codepoints()
    |> Enum.chunk_every(5)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(fn text ->
      res
      |> Map.take(["model", "created_at"])
      |> Map.put("done", false)
      |> Map.put("message", Map.put(res["message"], "content", text))
    end)
    |> List.insert_at(-1, Map.delete(res, "message"))
  end

  defp mock_response_stream(%{host: "localhost", request_path: "/api/generate"} = conn, text) do
    res = mock_response(conn, text)
    text
    |> String.codepoints()
    |> Enum.chunk_every(5)
    |> Enum.map(&Enum.join/1)
    |> Enum.map(fn text ->
      res
      |> Map.take(["model", "created_at"])
      |> Map.put("response", text)
      |> Map.put("done", false)
    end)
    |> List.insert_at(-1, Map.delete(res, "response"))
  end
end
