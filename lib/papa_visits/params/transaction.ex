defmodule PapaVisits.Params.Transaction do
  @moduledoc """
  Parameters for completing a visit.
  """

  use CozyParams.Schema

  schema do
    field :pal_id, Ecto.UUID, required: true
    field :visit_id, Ecto.UUID, required: true
  end

  @type t :: %__MODULE__{
          pal_id: Ecto.UUID.t(),
          visit_id: Ecto.UUID.t()
        }
end
