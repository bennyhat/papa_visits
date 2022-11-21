defmodule PapaVisits.Repo.Migrations.AddNilDeleteUserToTransactions do
  use Ecto.Migration

  def change do
    drop constraint(:transactions, :transactions_pal_id_fkey)

    alter table(:transactions) do
      modify :pal_id, references(:users, on_delete: :nilify_all)
    end
  end
end
