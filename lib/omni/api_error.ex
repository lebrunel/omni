defmodule Omni.APIError do
  @moduledoc false
  defexception [:status, :error]

  @impl true
  def message(%__MODULE__{error: %{"message" => message}}), do: message
  def message(%__MODULE__{status: status}), do: "HTTP Error: #{status}"
end
