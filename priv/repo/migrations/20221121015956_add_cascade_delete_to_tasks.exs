defmodule PapaVisits.Repo.Migrations.AddCascadeDeleteToTasks do
  use Ecto.Migration

  def change do
    drop constraint(:tasks, :tasks_visit_id_fkey)

    alter table(:tasks) do
      modify :visit_id, references(:visits, on_delete: :delete_all)
    end
  end
end
