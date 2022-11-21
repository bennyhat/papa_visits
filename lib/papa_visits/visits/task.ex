defmodule PapaVisits.Visits.Task do
  @moduledoc """
  How a visit task is representated in the database.
  """
  use Ecto.Schema

  import Ecto.Changeset

  alias PapaVisits.Params.Task, as: TaskParams
  alias PapaVisits.Visits.Visit

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tasks" do
    belongs_to :visit, Visit

    field :name, :string
    field :description, :string
  end

  @spec changeset(t(), map() | TaskParams.t()) :: Ecto.Changeset.t()
  def changeset(schema \\ %__MODULE__{}, params)

  def changeset(schema, %TaskParams{} = params) do
    changeset(schema, Map.from_struct(params))
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:name, :description])
    |> validate_required([:name])
  end

  @type t :: %__MODULE__{
          visit_id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          description: String.t() | nil
        }

  @type t_loaded :: %__MODULE__{
          id: Ecto.UUID.t(),
          visit_id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t()
        }
end
