defmodule Server.Connectivity do
  def start_server do
    case Node.alive?() do
      true ->
        {:ok, Node.self}

      false ->
        Node.start(:"server@127.0.0.1")
    end
  end
end
