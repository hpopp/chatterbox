-module(http2_spec_5_1_SUITE).

-include("http2.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-compile([export_all]).

all() ->
    [
     sends_rst_stream_to_idle,
     half_closed_remote_sends_headers,
     sends_window_update_to_idle,
     client_sends_even_stream_id
    ].

init_per_suite(Config) ->
    application:ensure_started(crypto),
    chatterbox_test_buddy:start(Config).

end_per_suite(Config) ->
    chatterbox_test_buddy:stop(Config),
    ok.

sends_rst_stream_to_idle(_Config) ->
    {ok, Client} = http2c:start_link(),

    RstStream = #rst_stream{error_code=?CANCEL},
    RstStreamBin = http2_frame:to_binary(
                     {#frame_header{
                         stream_id=1
                        },
                      RstStream}),

    http2c:send_binary(Client, RstStreamBin),

    Resp = http2c:wait_for_n_frames(Client, 0, 1),
    ct:pal("Resp: ~p", [Resp]),
    ?assertEqual(1, length(Resp)),
    [{_GoAwayH, GoAway}] = Resp,
    ?PROTOCOL_ERROR = GoAway#goaway.error_code,
    ok.

half_closed_remote_sends_headers(_Config) ->
    {ok, Client} = http2c:start_link(),
    RequestHeaders =
        [
         {<<":method">>, <<"GET">>},
         {<<":path">>, <<"/index.html">>},
         {<<":scheme">>, <<"https">>},
         {<<":authority">>, <<"localhost:8080">>},
         {<<"accept">>, <<"*/*">>},
         {<<"accept-encoding">>, <<"gzip, deflate">>},
         {<<"user-agent">>, <<"chattercli/0.0.1 :D">>}
        ],

    {H1, EC} =
        http2_frame_headers:to_frames(1,
                                      RequestHeaders,
                                      hpack:new_context(),
                                      16384,
                                      true),

    http2c:send_unaltered_frames(Client, H1),

    %% The stream should be half closed remote now

    {H2, _EC2} =
        http2_frame_headers:to_frames(1,
                                      RequestHeaders,
                                      EC,
                                      16384,
                                      true),


    http2c:send_unaltered_frames(Client, H2),

    Resp = http2c:wait_for_n_frames(Client, 1, 4),
    ct:pal("Resp: ~p", [Resp]),
    ?assertEqual(4, length(Resp)),
    [{_, #headers{}}, {_, #data{}}, {RstStreamH, RstStream}, _] = Resp,
    ?assertEqual(?RST_STREAM, RstStreamH#frame_header.type),
    ?assertEqual(?STREAM_CLOSED, RstStream#rst_stream.error_code),

    ok.

sends_window_update_to_idle(_Config) ->
    {ok, Client} = http2c:start_link(),



    WU = #window_update{window_size_increment=1},
    WUBin = http2_frame:to_binary(
                     {#frame_header{
                         stream_id=1
                        },
                      WU}),

    http2c:send_binary(Client, WUBin),

    Resp = http2c:wait_for_n_frames(Client, 0, 1),
    ct:pal("Resp: ~p", [Resp]),
    ?assertEqual(1, length(Resp)),
    [{_GoAwayH, GoAway}] = Resp,
    ?PROTOCOL_ERROR = GoAway#goaway.error_code,
    ok.

client_sends_even_stream_id(_Config) ->
    {ok, Client} = http2c:start_link(),

    RequestHeaders =
        [
         {<<":method">>, <<"GET">>},
         {<<":path">>, <<"/index.html">>},
         {<<":scheme">>, <<"https">>},
         {<<":authority">>, <<"localhost:8080">>},
         {<<"accept">>, <<"*/*">>},
         {<<"accept-encoding">>, <<"gzip, deflate">>},
         {<<"user-agent">>, <<"chattercli/0.0.1 :D">>}
        ],

    {H, _} =
        http2_frame_headers:to_frames(2,
                                      RequestHeaders,
                                      hpack:new_context(),
                                      16384,
                                      false),

    http2c:send_unaltered_frames(Client, H),

    Resp = http2c:wait_for_n_frames(Client, 0, 1),
    ct:pal("Resp: ~p", [Resp]),
    ?assertEqual(1, length(Resp)),
    [{_GoAwayH, GoAway}] = Resp,
    ?PROTOCOL_ERROR = GoAway#goaway.error_code,
    ok.
