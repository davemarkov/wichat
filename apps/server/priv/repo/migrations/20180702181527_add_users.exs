defmodule Server.Repo.Migrations.AddUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string
      add :passwd, :string
      timestamps
    end
  end
end
