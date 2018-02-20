defmodule WoodyTest do
  use ExUnit.Case
  import Woody.Logger, only: [transform: 1]

  test "transform" do
    assert transform(["a"]) == %{message: "a"}
    assert transform(["a", "b"]) == %{message: "a b"}

    assert transform(["message", %{a: "b"}]) == %{:message => "message", "a_str" => "b"}
    assert transform(["message", %{a: 1}]) == %{:message => "message", "a_int" => 1}
    assert transform(["message", %{a: 1.3}]) == %{:message => "message", "a_flt" => 1.3}
    assert transform(["message", %{a: true}]) == %{:message => "message", "a_bool" => true}
    assert transform(["message", %{a: {"tuple"}}]) == %{:message => "message", "a_str" => "{\"tuple\"}"}
    assert transform(["message", %{a: :atom}]) == %{:message => "message", "a_str" => "atom"}
    assert transform(["message", %{a: %{a: "b"}}]) == %{:message => "message", :a => %{"a_str" => "b"}}
    assert transform(["message", %{a: ~D[2017-11-13]}]) == %{:message => "message", "a_date" => "2017-11-13"}
    {:ok, dt, _} = DateTime.from_iso8601 "2017-11-13T10:00:00+00:00"
    assert transform(["message", %{a: dt}]) == %{:message => "message", "a_datetime" => "2017-11-13T10:00:00Z"}
    assert transform(["message", %{a: "b", b: 1, c: 1.3, d: true, e: ["1"], f: :atom, g: {"tuple"}, h: %{i: "j"}}]) == %{:message => "message", "a_str" => "b", "b_int" => 1, "c_flt" => 1.3, "d_bool" => true, "f_str" => "atom", "g_str" => "{\"tuple\"}", "e_str" => "[\"1\"]", :h => %{"i_str" => "j"}}
  end

end
