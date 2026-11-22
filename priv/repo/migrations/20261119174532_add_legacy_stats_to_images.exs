defmodule Philomena.Repo.Migrations.AddLegacyStatsToImages do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add :legacy_score, :integer
      add :legacy_upvotes, :integer
      add :legacy_downvotes, :integer
      add :legacy_faves, :integer
      add :legacy_source, :string
    end
  end
end
