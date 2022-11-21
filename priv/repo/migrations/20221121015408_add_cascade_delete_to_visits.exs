defmodule PapaVisits.Repo.Migrations.AddCascadeDeleteToVisits do
  use Ecto.Migration

  def change do
    drop constraint(:visits, :visits_user_id_fkey)

    alter table(:visits) do
      modify :user_id, references(:users, on_delete: :delete_all)
    end
  end
end
