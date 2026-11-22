defmodule Philomena.Images.TagValidator do
  alias Philomena.Config
  import Ecto.Changeset

  def validate_tags(changeset) do
    tags = changeset |> get_field(:tags)

    changeset
    |> validate_tag_input(tags)
    |> set_rating_changed()
  end

  defp set_rating_changed(changeset) do
    added_tags = changeset |> get_field(:added_tags) |> extract_names(changeset)
    removed_tags = changeset |> get_field(:removed_tags) |> extract_names(changeset)
    ratings = all_ratings()

    added_ratings = MapSet.intersection(ratings, added_tags) |> MapSet.size()
    removed_ratings = MapSet.intersection(ratings, removed_tags) |> MapSet.size()

    put_change(changeset, :ratings_changed, added_ratings + removed_ratings > 0)
  end

  defp validate_tag_input(changeset, tags) do
    # Extract tag names from both resolved Tag structs AND the raw tag_input string
    tag_set = extract_names(tags, changeset)
    rating_set = ratings(tag_set)

    changeset
    |> validate_number_of_tags(tag_set, 3)
    |> validate_bad_words(tag_set)
    |> validate_has_rating(rating_set, changeset, tag_set)
    |> validate_safe(rating_set)
    |> validate_sexual_exclusion(rating_set)
    |> validate_horror_exclusion(rating_set)
    |> validate_has_body_type(tag_set)
  end

  defp ratings(tag_set) do
    safe = MapSet.intersection(tag_set, safe_rating())
    sexual = MapSet.intersection(tag_set, sexual_ratings())
    horror = MapSet.intersection(tag_set, horror_ratings())
    gross = MapSet.intersection(tag_set, gross_rating())

    %{
      safe: safe,
      sexual: sexual,
      horror: horror,
      gross: gross
    }
  end

  defp validate_number_of_tags(changeset, tag_set, num) do
    if MapSet.size(tag_set) < num do
      add_error_unique(changeset, :tag_input, "must contain at least #{num} tags")
    else
      changeset
    end
  end

  def validate_bad_words(changeset, tag_set) do
    bad_words = MapSet.new(Config.get(:tag)["blacklist"])
    intersection = MapSet.intersection(tag_set, bad_words)

    if MapSet.size(intersection) > 0 do
      Enum.reduce(
        intersection,
        changeset,
        &add_error_unique(&2, :tag_input, "contains forbidden tag `#{&1}'")
      )
    else
      changeset
    end
  end

  defp validate_has_rating(changeset, %{safe: s, sexual: x, horror: h, gross: g}, _changeset, tag_set) do
    has_rating? =
      MapSet.size(s) > 0 or MapSet.size(x) > 0 or MapSet.size(h) > 0 or MapSet.size(g) > 0

    user_id = get_field(changeset, :user_id)
    is_admin? = user_id == 1
    is_import? = MapSet.member?(tag_set, "imported from e6ai")

    cond do
      has_rating? ->
        changeset

      is_admin? or is_import? ->
        # Admin and importer bypass if missing
        changeset

      true ->
        add_error_unique(changeset, :tag_input, "must contain at least one rating tag")
    end
  end

  defp validate_safe(changeset, %{safe: s, sexual: x, horror: h, gross: g}) do
    if MapSet.size(s) > 0 and (MapSet.size(x) > 0 or MapSet.size(h) > 0 or MapSet.size(g) > 0) do
      add_error_unique(changeset, :tag_input, "may not contain any other rating if safe")
    else
      changeset
    end
  end

  defp validate_sexual_exclusion(changeset, %{sexual: x}) do
    if MapSet.size(x) > 1 do
      add_error_unique(changeset, :tag_input, "may contain at most one sexual rating")
    else
      changeset
    end
  end

  defp validate_horror_exclusion(changeset, %{horror: h}) do
    if MapSet.size(h) > 1 do
      add_error_unique(changeset, :tag_input, "may contain at most one grim rating")
    else
      changeset
    end
  end

  defp validate_has_body_type(changeset, tag_set) do
    if exempt_from_body_type?(changeset, tag_set) do
      changeset
    else
      intersection = MapSet.intersection(tag_set, body_type_tags())

      if MapSet.size(intersection) > 0 do
        changeset
      else
        add_error_unique(
          changeset,
          :tag_input,
          "must contain at least one body-type tag (feral, anthro, semi-anthro, human, humanoid, taur, or zero pictured)"
        )
      end
    end
  end

  defp exempt_from_body_type?(changeset, tag_set) do
    exempt_tags = [
      "imported from e6ai",
      "imported from blep.art",
      "imported from floofgens"
    ]

    is_import? = Enum.any?(exempt_tags, &MapSet.member?(tag_set, &1))
    user_id = get_field(changeset, :user_id)
    is_admin? = user_id == 1

    is_import? or is_admin?
  end

  defp body_type_tags, do: MapSet.new(["anthro", "feral", "human", "humanoid", "semi-anthro", "taur", "zero pictured"])

  # Extracts tag names from both resolved Tag structs AND raw tag_input string
  defp extract_names(tags, changeset) do
    names_from_tags =
      case tags do
        list when is_list(list) -> Enum.map(list, & &1.name)
        _ -> []
      end

    raw_input =
      get_change(changeset, :tag_input) ||
      get_field(changeset, :tag_input) ||
      (changeset.params && (changeset.params["tag_input"] || changeset.params[:tag_input])) ||
      ""

    names_from_input =
      raw_input
      |> to_string()
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.reject(&(&1 == ""))

    MapSet.new(names_from_tags ++ names_from_input)
  end

  # Helper to prevent duplicate error messages on the same field
  defp add_error_unique(changeset, field, message) do
    already_present? =
      Enum.any?(changeset.errors, fn {f, {msg, _}} -> f == field and msg == message end)

    if already_present? do
      changeset
    else
      add_error(changeset, field, message)
    end
  end

  defp all_ratings do
    safe_rating()
    |> MapSet.union(sexual_ratings())
    |> MapSet.union(horror_ratings())
    |> MapSet.union(gross_rating())
  end

  defp safe_rating, do: MapSet.new(["safe"])
  defp sexual_ratings, do: MapSet.new(["suggestive", "questionable", "explicit"])
  defp horror_ratings, do: MapSet.new(["semi-grimdark", "grimdark"])
  defp gross_rating, do: MapSet.new(["grotesque"])
end
