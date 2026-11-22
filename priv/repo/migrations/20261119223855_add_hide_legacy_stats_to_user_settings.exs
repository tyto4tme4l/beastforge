defmodule Philomena.Repo.Migrations.AddHideLegacyStatsToUserSettings do
  use Ecto.Migration

  def change do
    alter table(:user_settings) do
      add :hide_legacy_stats, :boolean, default: false, null: false
    end
  end
end
