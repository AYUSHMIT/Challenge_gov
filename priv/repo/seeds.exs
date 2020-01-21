# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ChallengeGov.Repo.insert!(%ChallengeGov.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ChallengeGov.Accounts

defmodule Helpers do
  def create_admin(email) do
    case Accounts.get_by_email(email) do
      {:error, :not_found} ->
        Accounts.create(%{
          email: email,
          password: "password",
          password_confirmation: "password",
          first_name: "Admin",
          last_name: "User",
          role: "admin"
        })

      _ ->
        nil
    end
  end
end

defmodule Seeds do
  import Helpers

  def run do
    create_admin("admin@example.com")
  end
end

Seeds.run()
