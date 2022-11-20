defmodule PapaVisits.Repo.Migrations.CreateVisitsStatusIndex do
  use Ecto.Migration

  def change do
    create index(:visits, [:status])
  end
end
