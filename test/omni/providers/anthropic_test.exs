defmodule Omni.Providers.AnthropicTest do
  use ExUnit.Case, async: true
  alias Omni.Providers.Anthropic

  describe "schema/0" do
    test "model and messages is required" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: []], Anthropic.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test"], Anthropic.schema())
      assert {:error, _} = NimbleOptions.validate([messages: []], Anthropic.schema())
    end

    test "validates message types" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "user", content: "test"},
        %{role: "assistant", content: "test"},
      ]], Anthropic.schema())

      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "user", content: [
          %{type: "text", text: "test"},
          %{type: "image", source: [
            %{type: "base64", media_type: "image/png", data: "test"}
          ]},
        ]},
      ]], Anthropic.schema())

      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "user", content: "test"},
        %{role: "assistant", content: [
          %{type: "text", text: "test"},
          %{type: "tool_use", id: "test", name: "sum", input: %{"a" => 1, "b" => 2}},
        ]},
        %{role: "user", content: [
          %{type: "tool_result", tool_use_id: "test", content: [
            %{type: "text", text: "3"}
          ]},
        ]},
      ]], Anthropic.schema())

      # invalid role
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "whoami", content: "test"},
      ]], Anthropic.schema())

      # cannot current test invalid content blocks as nimble options not happy
      # with deeply nested conditional structure
    end

    test "validates tool types" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tools: [
        %{
          name: "test",
          description: "a test function",
          input_schema: %{
            type: "object",
            properties: %{
              foo: %{type: "string", description: "foo param"}
            },
            required: ["foo"]
          }
        }
      ]], Anthropic.schema())

      # invalid tool
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], tools: [
        %{foo: "bar"}
      ]], Anthropic.schema())
    end

    test "metadata must contain user id" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], metadata: %{user_id: "test"}], Anthropic.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], metadata: %{foo: "bar"}], Anthropic.schema())
    end

    test "tool choice can be a valid string" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{type: "auto"}], Anthropic.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{type: "any"}], Anthropic.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{type: "tool", name: "test"}], Anthropic.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], tool_choice: %{type: "foo"}], Anthropic.schema())
    end
  end

  describe "Omni.init/3" do
    test "returns an Omni client with Anthropic headers" do
      assert %Omni.Provider{} = provider = Omni.init(:anthropic)
      assert provider.mod == Anthropic
      assert "x-api-key" in Map.keys(provider.req.headers)
      assert "anthropic-version" in Map.keys(provider.req.headers)
      assert "user-agent" in Map.keys(provider.req.headers)
    end

    test "adds API key from config" do
      assert %Omni.Provider{req: req} = Omni.init(:anthropic)
      assert [key] = req.headers["x-api-key"]
      assert is_binary(key)
    end

    test "adds API key from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:anthropic, api_key: "test123")
      assert "test123" in req.headers["x-api-key"]
    end
  end

  describe "Omni chat functions" do
    setup do
      client = MockPlug.wrap(Omni.init(:anthropic))
      {:ok, client: client}
    end

    test "Omni.generate/2 returns a response", %{client: client} do
      assert {:ok, res} = Omni.generate(client, model: "claude-3-haiku-20240307", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert is_map(res)
      assert [%{"text" => text}] = res["content"]
      assert text == "Here is a haiku about the Greek Gods:\n\nMighty pantheon\nOlympian deities reign\nImmortal power"
    end

    test "Omni.async/3 returns a task", %{client: client} do
      assert {:ok, %Task{} = task} = Omni.async(client, model: "claude-3-haiku-20240307", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert {:ok, res} = Task.await(task)
      assert is_map(res)
      assert [%{"text" => text}] = res["content"]
      assert text == "Here is a haiku about the Greek Gods:\n\nMighty pantheon\nOlympian deities reign\nImmortal power"
    end

    test "Omni.stream/2 returns a stream", %{client: client} do
      assert {:ok, stream} = Omni.stream(client, model: "claude-3-haiku-20240307", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])

      assert Enumerable.impl_for(stream)
      chunks = Enum.to_list(stream)
      assert length(chunks) > 1
    end
  end

end
