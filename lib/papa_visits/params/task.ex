defmodule PapaVisits.Params.Task do
  @moduledoc """
  Parameters for requesting a visit task.
  """
  use CozyParams.Schema

  schema do
    field :name, :string, required: true
    field :description, :string
  end

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t()
        }
end
