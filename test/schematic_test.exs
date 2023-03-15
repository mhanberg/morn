defmodule SchematicTest do
  use ExUnit.Case, async: true

  import Schematic

  defmodule Request do
    defstruct [:jsonrpc, :method, :params, :id]
  end

  describe "assimilate" do
    test "str/0" do
      schematic = str()
      input = "lsp is kool"
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "str/1" do
      schematic = str("lsp is kool")
      input = "lsp is kool"
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "int/0" do
      schematic = int()
      input = 999
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "int/1" do
      schematic = int(999)
      input = 999
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "map/0" do
      schematic = map()
      input = %{}
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "list/0" do
      schematic = list()
      input = ["hello", "there"]
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "list/1" do
      schematic = list(int())
      input = [1, 2, 3]
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "oneof/1" do
      schematic = oneof([int(), str()])
      input = 1
      assert {:ok, input} == assimilate(schematic, input)

      input = "hi"
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "map/1" do
      schematic =
        map(%{
          "foo" => str()
        })

      input = %{"foo" => "hi there!", "bar" => []}
      assert {:ok, input} == assimilate(schematic, input)
    end

    test "complex" do
      schematic =
        map(%{
          "foo" => oneof([str(), int()]),
          "bar" =>
            map(%{
              "alice" => str("Alice"),
              "bob" => list(str()),
              "carol" =>
                map(%{
                  "baz" =>
                    oneof([
                      map(%{"one" => int()}),
                      map(%{"two" => str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok, input} == assimilate(schematic, input)
    end

    test "complex transformer" do
      schematic =
        map(%{
          {"foo", :foo} => oneof([str(), int()]),
          {"bar", :bar} =>
            map(%{
              {"alice", :alice} => str("Alice"),
              {"bob", :bob} => list(str()),
              {"carol", :carol} =>
                map(%{
                  {"baz", :baz} =>
                    oneof([
                      map(%{{"one", :one} => int()}),
                      map(%{{"two", :two} => str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok,
              %{
                foo: "hi there!",
                bar: %{
                  alice: "Alice",
                  bob: ["is", "the", "coolest"],
                  carol: %{
                    baz: %{
                      two: "the second"
                    }
                  }
                }
              }} == assimilate(schematic, input)
    end

    defmodule S1 do
      defstruct [:foo, :bar]
    end

    defmodule S2 do
      defstruct [:alice, :bob, :carol]
    end

    defmodule S3 do
      defstruct [:baz]
    end

    defmodule S4 do
      defstruct [:one]
    end

    defmodule S5 do
      defstruct [:two]
    end

    test "complex transformer with structs" do
      schematic =
        schema(S1, %{
          {"foo", :foo} => oneof([str(), int()]),
          bar:
            schema(S2, %{
              {"alice", :alice} => str("Alice"),
              {"bob", :bob} => list(str()),
              {"carol", :carol} =>
                schema(S3, %{
                  {"baz", :baz} =>
                    oneof([
                      schema(S4, %{one: int()}),
                      schema(S5, %{two: str()})
                    ])
                })
            })
        })

      input = %{
        "foo" => "hi there!",
        "bar" => %{
          "alice" => "Alice",
          "bob" => ["is", "the", "coolest"],
          "carol" => %{
            "baz" => %{
              "two" => "the second"
            }
          }
        }
      }

      assert {:ok,
              %S1{
                foo: "hi there!",
                bar: %S2{
                  alice: "Alice",
                  bob: ["is", "the", "coolest"],
                  carol: %S3{
                    baz: %S5{
                      two: "the second"
                    }
                  }
                }
              }} == assimilate(schematic, input)
    end
  end

  describe "error messages" do
    test "validates every key of a map" do
      teacher =
        map(%{
          "name" => str(),
          "grade" => int(),
          "prefix" => oneof([str("Mrs."), str("Mr.")])
        })

      schematic =
        map(%{
          "foo" => oneof([str(), int(), list()]),
          "bar" => str(),
          "baz" => list(),
          "alice" => str("foo"),
          "bob" => int(99),
          "carol" => oneof([null(), int()]),
          "dave" =>
            map(%{
              "first" => int(),
              "second" => list(oneof([list(), map()])),
              "teacher" => teacher
            })
        })

      input = %{
        "foo" => %{},
        "bar" => 1,
        "baz" => "hi!",
        "alice" => "bob",
        "dave" => %{
          "first" => "name",
          "second" => ["hi", "there"],
          "teacher" => %{}
        }
      }

      assert {:error,
              %{
                "alice" => "expected the literal string \"foo\"",
                "bar" => "expected a string",
                "baz" => "expected a list",
                "bob" => "expected the literal integer 99",
                "dave" => %{
                  "first" => "expected an integer",
                  "second" => "expected a list of either a list or a map",
                  "teacher" => %{
                    "grade" => "expected an integer",
                    "name" => "expected a string",
                    "prefix" =>
                      "expected either the literal string \"Mrs.\" or the literal string \"Mr.\""
                  }
                },
                "foo" => "expected either a string, an integer, or a list"
              }} == assimilate(schematic, input)
    end
  end
end
