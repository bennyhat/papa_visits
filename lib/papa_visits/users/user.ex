defmodule PapaVisits.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  import Pow.Ecto.Schema.Changeset, only: [new_password_changeset: 3]

  alias PapaVisits.Visits.Visit

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :minutes, :integer, default: 120

    has_many :visits, Visit

    pow_user_fields()

    timestamps()
  end

  def changeset(user_or_changeset, attrs) do
    user_or_changeset
    |> Ecto.Changeset.cast(attrs, [:first_name, :last_name, :minutes])
    |> Ecto.Changeset.validate_required([:first_name, :last_name])
    |> pow_user_id_field_changeset(attrs)
    |> pow_current_password_changeset(attrs)
    |> new_password_changeset(attrs, @pow_config)
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          minutes: integer(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @type t_preloaded :: %__MODULE__{
          id: Ecto.UUID.t(),
          email: String.t(),
          first_name: String.t(),
          last_name: String.t(),
          minutes: integer(),
          visits: [Visit.t()],
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }
end
