defmodule PapaVisits.Users.User do
  use Ecto.Schema
  use Pow.Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :minutes, :integer, default: 0

    pow_user_fields()

    timestamps()
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
end
