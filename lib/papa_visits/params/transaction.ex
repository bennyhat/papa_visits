defmodule PapaVisits.Params.Transaction do
  use CozyParams.Schema

  schema do
    field :papa_id, Ecto.UUID, required: true
    field :pal_id, Ecto.UUID, required: true
    field :visit_id, Ecto.UUID, required: true
  end

  @type t :: %__MODULE__{
          papa_id: Ecto.UUID.t(),
          pal_id: Ecto.UUID.t(),
          visit_id: Ecto.UUID.t()
        }
end
