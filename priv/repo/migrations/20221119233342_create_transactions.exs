defmodule PapaVisits.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :visit_id, references(:visits)
      add :papa_id, references(:users)
      add :pal_id, references(:users)

      timestamps()
    end
  end
end
