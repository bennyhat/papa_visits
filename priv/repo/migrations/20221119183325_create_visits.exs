defmodule PapaVisits.Repo.Migrations.CreateVisits do
  use Ecto.Migration

  def change do
    create table(:visits) do
      add :date, :date, null: false
      add :minutes, :integer, null: false
      add :status, :string, null: false
      add :user_id, references(:users)

      timestamps()
    end

    create table(:tasks) do
      add :name, :string, null: false
      add :description, :string

      add :visit_id, references(:visits)
    end
  end
end
