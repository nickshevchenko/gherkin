defmodule Gherkin.Parser do

  alias Gherkin.{TokenScanner,Token}

  defstruct scanner_state: nil, builder: nil, builder_state: nil

  def new(builder) do
    %__MODULE__{builder: builder}
  end

  def parse(parser, io) do
    initial_state = %{parser | scanner_state: TokenScanner.new, builder_state: call_builder(parser, :new)}
    final_state = parser_loop(initial_state, io)
    #IO.puts "final_state"
    #IO.inspect final_state
    call_builder(parser, :get_result, [final_state.builder_state])
  end
  defp parser_loop(parser_state, io) do
    #IO.inspect(parser)

    {:ok, token, new_scanner_state} = TokenScanner.read(io, parser_state.scanner_state)

    #IO.puts "----------------------------------------"

    #IO.inspect(token)

    {:ok, matched_token} = match_token(parser_state, token)

   # IO.inspect(matched_token)

    new_parser_state = %{parser_state |
      scanner_state: new_scanner_state,
      builder_state: call_builder(parser_state, :build, [parser_state.builder_state, matched_token])
    }


    if Token.eof?(matched_token) do
      #IO.puts "out"
      new_parser_state
    else
      #IO.puts "in"
      parser_loop(new_parser_state, io)
    end
  end

  defp call_builder(%{builder: builder}, fun, args \\ []) do
    Kernel.apply(builder, fun, args)
  end

  def allowed_token_types_for_state(_) do
    [:EOF, :Empty, :FeatureLine, :ScenarioLine, :StepLine]
  end

  def match_token(state, token) do
    # TODO get current dialect from state
    case find_token_type("en", token, allowed_token_types_for_state(state)) do
      :error ->
        IO.inspect(token)
        :error
      token_type_to_match ->
        do_match_token(state, token_type_to_match, token)
    end
  end

  defp find_token_type(dialect, token, allowed_types) do
    allowed_types
    |> Enum.find(:error, fn (token_type) -> token_of_type?(dialect, token, token_type) end)
  end


  defp token_of_type?(_, %{line: nil}, :EOF), do: true
  defp token_of_type?(_, %{line: %{trimmed_line_text: ""}}, :Empty), do: true

  @keyword_to_token_type %{
    "scenario" => :ScenarioLine,
    "feature"  => :FeatureLine,
    "given"    => :StepLine,
    "when"     => :StepLine,
    "then"     => :StepLine,
    "but"      => :StepLine,
    "*"        => :StepLine,
  }

  @tokens_table Path.join([__DIR__, "..", "..", "gherkin-languages.json"])
    |> File.read!
    |> Poison.decode!
    |> Enum.flat_map(fn ({language, keywords}) ->
      keywords
      |> Dict.drop(~w[name native])
      |> Enum.flat_map(fn ({keyword, aliases}) ->
        aliases
        |> Enum.map(fn (translated_keyword) ->
          {language, translated_keyword, Dict.get(@keyword_to_token_type, keyword, :TokenTypeNotYetMapped)}
        end)
      end)
    end)

  for {language, keyword, token_type} <- @tokens_table do

    defp token_of_type?(unquote(language), %{line: %{trimmed_line_text: unquote(keyword) <> _}}, unquote(token_type)), do: true

  end

  # Tentatively replaced by macro code above
  #defp token_of_type?(%{line: %{trimmed_line_text: "Feature:" <> _}}, :FeatureLine), do: true
  #defp token_of_type?(%{line: %{trimmed_line_text: "Scenario:" <> _}}, :ScenarioLine), do: true
  #defp token_of_type?(%{line: %{trimmed_line_text: "Given " <> _}}, :StepLine), do: true

  defp token_of_type?(_, _, _), do: false

  defp do_match_token(_, :EOF, token = %{line: nil}), do: {:ok, token}
  defp do_match_token(_, :Empty, token) do
    matched_token = %{token |
      matched_type: :Empty,
      matched_text: nil,
      matched_keyword: nil,
      matched_indent: 0,
      matched_items: [],
      location: %{token.location | column: 1},
    }
    {:ok, matched_token}
  end
  defp do_match_token(_, :FeatureLine, token = %{line: %{trimmed_line_text: text, indent: indent}}) do
    matched_token = %{token |
      matched_type: :FeatureLine,
      # XXX hardcoded offsets, breaks with other dialects
      matched_text: text |> String.slice(8..-1) |> String.strip,
      matched_keyword: text |> String.slice(0, 7),
      matched_indent: indent,
      matched_items: [],
      location: %{token.location | column: indent + 1},
    }
    {:ok, matched_token}
  end
  defp do_match_token(_, :ScenarioLine, token = %{line: %{trimmed_line_text: text, indent: indent}}) do
    matched_token = %{token |
      matched_type: :ScenarioLine,
      # XXX hardcoded offsets, breaks with other dialects
      matched_text: text |> String.slice(9..-1) |> String.strip,
      matched_keyword: text |> String.slice(0, 8),
      matched_indent: indent,
      matched_items: [],
      location: %{token.location | column: indent + 1},
    }
    {:ok, matched_token}
  end
  defp do_match_token(_, :StepLine, token = %{line: %{trimmed_line_text: text, indent: indent}}) do
    matched_token =  %{token |
      matched_type: :StepLine,
      # XXX hardcoded offsets, breaks with other dialects
      matched_text: text |> String.slice(6..-1) |> String.strip,
      matched_keyword: text |> String.slice(0, 6),
      matched_indent: indent,
      matched_items: [],
      location: %{token.location | column: indent + 1},
    }
    {:ok, matched_token}
  end

end