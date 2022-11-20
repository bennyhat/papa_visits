defmodule PapaVisits.Repo.Migrations.RemoveTransactionsPapaId do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      remove :papa_id, references(:users)
    end
  end
end
