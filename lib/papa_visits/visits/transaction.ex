defmodule PapaVisits.Visits.Transaction do
  use Ecto.Schema

  import Ecto.Changeset

  alias PapaVisits.Params.Transaction, as: TransactionParams
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Visit

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    belongs_to :papa, User
    belongs_to :pal, User
    belongs_to :visit, Visit

    timestamps()
  end

  @spec unvalidated_changeset(TransactionParams.t()) :: Ecto.Changeset.t()
  def unvalidated_changeset(params) do
    schema = %__MODULE__{
      papa_id: params.papa_id,
      pal_id: params.pal_id,
      visit_id: params.visit_id
    }

    change(schema, %{})
  end

  @spec changeset(map() | TransactionParams.t()) :: Ecto.Changeset.t()
  def changeset(params) do
    schema = %__MODULE__{
      papa_id: params.papa_id,
      pal_id: params.pal_id,
      visit_id: params.visit_id
    }

    changeset(schema, params)
  end

  @spec changeset(t(), map() | TransactionParams.t()) :: Ecto.Changeset.t()
  def changeset(schema, params)

  def changeset(schema, %TransactionParams{} = params) do
    changeset(schema, Map.from_struct(params))
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [])
    |> foreign_key_constraint(:pal_id, message: "pal not found")
    |> foreign_key_constraint(:papa_id, message: "papa not found")
    |> foreign_key_constraint(:visit_id, message: "visit not found")
  end

  @type t :: %__MODULE__{
          papa: User.t(),
          pal: User.t(),
          visit: Visit.t(),
          updated_at: DateTime.t(),
          inserted_at: DateTime.t()
        }
end