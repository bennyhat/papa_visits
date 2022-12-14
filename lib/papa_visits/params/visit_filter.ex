defmodule PapaVisits.Params.VisitFilter do
  @moduledoc """
  Parameters for filtering a list of visits.
  """
  use CozyParams.Schema

  schema do
    field :user_id, Ecto.UUID
    field :status, Ecto.Enum, values: [:requested, :completed, :canceled]
  end

  @type t :: %__MODULE__{
          user_id: Ecto.UUID.t(),
          status: atom()
        }
end
