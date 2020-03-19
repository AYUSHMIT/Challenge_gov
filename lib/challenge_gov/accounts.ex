defmodule ChallengeGov.Accounts do
  @moduledoc """
  Context for user accounts
  """

  alias ChallengeGov.Accounts.Avatar
  alias ChallengeGov.Accounts.User
  alias ChallengeGov.Recaptcha
  alias ChallengeGov.Repo
  alias Stein.Filter
  alias Stein.Pagination
  alias Web.SessionController

  import Ecto.Query

  @behaviour Stein.Filter

  @doc false
  def roles(user) do
    case user.role do
      "super_admin" ->
        User.roles()

      "admin" ->
        Enum.slice(User.roles(), 2..2)
    end
  end

  @doc """
  Get all accounts
  """
  def all(opts \\ []) do
    opts = Enum.into(opts, %{})

    query = Filter.filter(User, opts[:filter], __MODULE__)

    Pagination.paginate(Repo, query, %{page: opts[:page], per: opts[:per]})
  end

  @doc """
  Get all accounts
  """
  def all_for_select() do
    Repo.all(User)
  end

  @doc """
  Get all public accounts
  """
  def public(opts \\ []) do
    opts = Enum.into(opts, %{})

    query =
      User
      |> where([u], u.finalized == true)
      |> where([u], u.display == true)
      |> Filter.filter(opts[:filter], __MODULE__)

    Pagination.paginate(Repo, query, %{page: opts[:page], per: opts[:per]})
  end

  @doc """
  Find accounts that are OK to invite to this team

  They don't already belong
  """
  def for_inviting_to(opts \\ []) do
    opts = Enum.into(opts, %{})

    User
    |> where([u], u.finalized == true)
    |> where([u], u.display == true)
    |> where(
      [u],
      fragment(
        "(select count(*) from team_members where user_id = ? and status = 'accepted') = 0",
        u.id
      )
    )
    |> filter_invite_users(opts)
    |> limit(9)
    |> Repo.all()
  end

  def filter_invite_users(query, %{search: search}) when search != nil and search != "" do
    names = String.split(search, " ")

    conditions =
      Enum.reduce(names, false, fn name, query ->
        name = "%#{name}%"
        dynamic([u], ilike(u.first_name, ^name) or ilike(u.last_name, ^name) or ^query)
      end)

    where(query, ^conditions)
  end

  def filter_invite_users(query, _opts), do: query

  @doc """
  Changeset for sign in and registration
  """
  def new() do
    User.create_changeset(%User{}, %{})
  end

  @doc """
  Create an account
  """
  def create(params) do
    %User{}
    |> User.create_changeset(params)
    |> Repo.insert()
  end

  @doc """
  Register an account
  """
  def register(params) do
    recaptcha_token = Map.get(params, "recaptcha_token")

    case Recaptcha.valid_token?(recaptcha_token) do
      true ->
        register_user(params)

      false ->
        %User{}
        |> User.create_changeset(params)
        |> Ecto.Changeset.add_error(:recaptcha_token, "is invalid")
        |> Ecto.Changeset.apply_action(:insert)
    end
  end

  defp register_user(params) do
    changeset = User.create_changeset(%User{}, params)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(:user, changeset)
      |> Ecto.Multi.run(:avatar, fn _repo, %{user: user} ->
        Avatar.maybe_upload_avatar(user, params)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{avatar: user}} ->
        {:ok, user}

      {:error, _type, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Changeset for account editing
  """
  def edit(user), do: User.update_changeset(user, %{})

  @doc """
  Update last active timestamp
  """
  def update_last_active(user) do
    user
    |> User.last_active_changeset()
    |> Repo.update()
  end

  @doc """
  Update an account
  """
  def update(user, params) do
    changeset = User.update_changeset(user, params)

    result =
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, changeset)
      |> Ecto.Multi.run(:avatar, fn _repo, %{user: user} ->
        Avatar.maybe_upload_avatar(user, params)
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{avatar: user}} ->
        {:ok, user}

      {:error, _type, changeset, _changes} ->
        {:error, changeset}
    end
  end

  @doc """
  Update an account's password
  """
  def update_password(user, params) do
    user
    |> User.password_changeset(params)
    |> Repo.update()
  end

  @doc """
  Update an account's terms
  """
  def update_terms(user, params) do
    user
    |> User.terms_changeset(params)
    |> Repo.update()
  end

  @doc """
  Validate a user's login information
  """
  def validate_login(email, password) do
    Stein.Accounts.validate_login(Repo, User, email, password)
  end

  @doc """
  Get a user by an ID
  """
  def get(id) do
    case Repo.get(User, id) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  @doc """
  Get a user by an ID, public view
  """
  def public_get(id) do
    case Repo.get_by(User, id: id, display: true) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  @doc """
  Find a user by a token
  """
  def get_by_token(token) do
    case Ecto.UUID.cast(token) do
      {:ok, token} ->
        case Repo.get_by(User, token: token) do
          nil ->
            {:error, :not_found}

          user ->
            {:ok, user}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Find a user by an email verification token
  """
  def get_by_email_token(token) do
    case Ecto.UUID.cast(token) do
      {:ok, token} ->
        case Repo.get_by(User, email_verification_token: token) do
          nil ->
            {:error, :not_found}

          user ->
            {:ok, user}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @doc """
  Find a user by an email
  """
  def get_by_email(email) do
    case Repo.get_by(User, email: email) do
      nil ->
        {:error, :not_found}

      user ->
        {:ok, user}
    end
  end

  @doc """
  Find and verify a user by their verification token
  """
  def verify_email(token) do
    Stein.Accounts.verify_email(Repo, User, token)
  end

  @doc """
  Check if a user's email was verified
  """
  def email_verified?(user) do
    Stein.Accounts.email_verified?(user)
  end

  def has_admin_access?(user) do
    is_super_admin?(user) or is_admin?(user)
  end

  @doc """
  Check if a user is an super_admin

      iex> Accounts.is_super_admin?(%User{role: "super_admin"})
      true

      iex> Accounts.is_super_admin?(%User{role: "user"})
      false
  """
  def is_super_admin?(user)

  def is_super_admin?(%{role: "super_admin"}), do: true

  def is_super_admin?(_), do: false

  @doc """
  Check if a user is an admin

      iex> Accounts.is_admin?(%User{role: "admin"})
      true

      iex> Accounts.is_admin?(%User{role: "user"})
      false
  """
  def is_admin?(user)

  def is_admin?(%{role: "admin"}), do: true

  def is_admin?(_), do: false

  @doc """
  Check if a user is a challenge owner

      iex> Accounts.is_admin?(%User{role: "challenge_owner"})
      true

      iex> Accounts.is_admin?(%User{role: "challenge_owner"})
      false
  """
  def is_challenge_owner?(user)

  def is_challenge_owner?(%{role: "challenge_owner"}), do: true

  def is_challenge_owner?(_), do: false

  @doc """
  Check if a user has accepted all terms
  """
  def has_accepted_terms?(user)

  def has_accepted_terms?(%{terms_of_use: nil}), do: false

  def has_accepted_terms?(%{privacy_guidelines: nil}), do: false

  def has_accepted_terms?(%{terms_of_use: _timestamp}), do: true

  def has_accepted_terms?(%{privacy_guidelines: _timestamp}), do: true

  @doc """
  Check if a user is pending
  """
  def is_pending_user?(user)

  def is_pending_user?(%{pending: true}), do: true

  def is_pending_user?(%{pending: false}), do: false

  @impl true
  def filter_on_attribute({"search", value}, query) do
    value = "%" <> value <> "%"

    where(
      query,
      [a],
      ilike(a.first_name, ^value) or ilike(a.last_name, ^value) or ilike(a.email, ^value)
    )
  end

  @doc """
  Toggle suspension of a user
  """
  def toggle_suspension(user) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:suspended, !user.suspended)
    |> Repo.update()
  end

  @doc """
  Toggle display status of a user
  """
  def toggle_display(user) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:display, !user.display)
    |> Repo.update()
  end

  @doc """
  Toggle admin status of a user
  """
  def toggle_admin(user = %{role: "admin"}) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:role, "user")
    |> Repo.update()
  end

  def toggle_admin(user = %{role: "user"}) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_change(:role, "admin")
    |> Repo.update()
  end

  @doc """
  check for activity in last 90 days
  """
  def check_all_last_actives() do
    Enum.map(__MODULE__.all(), fn user ->
      check_last_active(user)
    end)
  end

  def check_last_active(user) do
    last_active = DateTime.to_unix(user.last_active)

    if user.last_active && SessionController.now() > last_active do
      __MODULE__.update(user, %{suspended: true})
    else
      __MODULE__.update_last_active(user)
    end
  end
end
