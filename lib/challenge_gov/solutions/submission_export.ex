defmodule ChallengeGov.Solutions.SubmissionExport do
  @moduledoc """
  Submission export schema
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias ChallengeGov.Challenges.Challenge

  @type t :: %__MODULE__{}

  @statuses [
    %{id: "pending", label: "Draft"},
    %{id: "cancelled", label: "Cancelled"},
    %{id: "completed", label: "Submitted"},
    %{id: "outdated", label: "Outdated"}
  ]

  @judging_statuses [
    "not_selected",
    "selected",
    "winner"
  ]

  def statuses(), do: @statuses

  def status_ids() do
    Enum.map(@statuses, & &1.id)
  end

  def judging_statuses, do: @judging_statuses

  schema "submission_exports" do
    # Associations
    belongs_to(:challenge, Challenge)

    # Fields
    field(:phase_ids, {:array, :string}, default: [])
    field(:judging_status, :string)
    field(:format, :string)
    field(:status, :string, default: "pending")
    field(:key, Ecto.UUID, read_after_writes: true)

    # Meta Timestamps
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [
      :phase_ids,
      :judging_status,
      :format,
      :status
    ])
    |> validate_required([
      :phase_ids,
      :judging_status,
      :format
    ])
  end

  def create_changeset(struct, params, challenge) do
    struct
    |> changeset(params)
    |> put_change(:challenge, challenge)
  end

  def update_changeset(struct, params) do
    struct
    |> changeset(params)
  end
end
