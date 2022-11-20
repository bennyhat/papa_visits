defmodule PapaVisits.Visits.Visit do
  use Ecto.Schema

  import Ecto.Changeset

  alias PapaVisits.Params.Visit, as: VisitParams
  alias PapaVisits.Users.User
  alias PapaVisits.Visits.Task

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "visits" do
    belongs_to :user, User

    field :date, :date
    field :minutes, :integer
    field :status, Ecto.Enum, values: [:requested, :completed, :canceled], default: :requested

    has_many :tasks, Task

    timestamps()
  end

  @spec unvalidated_changeset(VisitParams.t()) :: Ecto.Changeset.t()
  def unvalidated_changeset(params) do
    schema = %__MODULE__{
      user_id: params.user_id
    }

    change(schema, %{})
  end

  @spec changeset(map() | VisitParams.t()) ::
          {:ok, Ecto.Changeset.t()} | {:error, Ecto.Changeset.t()}
  def changeset(params) do
    %User{id: params.user_id}
    |> Ecto.build_assoc(:visits)
    |> changeset(params)
  end

  @spec changeset(t(), map() | VisitParams.t()) :: Ecto.Changeset.t()
  def changeset(schema, params)

  def changeset(schema, %VisitParams{} = params) do
    changeset(schema, Map.from_struct(params))
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:date, :minutes])
    |> validate_required([:date, :minutes, :user_id])
    |> cast_assoc(:tasks, required: true)
    |> foreign_key_constraint(:user_id, message: "papa not found")
    |> validate_number(:minutes, greater_than: 0)
    |> validate_date_is_at_least_today()
  end

  @spec status_changeset(t(), atom()) :: Ecto.Changeset.t()
  def status_changeset(schema, status) do
    schema
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
  end

  defp validate_date_is_at_least_today(changeset) do
    case get_change(changeset, :date, nil) do
      nil ->
        # for cases where date was not adjusted
        # like updating the status after visit is done
        changeset

      date ->
        if Date.compare(Date.utc_today(), date) == :gt do
          add_error(changeset, :date, "must be at least today")
        else
          changeset
        end
    end
  end

  @type t :: %__MODULE__{
          user: User.t(),
          date: Date.t(),
          minutes: integer(),
          tasks: [Task.t()],
          status: atom(),
          updated_at: DateTime.t(),
          inserted_at: DateTime.t()
        }
end
