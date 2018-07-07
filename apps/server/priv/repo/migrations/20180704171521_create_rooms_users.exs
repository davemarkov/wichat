defmodule Server.Repo.Migrations.CreateRoomsUsers do
  use Ecto.Migration

  def change do
    create table(:rooms_users, primary_key: false) do
      add :rooms_id, references(:rooms)
      add :users_id, references(:users)
    end
  end
end
