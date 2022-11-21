defmodule PapaVisits.Params.Visit do
  @moduledoc """
  Parameters for requesting a visit.
  """
  use CozyParams.Schema
  alias PapaVisits.Params.Task

  schema do
    field :user_id, Ecto.UUID, required: true
    field :date, :date, required: true
    field :minutes, :integer, required: true

    embeds_many :tasks, Task
  end

  @type t :: %__MODULE__{
          user_id: Ecto.UUID.t(),
          date: Date.t(),
          minutes: integer(),
          tasks: [Task.t()]
        }
end
