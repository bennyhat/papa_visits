defmodule PapaVisitsWeb.Api.VisitView do
  use PapaVisitsWeb, :view

  alias PapaVisits.Visits.Visit
  alias PapaVisits.Visits.Task
  alias PapaVisitsWeb.Api.TransactionView
  alias PapaVisitsWeb.Api.UserView

  def render("index.json", %{visits: visits}) do
    %{
      data: render_many(visits, __MODULE__, "visit_preloaded.json", as: :visit)
    }
  end

  def render("show.json", %{visit: visit}) do
    %{
      data: render(__MODULE__, "visit_preloaded.json", visit: visit)
    }
  end

  def render("update_completed.json", %{transaction: transaction}) do
    %{
      data: render(TransactionView, "transaction.json", transaction: transaction)
    }
  end

  def render("visit.json", %{visit: %Visit{} = visit}) do
    %{
      id: visit.id,
      minutes: visit.minutes,
      date: visit.date,
      status: visit.status,
      tasks: render_many(visit.tasks, __MODULE__, "task.json", as: :task)
    }
  end

  def render("visit_preloaded.json", %{visit: %Visit{} = visit}) do
    %{
      id: visit.id,
      user: render(UserView, "user.json", user: visit.user),
      minutes: visit.minutes,
      date: visit.date,
      status: visit.status,
      tasks: render_many(visit.tasks, __MODULE__, "task.json", as: :task)
    }
  end

  def render("task.json", %{task: %Task{} = task}) do
    %{
      id: task.id,
      name: task.name,
      description: task.description
    }
  end
end
