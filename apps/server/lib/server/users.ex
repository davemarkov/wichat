defmodule Server.Users do
  use Ecto.Schema
  # import Ecto.Changeset

  schema "users" do
    field(:name, :string)
    field(:passwd, :string)

    many_to_many(
      :rooms,
      Server.Rooms,
      join_through: "rooms_users",
      on_replace: :delete,
      on_delete: :delete_all
    )

    timestamps()
  end

  # def changeset(users, params \\ %{}) do
  #  users
  #  |> cast(params,[])
  # end
end
