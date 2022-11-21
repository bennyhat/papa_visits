defmodule PapaVisits.Factory do
  @moduledoc """
  Factories for parameters and database models
  """
  use ExMachina.Ecto, repo: PapaVisits.Repo

  def user_factory do
    %PapaVisits.Users.User{
      id: Faker.UUID.v4(),
      first_name: Faker.Person.En.first_name(),
      last_name: Faker.Person.En.last_name(),
      email: Faker.Internet.safe_email(),
      minutes: Faker.random_between(0, 1_000)
    }
  end

  def visit_factory do
    %PapaVisits.Visits.Visit{
      id: Faker.UUID.v4(),
      user: build(:user),
      date: Faker.Date.forward(10),
      minutes: Faker.random_between(0, 1_000),
      status: Enum.random([:completed, :requested, :canceled]),
      tasks: [
        build(:visit_task),
        build(:visit_task),
        build(:visit_task)
      ]
    }
  end

  def visit_task_factory do
    %PapaVisits.Visits.Task{
      id: Faker.UUID.v4(),
      name: Faker.Lorem.word(),
      description: Faker.Lorem.sentence()
    }
  end

  def user_creation_factory do
    %PapaVisits.Users.User{
      first_name: Faker.Person.En.first_name(),
      last_name: Faker.Person.En.last_name(),
      email: Faker.Internet.safe_email(),
      password: Faker.String.base64(10)
    }
  end

  def visit_params_factory do
    %PapaVisits.Params.Visit{
      user_id: Faker.UUID.v4(),
      date: Faker.Date.forward(10),
      minutes: Faker.random_between(0, 1_000),
      tasks: [
        build(:visit_task_params),
        build(:visit_task_params),
        build(:visit_task_params)
      ]
    }
  end

  def visit_task_params_factory do
    %PapaVisits.Params.Task{
      name: Faker.Lorem.word(),
      description: Faker.Lorem.sentence()
    }
  end

  def transaction_params_factory do
    %PapaVisits.Params.Transaction{
      pal_id: Faker.UUID.v4(),
      visit_id: Faker.UUID.v4()
    }
  end

  def visit_filter_params_factory do
    %PapaVisits.Params.VisitFilter{
      user_id: Faker.UUID.v4(),
      status: Enum.random([:completed, :requested, :canceled])
    }
  end
end
