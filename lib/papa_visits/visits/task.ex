defmodule PapaVisits.Visits.Task do
  use Ecto.Schema

  import Ecto.Changeset

  alias PapaVisits.Params.Visit.Tasks, as: TaskParams
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
          visit: Visit.t(),
          name: String.t(),
          description: String.t()
        }
end
