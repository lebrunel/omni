defmodule Omni.Providers.GoogleTest do
  use ExUnit.Case, async: true
  alias Omni.Providers.Google

  describe "schema/0" do
    test "model and content is required" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", contents: []], Google.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test"], Google.schema())
      assert {:error, _} = NimbleOptions.validate([contents: []], Google.schema())
    end

    test "validates content part types" do
      # valid content parts
      assert {:ok, _} = NimbleOptions.validate([model: "test", contents: [
        %{role: "user", parts: [
          %{text: "test"},
          %{inline_data: %{mime_type: "image/png", data: "foo"}},
          %{file_data: %{mime_type: "image/png", file_uri: "http://foo"}},
        ]},
        %{role: "model", parts: [
          %{text: "test"},
          %{function_call: %{name: "test", args: %{foo: "bar"}}},
        ]},
        %{role: "user", parts: [
          %{text: "test"},
          %{function_response: %{name: "test", response: %{foo: "bar"}}},
        ]}
      ]], Google.schema())

      # invalid content and/or parts
      assert {:error, _} = NimbleOptions.validate([model: "test", contents: [
        %{foo: "bar"},
      ]], Google.schema())

      assert {:error, _} = NimbleOptions.validate([model: "test", contents: [
        %{role: "user", parts: [
          %{foo: "bar"},
        ]},
      ]], Google.schema())
    end

    test "validates tool types" do
      # valid tool
      assert {:ok, _} = NimbleOptions.validate([model: "test", contents: [], tools: [
        %{function_declarations: [
          %{
            name: "test",
            description: "a test function",
            parameters: %{
              type: "object",
              properties: %{
                foo: %{type: "string", description: "foo param"}
              },
              required: ["foo"]
            }
          }
        ]}
      ]], Google.schema())

      # invalid tool
      assert {:error, _} = NimbleOptions.validate([model: "test", contents: [], tools: [
        %{foo: "bar"}
      ]], Google.schema())
    end

    test "validates tool config" do
      # valid tool config
      assert {:ok, _} = NimbleOptions.validate([model: "test", contents: [], tool_config: %{
        function_calling_config: %{
          mode: "ANY",
          allowed_function_names: ["foo", "bar"],
        }
      }], Google.schema())

      # invalid tool config
      assert {:error, _} = NimbleOptions.validate([model: "test", contents: [], tool_config: %{foo: "bar"}], Google.schema())
    end

    test "validates safety settings" do
      # valid harm category and threshold
      assert {:ok, _} = NimbleOptions.validate([model: "test", contents: [], safety: [
        %{category: "HARM_CATEGORY_UNSPECIFIED", threshold: "HARM_BLOCK_THRESHOLD_UNSPECIFIED"},
        %{category: "HARM_CATEGORY_DEROGATORY", threshold: "BLOCK_LOW_AND_ABOVE"},
        %{category: "HARM_CATEGORY_TOXICITY", threshold: "BLOCK_MEDIUM_AND_ABOVE"},
        %{category: "HARM_CATEGORY_VIOLENCE", threshold: "BLOCK_ONLY_HIGH"},
        %{category: "HARM_CATEGORY_SEXUAL", threshold: "BLOCK_NONE"},
        %{category: "HARM_CATEGORY_MEDICAL", threshold: "HARM_BLOCK_THRESHOLD_UNSPECIFIED"},
        %{category: "HARM_CATEGORY_DANGEROUS", threshold: "BLOCK_LOW_AND_ABOVE"},
        %{category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE"},
        %{category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_ONLY_HIGH"},
        %{category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE"},
        %{category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "HARM_BLOCK_THRESHOLD_UNSPECIFIED"},
      ]], Google.schema())

      # invalid safety setting
      assert {:error, _} = NimbleOptions.validate([model: "test", contents: [], safety: [
        %{category: "for", threshold: "bar"},
      ]], Google.schema())
    end
  end

  describe "Omni.init/3" do
    test "returns an Omni client with Google headers" do
      assert %Omni.Provider{} = provider = Omni.init(:google)
      assert provider.mod == Google
      assert "x-goog-api-key" in Map.keys(provider.req.headers)
      assert "user-agent" in Map.keys(provider.req.headers)
    end

    test "adds API key from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:google, api_key: "test123")
      assert "test123" in req.headers["x-goog-api-key"]
    end
  end

  describe "Omni chat functions" do
    setup do
      client = MockPlug.wrap(Omni.init(:google))
      {:ok, client: client}
    end

    test "Omni.generate/2 returns a response", %{client: client} do
      assert {:ok, res} = Omni.generate(client, model: "gemini-1.5-flash", contents: [
        %{role: "user", parts: [%{text: "Write a haiku about the Greek Gods"}]}
      ])
      assert [%{"content" => %{"parts" => [content]}}] = res["candidates"]
      assert content["text"] == "Olympus' peak shines,\nGods with power, love, and wrath,\nMortals fear their gaze. \n"
    end

    test "Omni.async/3 returns a task", %{client: client} do
      assert {:ok, %Task{} = task} = Omni.async(client, model: "gemini-1.5-flash", contents: [
        %{role: "user", parts: [%{text: "Write a haiku about the Greek Gods"}]}
      ])
      assert {:ok, res} = Task.await(task)
      assert [%{"content" => %{"parts" => [content]}}] = res["candidates"]
      assert content["text"] == "Olympus' peak shines,\nGods with power, love, and wrath,\nMortals fear their gaze. \n"
    end

    test "Omni.stream/2 returns a stream", %{client: client} do
      assert {:ok, stream} = Omni.stream(client, model: "gemini-1.5-flash", contents: [
        %{role: "user", parts: [%{text: "Write a haiku about the Greek Gods"}]}
      ])

      assert Enumerable.impl_for(stream)
      chunks = Enum.to_list(stream)
      assert length(chunks) > 1
    end
  end
end
