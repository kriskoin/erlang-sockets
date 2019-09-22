%%  based on socket examples from Joe Armstrong's "Programming Erlang, Second Edition".
-module(sockets).
-compile(export_all).
-import(lists, [reverse/1]).

string2value(Str) ->
    {ok, Tokens, _} = erl_scan:string(Str ++ "."),
    {ok, Exprs} = erl_parse:parse_exprs(Tokens),
    Bindings = erl_eval:new_bindings(),
    {value, Value, _} = erl_eval:exprs(Exprs, Bindings),
    Value.

tiny_get_url() ->
    tiny_get_url("www.asite.com").

tiny_get_url(Host) ->
    {ok, Socket} = gen_tcp:connect(Host, 80, [binary, {packet, 0}]),
    ok = gen_tcp:send(Socket, "GET / HTTP/1.0\r\n\r\n"),
    receive_data(Socket, []).

receive_data(Socket, SoFar) ->
    io:format("~p~n", [SoFar]),
    receive
        {tcp, Socket, Bin} ->
            receive_data(Socket, [Bin|SoFar]);
        {tcp_closed, Socket} ->
            list_to_binary(reverse(SoFar))
    end.

start_tiny_server() ->
    {ok, Listen} = gen_tcp:listen(7475, [binary, {packet, 4},
                                         {reuseaddr, true},
                                         {active, true}]),
    {ok, Socket} = gen_tcp:accept(Listen),
    gen_tcp:close(Listen),
    loop(Socket).

start_seq_server() ->
    {ok, Listen} = gen_tcp:listen(7475, [binary, {packet, 4},
                                         {reuseaddr, true},
                                         {active, true}]),
    seq_loop(Listen).

seq_loop(Listen) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    loop(Socket),
    seq_loop(Listen).

start_parallel_server() ->
    {ok, Listen} = gen_tcp:listen(7475, [binary, {packet, 4},
                                         {reuseaddr, true},
                                         {active, true}]),
    spawn(fun() -> par_connect(Listen) end).

par_connect(Listen) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    spawn(fun() -> par_connect(Listen) end),
    loop(Socket).

loop(Socket) ->
    receive
       {tcp, Socket, Bin} ->
            io:format("Server received binary =~p~n", [Bin]),
            Str = binary_to_term(Bin),
            io:format("Server (unpacked) ~p~n", [Str]),
            Reply = string2value(Str),
            io:format("Server replying = ~p~n", [Reply]),
            gen_tcp:send(Socket, term_to_binary(Reply)),
            loop(Socket);
        {tcp_closed, Socket} ->
            io:format("Server socket closed~n")
    end.

tiny_client_eval(Str) ->
    {ok, Socket} =
        gen_tcp:connect("localhost", 7475,
                        [binary, {packet, 4}]),
    ok = gen_tcp:send(Socket, term_to_binary(Str)),
    receive
       {tcp, Socket, Bin} ->
            io:format("Client received binary = ~p~n", [Bin]),
            Val = binary_to_term(Bin),
            io:format("Client result = ~p~n", [Val]),
            gen_tcp:close(Socket)
    end.