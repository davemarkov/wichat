defmodule Client.Connectivity do
  def create_address() do
    client_name =
      1..8
      |> Enum.reduce([], fn _, acc -> [Enum.random(?a..?z) | acc] end)
      |> List.to_string()

    client_location = "127.0.0.1"
    # get user ip
    :"#{client_name}@#{client_location}"
  end

  def connect_to_server() do
    case Node.alive?() do
      true ->
        :ok

      false ->
        create_address()
        |> Node.start()
    end

    # Node.set_cookie(:my_chat)
    Node.connect(:"server@127.0.0.1")
  end
end
