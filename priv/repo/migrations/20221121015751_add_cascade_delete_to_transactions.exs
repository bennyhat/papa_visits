defmodule PapaVisits.Repo.Migrations.AddCascadeDeleteToTransactions do
  use Ecto.Migration

  def change do
    drop constraint(:transactions, :transactions_visit_id_fkey)

    alter table(:transactions) do
      modify :visit_id, references(:visits, on_delete: :delete_all)
    end
  end
end
