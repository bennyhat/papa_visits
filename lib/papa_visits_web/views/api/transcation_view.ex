defmodule PapaVisitsWeb.Api.TransactionView do
  use PapaVisitsWeb, :view

  alias PapaVisits.Visits.Transaction
  alias PapaVisitsWeb.Api.UserView
  alias PapaVisitsWeb.Api.VisitView

  def render("transaction.json", %{transaction: %Transaction{} = transaction}) do
    %{
      id: transaction.id,
      pal: render(UserView, "user.json", user: transaction.pal),
      visit: render(VisitView, "visit_preloaded.json", visit: transaction.visit)
    }
  end
end
