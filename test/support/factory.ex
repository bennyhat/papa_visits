defmodule PapaVisits.Factory do
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
end
