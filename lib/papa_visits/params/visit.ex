defmodule PapaVisits.Params.Visit do
  use CozyParams.Schema

  schema do
    field :user_id, Ecto.UUID, required: true
    field :date, :date, required: true
    field :minutes, :integer, required: true

    embeds_many :tasks do
      field :name, :string, required: true
      field :description, :string
    end
  end

  @type t :: %__MODULE__{
          user_id: Ecto.UUID.t(),
          date: Date.t(),
          minutes: integer(),
          tasks: [
            %__MODULE__.Tasks{
              name: String.t(),
              description: String.t()
            }
          ]
        }
end
