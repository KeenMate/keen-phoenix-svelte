defmodule Example.Directory do
  @moduledoc """
  In-memory company directory of demo users.

  A real app would back this with a database or an identity provider (Microsoft
  Entra ID, LDAP, ...). Here it's a static seed so the demo is self-contained and
  needs no database.
  """

  @type user :: %{
          id: pos_integer(),
          name: String.t(),
          title: String.t(),
          email: String.t(),
          color: String.t()
        }

  @users [
    %{
      id: 1,
      name: "Ada Lovelace",
      title: "Engineering Lead",
      email: "ada@keenspace.dev",
      color: "#6366f1"
    },
    %{
      id: 2,
      name: "Alan Turing",
      title: "Principal Engineer",
      email: "alan@keenspace.dev",
      color: "#0ea5e9"
    },
    %{
      id: 3,
      name: "Grace Hopper",
      title: "VP Engineering",
      email: "grace@keenspace.dev",
      color: "#ec4899"
    },
    %{
      id: 4,
      name: "Katherine Johnson",
      title: "Staff Engineer",
      email: "katherine@keenspace.dev",
      color: "#f59e0b"
    },
    %{
      id: 5,
      name: "Linus Torvalds",
      title: "Infrastructure",
      email: "linus@keenspace.dev",
      color: "#10b981"
    }
  ]

  @doc "Every user in the directory."
  @spec list() :: [user()]
  def list, do: @users

  @doc "Look up a user by id (accepts an integer or a stringified integer)."
  @spec get(integer() | String.t() | nil) :: user() | nil
  def get(nil), do: nil

  def get(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, _} -> get(n)
      :error -> nil
    end
  end

  def get(id) when is_integer(id), do: Enum.find(@users, &(&1.id == id))

  @doc "The user the demo starts as when no one has been selected yet."
  @spec default() :: user()
  def default, do: hd(@users)

  @doc "Up-to-two-letter initials for an avatar bubble, e.g. \"Ada Lovelace\" -> \"AL\"."
  @spec initials(user()) :: String.t()
  def initials(%{name: name}) do
    name
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end
end
