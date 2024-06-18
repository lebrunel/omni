defmodule Omni.Providers.OllamaTest do
  use ExUnit.Case, async: true
  alias Omni.Providers.Ollama

  describe "schema/0" do
    test "model and messages is required" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: []], Ollama.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test"], Ollama.schema())
      assert {:error, _} = NimbleOptions.validate([messages: []], Ollama.schema())
    end

    test "validates message types" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "system", content: "test"},
        %{role: "user", content: "test"},
        %{role: "assistant", content: "test"},
      ]], Ollama.schema())

      # invalid role
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [
        %{role: "whoami", content: "test"},
      ]], Ollama.schema())
    end

    test "keep_alive accepts string or integer" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], keep_alive: 100], Ollama.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], keep_alive: "10m"], Ollama.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], keep_alive: [1, 2]], Ollama.schema())
    end

    test "validates options map" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", messages: [], options: %{
        :atom => 123,
        "string" => "test",
      }], Ollama.schema())

      # invalid options
      assert {:error, _} = NimbleOptions.validate([model: "test", messages: [], options: %{
        123 => "test"
      }], Ollama.schema())
    end
  end

  describe "Omni.init/3" do
    test "returns an Omni client with Ollama headers" do
      assert %Omni.Provider{} = provider = Omni.init(:ollama)
      assert provider.mod == Ollama
      assert "user-agent" in Map.keys(provider.req.headers)
    end

    test "sets base URL from opts" do
      assert %Omni.Provider{req: req} = Omni.init(:ollama, base_url: "http://host.com/api")
      assert req.options.base_url == "http://host.com/api"
    end
  end

  describe "Omni chat functions" do
    setup do
      client = MockPlug.wrap(Omni.init(:ollama))
      {:ok, client: client}
    end

    test "Omni.generate/2 returns a response", %{client: client} do
      assert {:ok, res} = Omni.generate(client, model: "llama3", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert %{"content" => content} = res["message"]
      assert content == "Here is a haiku about the Greek Gods:\n\nOlympus' grandeur\nZeus' thunderbolt crashes\nGods' eternal reign"
    end

    test "Omni.async/3 returns a task", %{client: client} do
      assert {:ok, %Task{} = task} = Omni.async(client, model: "llama3", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])
      assert {:ok, res} = Task.await(task)
      assert %{"content" => content} = res["message"]
      assert content == "Here is a haiku about the Greek Gods:\n\nOlympus' grandeur\nZeus' thunderbolt crashes\nGods' eternal reign"
    end

    test "Omni.stream/2 returns a stream", %{client: client} do
      assert {:ok, stream} = Omni.stream(client, model: "llama3", messages: [
        %{role: "user", content: "Write a haiku about the Greek Gods"}
      ])

      assert Enumerable.impl_for(stream)
      chunks = Enum.to_list(stream)
      assert length(chunks) > 1
    end
  end

end
