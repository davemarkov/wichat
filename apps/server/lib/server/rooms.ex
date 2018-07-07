defmodule Server.Rooms do
  use Ecto.Schema
  # import Ecto.Changeset

  schema "rooms" do
    field(:room_name, :string)
    timestamps()
    has_many(:messages, Server.Messages, on_delete: :delete_all)

    many_to_many(
      :users,
      Server.Users,
      join_through: "rooms_users",
      on_replace: :delete,
      on_delete: :delete_all
    )
  end
end
