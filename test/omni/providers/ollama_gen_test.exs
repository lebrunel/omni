defmodule Omni.Providers.OllamaGenTest do
  use ExUnit.Case, async: true
  alias Omni.Providers.OllamaGen

  describe "schema/0" do
    test "model and prompt is required" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", prompt: "test"], OllamaGen.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test"], OllamaGen.schema())
      assert {:error, _} = NimbleOptions.validate([prompt: "test"], OllamaGen.schema())
    end

    test "context accepts list of numbers" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", prompt: "test", context: [1, 2, 1.2]], OllamaGen.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", prompt: "test", context: ["a", "b"]], OllamaGen.schema())
    end

    test "keep_alive accepts string or integer" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", prompt: "test", keep_alive: 100], OllamaGen.schema())
      assert {:ok, _} = NimbleOptions.validate([model: "test", prompt: "test", keep_alive: "10m"], OllamaGen.schema())
      assert {:error, _} = NimbleOptions.validate([model: "test", prompt: "test", keep_alive: [1, 2]], OllamaGen.schema())
    end

    test "validates options map" do
      assert {:ok, _} = NimbleOptions.validate([model: "test", prompt: "test", options: %{
        :atom => 123,
        "string" => "test",
      }], OllamaGen.schema())

      # invalid options
      assert {:error, _} = NimbleOptions.validate([model: "test", prompt: "test", options: %{
        123 => "test"
      }], OllamaGen.schema())
    end
  end

  describe "Omni.init/3" do
    test "returns an Omni client with Ollama headers" do
      assert %Omni.Provider{} = provider = Omni.init(OllamaGen)
      assert provider.mod == OllamaGen
      assert "user-agent" in Map.keys(provider.req.headers)
    end

    test "sets base URL from opts" do
      assert %Omni.Provider{req: req} = Omni.init(OllamaGen, base_url: "http://host.com/api")
      assert req.options.base_url == "http://host.com/api"
    end
  end

  describe "Omni chat functions" do
    setup do
      client = MockPlug.wrap(Omni.init(OllamaGen))
      {:ok, client: client}
    end

    test "Omni.generate/2 returns a response", %{client: client} do
      assert {:ok, res} = Omni.generate(client, model: "llama3", prompt: "Write a haiku about the Greek Gods")
      assert res["response"] == "Olympus' throne high\nZeus' lightning bolts strike fear\nMortal fate's grasp"
    end

    test "Omni.async/3 returns a task", %{client: client} do
      assert {:ok, %Task{} = task} = Omni.async(client, model: "llama3", prompt: "Write a haiku about the Greek Gods")
      assert {:ok, res} = Task.await(task)
      assert res["response"] == "Olympus' throne high\nZeus' lightning bolts strike fear\nMortal fate's grasp"
    end

    test "Omni.stream/2 returns a stream", %{client: client} do
      assert {:ok, stream} = Omni.stream(client, model: "llama3", prompt: "Write a haiku about the Greek Gods")
      assert Enumerable.impl_for(stream)
      chunks = Enum.to_list(stream)
      assert length(chunks) > 1
    end
  end

end
