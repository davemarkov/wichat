defmodule Server.Messages do
  use Ecto.Schema

  schema "messages" do
    field(:messages, :string)
    field(:from, :string)
    belongs_to(:rooms, Server.Rooms, on_replace: :delete)
    timestamps()
  end
end
