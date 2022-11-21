defmodule PapaVisits.Visits.Transaction do
  @moduledoc """
  How a visit completion transaction is representated in the database.
  Only minor validation is done here, as I try to avoid
  Doing Repo calls at this level.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias PapaVisits.Params.Transaction, as: TransactionParams
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Visit

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactions" do
    belongs_to :pal, User
    belongs_to :visit, Visit

    timestamps()
  end

  @spec unvalidated_changeset(TransactionParams.t()) :: Ecto.Changeset.t()
  def unvalidated_changeset(params) do
    schema = %__MODULE__{
      pal_id: params.pal_id,
      visit_id: params.visit_id
    }

    change(schema, %{})
  end

  @spec changeset(map() | TransactionParams.t()) :: Ecto.Changeset.t()
  def changeset(params) do
    schema = %__MODULE__{
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
    |> foreign_key_constraint(:visit_id, message: "visit not found")
  end

  @type t :: %__MODULE__{
          visit_id: Ecto.UUID.t(),
          pal_id: Ecto.UUID.t()
        }

  @type t_preloaded :: %__MODULE__{
          id: Ecto.UUID.t(),
          pal: User.t(),
          visit: Visit.t_preloaded()
        }
end
