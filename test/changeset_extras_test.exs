defmodule ChangesetExtrasTest do
  @moduledoc false

  use ExUnit.Case
  alias Ecto.Changeset

  doctest ChangesetExtras

  defp traverse_errors(changeset) do
    Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defmodule PaymentTest do
    @moduledoc """
    For testing
    """

    use Ecto.Schema
    import Ecto.Changeset
    import ChangesetExtras

    embedded_schema do
      field(:status, Ecto.Enum, values: [:pending, :paid, :unpaid])
      field(:paid_at, :naive_datetime)
      field(:resource, :string)
      field(:richer_resource, :string)
    end

    def new_changeset(params \\ %{}), do: changeset(%__MODULE__{}, params)

    def changeset(struct, params) do
      struct
      |> cast(params, [:status])
      |> validate_enum_transitions(:status, %{
        pending: :all
      })
      |> cascade_change(:status, :paid_at, &register_paid_date/2)
      |> at_least_one_field([:resource, :richer_resource])
      |> validate_required([:status])
    end

    defp register_paid_date(current_status, _old) do
      if current_status == :paid, do: NaiveDateTime.utc_now()
    end
  end

  defmodule UserTest do
    @moduledoc """
    For testing
    """

    use Ecto.Schema
    import Ecto.Changeset
    import ChangesetExtras

    embedded_schema do
      field(:name, :string)
      field(:document, :string)
      field(:document_type, :string)
    end

    def new_changeset(params \\ %{}), do: changeset(%__MODULE__{}, params)

    def changeset(struct, params) do
      struct
      |> cast(params, [:name, :document, :document_type])
      |> put_document_type(:document, :document_type)
      |> validate_required([:name, :document, :document_type])
    end
  end

  describe "validate_enum_transitions/3" do
    test "Validate some transitions" do
      payment = %PaymentTest{status: :pending, resource: "::URL::"}

      updated_payment_result =
        payment
        |> PaymentTest.changeset(%{status: :paid})
        |> Changeset.apply_action(:update)

      assert {:ok, %PaymentTest{status: :paid}} = updated_payment_result
    end

    test "Validate some invalid transitions" do
      payment = %PaymentTest{status: :paid, resource: "::URL::"}

      updated_payment_changeset = PaymentTest.changeset(payment, %{status: :unpaid})

      assert %{status: ["must be a valid transition"]} ==
               traverse_errors(updated_payment_changeset)
    end

    test "Validate self transition with field :all" do
      payment = %PaymentTest{status: :pending, resource: "::URL::"}

      updated_payment_result =
        payment
        |> PaymentTest.changeset(%{status: :paid})
        |> Changeset.apply_action(:update)

      assert {:ok, %PaymentTest{status: :paid}} = updated_payment_result
    end

    test "Validate self transition with field" do
      payment = %PaymentTest{status: :pending, resource: "::URL::"}

      updated_payment_result =
        payment
        |> PaymentTest.changeset(%{status: :paid})
        |> Changeset.apply_action(:update)

      assert {:ok, %PaymentTest{status: :paid}} = updated_payment_result
    end
  end

  describe "cascade_change/4" do
    test "Add :paid_at field when paid" do
      payment = %PaymentTest{status: :paid}

      updated_payment_changeset = PaymentTest.changeset(payment, %{status: :paid})

      assert %{
               at_least_one_field: [
                 "at least one of those fields must be defined: resource, richer_resource"
               ]
             } ==
               traverse_errors(updated_payment_changeset)
    end
  end

  describe "put_document_type/4" do
    test "Add valid CPF to user" do
      name = "Kakashi Hatake"
      cpf = "51640724087"
      user = %UserTest{name: name}

      assert {:ok, %UserTest{name: ^name, document: ^cpf, document_type: "CPF"}} =
               user
               |> UserTest.changeset(%{document: cpf})
               |> Changeset.apply_action(:update)
    end

    test "Add valid CNPJ to user" do
      name = "Weasleys' Wizard Wheezes"
      cnpj = "39133468000190"
      user = %UserTest{name: name}

      assert {:ok, %UserTest{name: ^name, document: ^cnpj, document_type: "CNPJ"}} =
               user
               |> UserTest.changeset(%{document: cnpj})
               |> Changeset.apply_action(:update)
    end

    test "Add invalid document to user" do
      name = "Tyler Durden"
      cpf = "00000000000"
      user = %UserTest{name: name}

      assert %Changeset{valid?: false} = changeset = UserTest.changeset(user, %{document: cpf})

      assert %{
               document: ["Document is neither a valid CPF or CNPJ"],
               document_type: ["can't be blank"]
             } ==
               traverse_errors(changeset)
    end
  end
end
