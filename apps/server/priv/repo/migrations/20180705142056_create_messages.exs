defmodule Server.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add(:messages, :string)
      add(:from, :string)
      add(:rooms_id, references(:rooms))
      timestamps()
    end
  end
end
