defmodule Mix.Tasks.RemoveUnused do
  @moduledoc """
  The core of the package. Run this task to remove unused code from your project.
  """

  use Mix.Task

  @doc """
  Runs the core of the package. You wouldn't use this directly, but rather run `mix remove_unused` in the console.
  """
  def run(_) do
    diagnostics = list_diagnostics()

    diagnostics
    |> Enum.filter(&filter_unused/1)
    |> Enum.group_by(& &1.file, & &1.position)
    |> Enum.each(&remove_lines/1)

    diagnostics
    |> Enum.filter(&filter_unused_variables/1)
    |> Enum.group_by(& &1.file, &{&1.position, &1.message})
    |> IO.inspect(label: "unused variables group by ## ")
    |> Enum.each(&underscore_variable/1)
  end

  defp list_diagnostics do
    case Mix.Task.rerun("compile.elixir", ["--all-warnings", "--no-compile"]) do
      {:noop, results} -> results
      {:ok, results} -> results
      :noop -> []
      {:error, _results} -> []
    end
  end

  defp filter_unused(%{message: "unused" <> _msg}), do: true
  defp filter_unused(_), do: false

  defp filter_unused_variables(%{message: message}) do
    # variable "month_date" is unused (if the variable is not meant to be used, prefix it with an underscore)
    # iex(test@Mainframe03)4> Regex.named_captures(~r/^variable\s(?<var>[a-zA-Z0-9_]+)\sis\sunused/, "variable month_date is unused ddd")
    # %{"var" => "month_date"}
    case Regex.named_captures(~r/^variable\s"(?<var>[a-zA-Z0-9_]+)"\sis\sunused/, message) do
      nil ->
        false

      msg ->
        IO.puts("unused variable: #{inspect(message)}")
        true
    end
  end

  defp remove_lines({file_path, line_numbers}) do
    tmp_file_path = file_path <> ".tmp"

    file_path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {line, i} ->
      if i in Enum.map(line_numbers, fn n -> elem(n, 0) end) do
        ""
      else
        line
      end
    end)
    |> Stream.into(File.stream!(tmp_file_path))
    |> Stream.run()

    File.cp(tmp_file_path, file_path, on_conflict: fn _, _ -> true end)
    File.rm(tmp_file_path)
  end

  defp underscore_variable({file_path, line_numbers}) do
    tmp_file_path = file_path <> ".tmp"

    file_path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {line, i} ->
      ## [{{10, 3}, "message1"}, {{11, 10}, "message2"}, {{13, 17}, "..."}}]
      if i in Enum.map(line_numbers, fn {position, message} -> elem(position, 0) end) do
        insert_position =
          line_numbers
          |> Enum.find(fn {position, message} -> elem(position, 0) == i end)
          |> elem(0)
          |> elem(1)

        char = "_"
        ## insert underscore in nth position of the line
        then(
          line,
          &(String.slice(&1, 0..(insert_position - 2)) <>
              char <> String.slice(&1, (insert_position - 1)..String.length(&1)))
        )

      else
        line
      end
    end)
    |> Stream.into(File.stream!(tmp_file_path))
    |> Stream.run()

    File.cp(tmp_file_path, file_path, on_conflict: fn _, _ -> true end)
    File.rm(tmp_file_path)
  end
end
