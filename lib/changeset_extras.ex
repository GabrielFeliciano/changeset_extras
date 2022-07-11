defmodule ChangesetExtras do
  @moduledoc """
  Module holding any util changeset process

  Documentation incoming
  """

  import Ecto.Changeset
  alias Ecto.Changeset

  @doc """
  Compares current enum value with old value, and validates if it's a allowed transition
  """
  @type transitions() :: list(atom())
  @spec validate_enum_transitions(
          Changeset.t(),
          atom(),
          %{atom() => :all | {:all, transitions()} | nil | transitions()}
        ) :: Changeset.t()
  def validate_enum_transitions(
        %Changeset{} = changeset,
        property,
        transition_map
      ) do
    old_value = Map.get(changeset.data, property)
    new_value = get_change(changeset, property)

    is_changing? = new_value == nil

    valid_transition? =
      case transition_map[old_value] do
        :all ->
          new_value in (changeset
                        |> get_enum_values_from_property(property)
                        |> List.delete(old_value))

        {:all, unallowed_transitions} when is_list(unallowed_transitions) ->
          new_value in (changeset
                        |> get_enum_values_from_property(property)
                        |> Kernel.--([old_value | unallowed_transitions]))

        nil ->
          false

        allowed_transitions when is_list(allowed_transitions) ->
          new_value in allowed_transitions
      end

    if is_changing? or valid_transition? do
      changeset
    else
      error_msg = "must be a valid transition"
      add_error(changeset, property, error_msg)
    end
  end

  defp get_enum_values_from_property(%Changeset{} = changeset, property) do
    changeset.data.__struct__
    |> Ecto.Enum.mappings(property)
    |> Keyword.keys()
  end

  @doc """
  Cascades the change of a field into other fields
  """
  @spec cascade_change(Ecto.Changeset.t(), atom(), atom() | list(atom()), function()) ::
          Ecto.Changeset.t()
  def cascade_change(changeset, selected_field, apply_fields, mapper)
      when is_list(apply_fields) do
    old_value = Map.get(changeset.data, selected_field)
    change = get_change(changeset, selected_field)

    if is_nil(change) do
      changeset
    else
      change_map =
        Enum.reduce(
          apply_fields,
          %{},
          &reduce_observer_fields(&1, &2, change, old_value, mapper)
        )

      changeset
      |> cast(change_map, apply_fields)
    end
  end

  def cascade_change(changeset, selected_field, apply_field, mapper)
      when not is_list(apply_field) do
    old_value = Map.get(changeset.data, selected_field)
    change = get_change(changeset, selected_field)

    if is_nil(change) do
      changeset
    else
      change_map = %{apply_field => mapper.(change, old_value)}

      cast(changeset, change_map, [apply_field])
    end
  end

  defp reduce_observer_fields(field, map, change, old_value, mapper) do
    new_change = mapper.(field, change, old_value)

    if is_nil(new_change) do
      map
    else
      Map.put(map, field, new_change)
    end
  end

  @doc """
  Validates if a field has a datetime that goes after the referenced datetime
  """
  def validate_after_date(changeset, property, reference_date) when is_atom(property) do
    changeset
    |> get_field(property, nil)
    |> case do
      %DateTime{} = date ->
        if DateTime.compare(date, reference_date) != :gt do
          message = "must be after #{DateTime.to_iso8601(reference_date)}"
          add_error(changeset, property, message)
        else
          changeset
        end

      _ ->
        add_error(changeset, property, "must be a valid date")
    end
  end

  @doc """
  Validates if at least one of the fields aren't nil
  """
  def at_least_one_field(changeset, fields) do
    fields
    |> Enum.map(fn field -> get_field(changeset, field, nil) end)
    |> Enum.all?(fn value -> value == nil or value == "" end)
    |> case do
      true -> add_error(changeset, :at_least_one_field, at_least_one_field_message(fields))
      false -> changeset
    end
  end

  defp at_least_one_field_message(fields) do
    fields_str = Enum.map_join(fields, ", ", &to_string/1)
    "at least one of those fields must be defined: #{fields_str}"
  end

  @doc """
  Check :at_least_one_field constraint
  Needs to be defined in the migrations
  """
  def at_least_one_field_constraint(changeset, fields) do
    check_constraint(changeset, :at_least_one_field,
      name: :at_least_one_field,
      message: at_least_one_field_message(fields)
    )
  end

  @doc """
  Put assoc only if value is array
  """
  def put_assoc_if_array(changeset, name, values, opts \\ [])

  def put_assoc_if_array(changeset, name, values, opts) when is_list(values) do
    put_assoc(changeset, name, values, opts)
  end

  def put_assoc_if_array(changeset, _name, _values, _opts), do: changeset
end
