defmodule Morn do
  defmodule Schematic do
    defstruct [:permeate, :absorb, :kind]
  end

  def str(literal \\ nil) do
    %Schematic{
      kind: "string",
      permeate: fn input ->
        # FIXME this is ugly
        cond do
          is_binary(literal) ->
            if is_binary(input) && input == literal do
              {:ok, fn -> input end}
            else
              {:error, equality_error_str(input, literal)}
            end

          is_binary(input) ->
            {:ok, fn -> input end}

          true ->
            {:error, "#{inspect(input, pretty: true)} is not a string"}
        end
      end
    }
  end

  def int(literal \\ nil) do
    %Schematic{
      kind: "integer",
      permeate: fn input ->
        # FIXME this is ugly
        cond do
          is_integer(literal) ->
            if is_integer(input) && input == literal do
              {:ok, fn -> input end}
            else
              {:error, equality_error_str(input, literal)}
            end

          is_integer(input) ->
            {:ok, fn -> input end}

          true ->
            {:error, "#{inspect(input, pretty: true)} is not an int"}
        end
      end
    }
  end

  def list() do
    %Schematic{
      kind: "list",
      permeate: fn input ->
        if is_list(input) do
          {:ok, fn -> input end}
        else
          {:error, ~s|#{inspect(input, pretty: true)} is not a list|}
        end
      end
    }
  end

  def list(schematic) do
    %Schematic{
      kind: "list",
      permeate: fn input ->
        if is_list(input) do
          Enum.reduce_while(input, {:ok, fn -> [] end}, fn el, {:ok, absorber_acc} ->
            case permeate(schematic, el) do
              {:ok, absorber} ->
                absorber = fn ->
                  absorbed_el = absorber.()
                  absorbed_rest = absorber_acc.()

                  [absorbed_el | absorbed_rest]
                end

                {:cont, {:ok, absorber}}

              {:error, error} ->
                {:halt, {:error, ~s|#{error} in #{inspect(input, pretty: true)}|}}
            end
          end)
          |> then(fn
            {:ok, absorber} ->
              {:ok, fn -> Enum.reverse(absorber.()) end}

            error ->
              error
          end)
        else
          {:error, ~s|#{inspect(input, pretty: true)} is not a list|}
        end
      end
    }
  end

  def map(blueprint \\ %{}) do
    %Schematic{
      kind: "map",
      permeate: fn input ->
        if is_map(input) do
          bp_keys = Map.keys(blueprint)

          Enum.reduce_while(bp_keys, {:ok, fn -> input end}, fn bpk, {:ok, absorber_acc} ->
            schematic = blueprint[bpk]
            {from_key, to_key} = with key when not is_tuple(key) <- bpk, do: {key, key}

            if schematic do
              case permeate(schematic, input[from_key]) do
                {:ok, absorber} ->
                  absorber = fn ->
                    absorber_acc.()
                    |> Map.delete(from_key)
                    |> Map.put(to_key, absorber.())
                  end

                  {:cont, {:ok, absorber}}

                {:error, error} ->
                  {:halt,
                   {:error,
                    "#{error} for key #{inspect(from_key, pretty: true)} in #{inspect(input, pretty: true)}"}}
              end
            else
              {:halt,
               {:error,
                "#{inspect(input, pretty: true)} is missing a #{inspect(bpk, pretty: true)} key"}}
            end
          end)
        else
          {:error, "#{inspect(input, pretty: true)} is not a map"}
        end
      end
    }
  end

  def schema(mod, schematic) do
    schematic =
      Map.new(schematic, fn
        {k, v} when is_atom(k) ->
          {{to_string(k), k}, v}

        kv ->
          kv
      end)

    %Schematic{
      kind: "map",
      permeate: fn input ->
        with {:ok, absorber} <- permeate(map(schematic), input) do
          a1 = absorber.()
          dbg()
          {:ok, fn -> struct(mod, a1) end}
        end
      end
    }
  end

  def oneof(schematics) do
    %Schematic{
      kind: "oneof",
      permeate: fn input ->
        inquiry =
          Enum.find_value(schematics, fn schematic ->
            with {:error, _} <- permeate(schematic, input) do
              false
            end
          end)

        with nil <- inquiry do
          {:error,
           ~s|#{inspect(input, pretty: true)} is not one of: [#{Enum.map_join(schematics, ", ", & &1.kind)}]|}
        end
      end
    }
  end

  def permeate(schematic, input) do
    dbg()
    schematic.permeate.(input)
  end

  defp equality_error_str(input, literal) do
    "#{inspect(input, pretty: true)} != #{inspect(literal, pretty: true)}"
  end
end
