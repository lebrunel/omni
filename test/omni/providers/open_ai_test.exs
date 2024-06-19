defmodule Omni.Providers.OpenAITest do
  use ExUnit.Case, async: true
  alias Omni.Providers.OpenAI

  describe "schema/0" do
    test "model and messages is required" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: []], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test"], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([messages: []], OpenAI.schema())
    end

    test "validates message types" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "system", content: "test"},
        %{role: "user", name: "foo", content: "test"},
        %{role: "user", name: "bar", content: "test"},
        %{role: "assistant", content: "test"},
      ]], OpenAI.schema())

      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "user", content: "test"},
        %{role: "assistant", content: "test", tool_calls: [
          %{id: "foo", type: "function", function: %{name: "sum", arguments: "{a: 1, b: 2}"}}
        ]},
        %{role: "tool", tool_call_id: "foo", name: "sum", content: "3"}
      ]], OpenAI.schema())

      # invalid role
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "whoami", content: "test"},
      ]], OpenAI.schema())

      # invalid tool call
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "user", content: "test"},
        %{role: "assistant", content: "test", tool_calls: [
          %{foo: "bar"}
        ]},
      ]], OpenAI.schema())
    end

    test "validates tool types" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tools: [
        %{
          type: "function",
          function: %{
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
        }
      ]], OpenAI.schema())

      # invalid tool
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], tools: [
        %{foo: "bar"}
      ]], OpenAI.schema())
    end

    test "logit_bias must be a map of string to integers" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], logit_bias: %{"foo" => 100}], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], logit_bias: %{foo: 100}], OpenAI.schema())
    end

    test "response_format must be a map with valid type value" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], response_format: %{type: "text"}], OpenAI.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], response_format: %{type: "json_object"}], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], response_format: %{type: "foo"}], OpenAI.schema())
    end

    test "stop must be a string or list of strings" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], stop: "foo"], OpenAI.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], stop: ["foo", "bar", "baz"]], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], stop: 123], OpenAI.schema())
    end

    test "tool choice can be a valid string" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: "none"], OpenAI.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: "auto"], OpenAI.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: "required"], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: "foo"], OpenAI.schema())
    end

    test "tool choice can be a function map" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{type: "function", function: %{name: "test"}}], OpenAI.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{foo: "bar"}], OpenAI.schema())
    end
  end

  describe "Omni.init/3" do
    test "returns an Omni client with OpenAI headers" do
      assert %Omni.Provider{} = provider = Omni.init(:openai)
      assert provider.mod == OpenAI
      assert "authorization" in Map.keys(provider.req.headers)
      assert "user-agent" in Map.keys(provider.req.headers)
    end

    test "adds API key from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:openai, api_key: "test123")
      assert "Bearer test123" in req.headers["authorization"]
    end

    test "adds organization id from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:openai, organization_id: "test123")
      assert "test123" in req.headers["openai-organization"]
    end

    test "adds project id from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:openai, project_id: "test123")
      assert "test123" in req.headers["openai-project"]
    end

    test "sets base URL from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:openai, base_url: "http://host.com/api")
      assert req.options.base_url == "http://host.com/api"
    end
  end

  describe "Omni chat functions" do
    setup do
      client = MockPlug.wrap(Omni.init(:openai))
      {:ok, client: client}
    end

    test "Omni.generate/2 returns a response", %{client: client} do
      assert {:ok, res} = Omni.generate(client, model: "gpt-4o", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert [%{"message" => message}] = res["choices"]
      assert message["content"] == "Mount Olympus stands,\nImmortal whispers echo—\nZeus reigns, thunder roars."
    end

    test "Omni.async/3 returns a task", %{client: client} do
      assert {:ok, %Task{} = task} = Omni.async(client, model: "gpt-4o", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert {:ok, res} = Task.await(task)
      assert [%{"message" => message}] = res["choices"]
      assert message["content"] == "Mount Olympus stands,\nImmortal whispers echo—\nZeus reigns, thunder roars."
    end

    test "Omni.stream/2 returns a stream", %{client: client} do
      assert {:ok, stream} = Omni.stream(client, model: "gpt-4o", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])

      assert Enumerable.impl_for(stream)
      chunks = Enum.to_list(stream)
      assert length(chunks) > 1
    end
  end

end
