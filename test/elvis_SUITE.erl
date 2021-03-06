-module(elvis_SUITE).

-export([
         all/0,
         init_per_suite/1,
         end_per_suite/1,
         chunk_fold_task/2
        ]).

-export([
         %% Rocking
         rock_with_empty_map_config/1,
         rock_with_empty_list_config/1,
         rock_with_incomplete_config/1,
         rock_with_list_config/1,
         rock_with_file_config/1,
         rock_with_old_config/1,
         rock_with_rebar_default_config/1,
         rock_this/1,
         rock_without_colors/1,
         rock_with_parsable/1,
         rock_with_no_output_has_no_output/1,
         rock_with_errors_has_output/1,
         rock_without_errors_has_no_output/1,
         rock_without_errors_and_with_verbose_has_output/1,
         rock_with_rule_groups/1,
         rock_this_skipping_files/1,
         rock_this_not_skipping_files/1,
         rock_with_include_dirs/1,
         %% Util & Config
         throw_configuration/1,
         find_file_and_check_src/1,
         find_file_with_ignore/1,
         invalid_file/1,
         to_string/1,
         chunk_fold/1
        ]).

-define(EXCLUDED_FUNS,
        [
         module_info,
         all,
         test,
         init_per_suite,
         end_per_suite,
         chunk_fold_task
        ]).

-type config() :: [{atom(), term()}].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Common test
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-spec all() -> [atom()].
all() ->
    Exports = elvis_SUITE:module_info(exports),
    [F || {F, _} <- Exports, not lists:member(F, ?EXCLUDED_FUNS)].

-spec init_per_suite(config()) -> config().
init_per_suite(Config) ->
    {ok, _} = application:ensure_all_started(elvis),
    Config.

-spec end_per_suite(config()) -> config().
end_per_suite(Config) ->
    ok = application:stop(elvis),
    Config.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Test Cases
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%
%%% Rocking

-spec rock_with_empty_map_config(config()) -> any().
rock_with_empty_map_config(_Config) ->
    ok = try
             ok = elvis_core:rock([#{}]),
             fail
         catch
             throw:{invalid_config, _} -> ok
         end,
    ok = try
             ok = elvis_core:rock([#{} || X <- lists:seq(1,10), X < 1]),
             fail
         catch
             throw:{invalid_config, _} -> ok
         end.

-spec rock_with_empty_list_config(config()) -> any().
rock_with_empty_list_config(_Config) ->
    ok = try
             ok = elvis_core:rock([#{}, #{}]),
             fail
         catch
             throw:{invalid_config, _} -> ok
         end.

-spec rock_with_incomplete_config(config()) -> any().
rock_with_incomplete_config(_Config) ->
    ElvisConfig = [#{src_dirs => ["src"]}],
    ok = try
             ok = elvis_core:rock(ElvisConfig),
             fail
         catch
             throw:{invalid_config, _} -> ok
         end.

-spec rock_with_list_config(config()) -> any().
rock_with_list_config(_Config) ->
    ElvisConfig = [#{src_dirs => ["src"],
                     rules => []},
                   #{dirs => ["."],
                     filter => "Makefile",
                     rules => []}],
    ok = try
             ok = elvis_core:rock(ElvisConfig)
         catch
             throw:{invalid_config, _} -> fail
         end.

-spec rock_with_file_config(config()) -> ok.
rock_with_file_config(_Config) ->
    Fun = fun() -> elvis_core:rock() end,
    Expected = "# \\.\\./\\.\\./_build/test/lib/elvis/test/" ++
               "examples/.*\\.erl.*FAIL",
    [_ | _] = check_some_line_output(Fun, Expected, fun matches_regex/2),
    ok.

-spec rock_with_old_config(config()) -> ok.
rock_with_old_config(_Config) ->
    ConfigPath = "../../config/old/elvis.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    ok = try
             ok = elvis_core:rock(ElvisConfig)
         catch
             throw:{invalid_config, _} -> fail
         end,

    ConfigPath1 = "../../config/old/elvis-test.config",
    ElvisConfig1 = elvis_config:load_file(ConfigPath1),
    ok = try
             ok = elvis_core:rock(ElvisConfig1)
         catch
             throw:{invalid_config, _} -> fail
         end,

    ConfigPath2 = "../../config/old/elvis-test-rule-config-list.config",
    ElvisConfig2 = elvis_config:load_file(ConfigPath2),
    ok = try
             ok = elvis_core:rock(ElvisConfig2)
         catch
             throw:{invalid_config, _} -> fail
         end.

-spec rock_with_rebar_default_config(config()) -> ok.
rock_with_rebar_default_config(_Config) ->
    {ok, _} = file:copy("../../config/rebar.config", "rebar.config"),
    [#{name := line_length}] = try
        {fail, Results} = elvis_core:rock(),
        [Rule || #{rules := [Rule]} <- Results]
    after
        file:delete("rebar.config")
    end,
    ok.

-spec rock_this(config()) -> ok.
rock_this(_Config) ->
    ok = elvis_core:rock_this(elvis_core),

    ok = try
             {fail, _} = elvis_core:rock_this("bla.erl")
         catch
             _:{enoent, "bla.erl"} -> ok
         end,

    Path =
        "../../_build/test/lib/elvis/test/examples/fail_line_length.erl",
    {fail, _} = elvis_core:rock_this(Path),

    ok.

-spec rock_without_colors(config()) -> ok.
rock_without_colors(_Config) ->
    ConfigPath = "../../config/test.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    Expected = "\\e.*?m",
    ok = try check_some_line_output(Fun, Expected, fun matches_regex/2) of
             Result -> ct:fail("Unexpected result ~p", [Result])
         catch
             _:{badmatch, []} -> ok
         end.

-spec rock_with_parsable(config()) -> ok.
rock_with_parsable(_Config) ->
    {ok, Default} = application:get_env(elvis, output_format),
    application:set_env(elvis, output_format, parsable),
    ConfigPath = "../../config/test.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    Expected = ".*\\.erl:\\d:[a-zA-Z0-9_]+:.*",
    ok = try check_some_line_output(Fun, Expected, fun matches_regex/2) of
             Result ->
                 io:format("~p~n", [Result])
         catch
             _:{badmatch, []} ->
                 ct:fail("Unexpected result ~p")
         after
             application:set_env(elvis, output_format, Default)
         end.

-spec rock_with_no_output_has_no_output(config()) -> ok.
rock_with_no_output_has_no_output(_Config) ->
    application:set_env(elvis, no_output, true),
    ConfigPath = "../../config/test.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    [] = check_no_line_output(Fun),
    application:unset_env(elvis, no_output),
    ok.

-spec rock_with_errors_has_output(config()) -> ok.
rock_with_errors_has_output(_Config) ->
    ConfigPath = "../../config/test.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    Expected = "FAIL",
    [_|_] = check_some_line_output(Fun, Expected, fun matches_regex/2),
    ok.

-spec rock_without_errors_has_no_output(config()) -> ok.
rock_without_errors_has_no_output(_Config) ->
    ConfigPath = "../../config/test.pass.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    [] = check_no_line_output(Fun),
    ok.

-spec rock_without_errors_and_with_verbose_has_output(config()) -> ok.
rock_without_errors_and_with_verbose_has_output(_Config) ->
    application:set_env(elvis, verbose, true),
    ConfigPath = "../../config/test.pass.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    Fun = fun() -> elvis_core:rock(ElvisConfig) end,
    Expected = "OK",
    [_|_] = check_some_line_output(Fun, Expected, fun matches_regex/2),
    application:unset_env(elvis, verbose),
    ok.

-spec rock_with_rule_groups(Config::config()) -> ok.
rock_with_rule_groups(_Config) ->
    % elvis_config will load default elvis_core rules for every
    % rule_group in the config.
    RulesGroupConfig =
        [#{dirs => ["src"], filter => "*.erl", ruleset => erl_files},
         #{dirs => ["."], filter => "Makefile", ruleset => makefiles},
         #{dirs => ["."], filter => "rebar.config", ruleset => rebar_config},
         #{dirs => ["."], filter => "elvis.config", ruleset => elvis_config}],
    ok = try
             ok = elvis_core:rock(RulesGroupConfig)
         catch
             throw:{invalid_config, _} -> fail
         end,
    % Override default elvis_core rules without ruleset should fail.
    OverrideFailConfig =
        [#{dirs => ["src"],
           rules => [{elvis_style, line_length, #{limit => 90}},
                     {elvis_style, state_record_and_type, disable}]}],
    ok = try
           _ = elvis_core:rock(OverrideFailConfig),
           fail
       catch
           throw:{invalid_config, _} -> ok
       end,
    % Override default elvis_core rules.
    OverrideConfig =
        [#{dirs => ["src"],
           filter => "*.erl",
           ruleset => erl_files,
           rules => [{elvis_style, line_length, #{limit => 90}}, % I like 90 chars per line.
                     {elvis_style, no_tabs, disable}]}, % I like tabs so disable this rule.
         #{dirs => ["."],
           filter => "Makefile",
           ruleset => makefiles,
           rules => [{elvis_project, no_deps_master_erlang_mk, disable}]}, % I like stable dependencies
         #{dirs => ["."], filter => "rebar.config", ruleset => rebar_config},
         #{dirs => ["."], filter => "elvis.config", ruleset => elvis_config}],
    ok = try
           ok = elvis_core:rock(OverrideConfig)
       catch
           throw:{invalid_config, _} -> fail
       end.

-spec rock_this_skipping_files(Config::config()) -> ok.
rock_this_skipping_files(_Config) ->
    meck:new(elvis_file, [passthrough]),
    Dirs = ["../../_build/test/lib/elvis/test/examples"],
    [File] = elvis_file:find_files(Dirs, "small.erl"),
    Path = elvis_file:path(File),
    ConfigPath = "../../config/elvis-test-pa.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    ok = elvis_core:rock_this(Path, ElvisConfig),
    0 = meck:num_calls(elvis_file, load_file_data, '_'),
    meck:unload(elvis_file),
    ok.

-spec rock_this_not_skipping_files(Config::config()) -> ok.
rock_this_not_skipping_files(_Config) ->
    meck:new(elvis_file, [passthrough]),
    Dirs = ["../../_build/test/lib/elvis/test/examples"],
    [File] = elvis_file:find_files(Dirs, "small.erl"),
    Path = elvis_file:path(File),
    ConfigPath = "../../config/test.config",
    ElvisConfig = elvis_config:load_file(ConfigPath),
    ok = elvis_core:rock_this(Path, ElvisConfig),
    1 = meck:num_calls(elvis_file, load_file_data, '_'),
    meck:unload(elvis_file),
    ok.

-spec rock_with_include_dirs(Config::config()) -> ok.
rock_with_include_dirs(_Config) ->
    meck:new(ktn_code, [unstick]),
    Dirs = ["../../test/examples"],
    Filter = "small.erl",
    _ = application:set_env(elvis, verbose, true),

    % Default `include_dirs' value is used when not provided
    meck:expect(ktn_code,
                parse_tree,
                fun(IDirs = ["include"], Content) ->
                    meck:passthrough([IDirs, Content]);
                   (_, _) ->
                    % Received include dirs are different than expected
                    throw({error, badmatch})
                end),
    DefaultConf = [#{dirs => Dirs, filter => Filter, ruleset => erl_files}],
    % We don't care about checks results
    _ = elvis_core:rock(DefaultConf),
    true = meck:validate(ktn_code),

    % Given `include_dirs' are used when provided
    CustomIDirs = ["path/to/include1", "path/to/include2"],
    meck:expect(ktn_code,
                parse_tree,
                fun(IDirs, Content) ->
                  case IDirs of
                    CustomIDirs ->
                      meck:passthrough([IDirs, Content]);
                    _ ->
                      % Received include dirs are different than expected
                      throw({error, badmatch})
                  end
                end),
    CustomConf = #{dirs => Dirs,
                   include_dirs => CustomIDirs,
                   filter => Filter,
                   ruleset => erl_files},
    % We don't care about checks results
    _ = elvis_core:rock([CustomConf]),
    true = meck:validate(ktn_code),

    % It must fail when the received include_dirs value is different
    % than expected.
    _ = elvis_core:rock([CustomConf#{include_dirs => ["unknown/path"]}]),
    false = meck:validate(ktn_code),

    % Clean up environment
    _ = application:set_env(elvis, verbose, false),
    _ = meck:unload(ktn_code),
    ok.


%%%%%%%%%%%%%%%
%%% Utils

-spec throw_configuration(config()) -> any().
throw_configuration(_Config) ->
    Filename = "./elvis.config",
    ok = file:write_file(Filename, <<"-">>),
    ok = try
             _ = elvis_config:default(),
             fail
         catch
             throw:_ -> ok
         after
             file:delete(Filename)
         end.

-spec find_file_and_check_src(config()) -> any().
find_file_and_check_src(_Config) ->
    Dirs = ["../../test/examples"],

    [] = elvis_file:find_files(Dirs, "doesnt_exist.erl"),
    [File] = elvis_file:find_files(Dirs, "small.erl"),

    {<<"-module(small).\n">>, _} = elvis_file:src(File),
    {error, enoent} = elvis_file:src(#{path => "doesnt_exist.erl"}).


-spec find_file_with_ignore(config()) -> any().
find_file_with_ignore(_Config) ->
    Dirs = ["../../test/examples"],
    Filter = "find_test*.erl",
    Ignore = elvis_config:ignore(#{ignore => [find_test1]}),
    Files = [_, _] = elvis_file:find_files(Dirs, Filter),
    [_, _] = elvis_file:filter_files(Files, Dirs, Filter, []),
    [#{path := "../../test/examples/find_test2.erl"}] =
        elvis_file:filter_files(Files, Dirs, Filter, Ignore).

-spec invalid_file(config()) -> any().
invalid_file(_Config) ->
    ok = try
             {error, _} = elvis_file:src(#{}),
             fail
         catch
             throw:{invalid_file, #{}} -> ok
         end.

-spec to_string(config()) -> any().
to_string(_Config) ->
    "1" = elvis_utils:to_str(1),
    "hello" = elvis_utils:to_str(<<"hello">>),
    "atom" = elvis_utils:to_str(atom).

-spec chunk_fold(config()) -> any().
chunk_fold(_Config) ->
    Multiplier = 10,
    List = lists:seq(1,10),
    {ok, Value} = elvis_task:chunk_fold({?MODULE, chunk_fold_task},
                                        fun(Elem, Acc) ->
                                                {ok, Acc + Elem}
                                        end, 0, [Multiplier], lists:seq(1,10), 10),
    Value = lists:sum(
              lists:map(fun(E) -> E * Multiplier end, List)),

    {error, {error, undef}} =
        elvis_task:chunk_fold({?MODULE, chunk_fold_task_do_not_exist},
                              fun(Elem, Acc) ->
                                      {ok, Acc + Elem}
                              end, 0, [Multiplier], lists:seq(1,10), 10).


-spec chunk_fold_task(integer(), integer()) -> {ok, integer()}.
chunk_fold_task(Elem, Multiplier) ->
    {ok, Elem * Multiplier}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Private
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

check_some_line_output(Fun, Expected, FilterFun) ->
    _ = ct:capture_start(),
    _ = Fun(),
    _ = ct:capture_stop(),
    Lines = ct:capture_get([]),
    ListFun = fun(Line) -> FilterFun(Line, Expected) end,
    [_ | _] = lists:filter(ListFun, Lines).

check_no_line_output(Fun) ->
    _ = ct:capture_start(),
    _ = Fun(),
    _ = ct:capture_stop(),
    [] = ct:capture_get([]).

matches_regex(Result, Regex) ->
    case re:run(Result, Regex) of
        {match, _} -> true;
        nomatch ->
            false
    end.
