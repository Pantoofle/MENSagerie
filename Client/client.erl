-module(client).
-export([client/2, new_client/2, init/0, main_input/0]).

% ------- ToDo List -------------
% rapport
% Discussion persistante
% Discussion de groupe
% Ouverture ports anti-virus


new_client(Server_Node, Name) ->
    {server, Server_Node} ! {self(), join, Name},
    Done = wait_answer(),
    if 
        Done -> client(Server_Node, 'Server');
        true -> io:format("identifiaction echouee ~n"),
                exit(self())
    end.

client(Server_Node, Last_Sender) ->
    receive
% ---------- Venant du serveur ------------------
        {recu, From_Name, Type, Msg} ->
            display_output(msg, {From_Name, Type, Msg}),
            io:fw
            client(Server_Node, From_Name);
        
        {info, Msg} -> 
            display_output(info, Msg),
            client(Server_Node, Last_Sender);
        
        {fatal_error, Msg} ->
            display_output(fatal_error, Msg),
            init:stop();

        {error, Msg} -> 
            display_output(error, Msg),
            client(Server_Node, Last_Sender);

        {ping} -> {checker, Server_Node} ! self(),
                  client(Server_Node, Last_Sender);
        
% --------- Actions de l'utilisateur--------------
        {leave, []} -> {server, Server_Node} ! {self(), leave};

        {w, [To | Msg]} -> {server, Server_Node} ! {self(), send, To, join_lists(Msg, 32)},
                           wait_answer(),
                           client(Server_Node, Last_Sender);

        {all, Msg} ->  {server, Server_Node} ! {self(), send_all, join_lists(Msg, 32)},
                       io:fwrite("Envoyé au serveur : send_all, ~w ~n", [Msg]),
                       client(Server_Node, Last_Sender);
        
        {r, Msg} -> {server, Server_Node} ! {self(), send, Last_Sender, join_lists(Msg, 32)},
                         wait_answer(),
                         client(Server_Node, Last_Sender);
        
        {who, []} -> {server, Server_Node} ! {self(), who},
                 wait_answer(),
                 client(Server_Node, Last_Sender);

        {shutdown, []} -> {server, Server_Node} ! {self(), shutdown},
                      wait_answer(),
                      client(Server_Node, Last_Sender);

        {mod, [Target]} -> {server, Server_Node} ! {self(), mod, Target},
                         wait_answer(),
                         client(Server_Node, Last_Sender);

        {self_mod, [Password]} -> {server, Server_Node} ! {self(), self_mod, Password},
                                  wait_answer(),
                                  client(Server_Node, Last_Sender);
        
        {help, []} -> display_output(help, []),
                      client(Server_Node, Last_Sender);

        _ -> display_output(error, bad_function),
             client(Server_Node, Last_Sender)
    end.

% Quand le client est en attente d'une réponse du serveur
wait_answer() ->
    receive
        {Tag, Msg} ->
            display_output(Tag, Msg),
            if 
                (Tag == fatal_error) -> 
                    init:stop();
                true -> true
            end
    after
        200 ->
            display_output(fatal_error, server_not_responding),
            exit(self())
    end.

% Affichage classique d'une reponse
display_output(Tag, Msg) ->
    io:format("tag recu : ~w ~n", [Tag]),
    case Tag of
        file ->
             open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--info", 
                               "--title=Informations ",
                               lists:append("--text=" , lists:droplast(lists:append(Msg)))
                              ]}]);

        info ->
             open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--info", 
                               "--title=Info ",
                               lists:append("--text=" , atom_to_list(Msg))
                              ]}]);
        fatal_error ->
            open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--error", 
                               "--title=Fatal Error ",
                               lists:append("--text=" , atom_to_list(Msg))
                              ]}]);
        msg -> 
            {From, Type, Content} = Msg,
            open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--info", 
                               "--title=Incomming Message ",
                               lists:append([ "--text=" ,"[", atom_to_list(Type), "]",
                                              "[", From, "] ", Content])
                              ]}]);
        error ->
            open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--warning", 
                               "--title=Error ",
                               lists:append("--text=" , atom_to_list(Msg))
                              ]}]);
        
        help ->
            open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--text-info", 
                               "--title=ReadMe",
                               "--filename=Readme.txt"
                              ]}])
    end.

% Fenêtre où l'utilisateur entre ses différentes commandes
main_input() ->
    % Creation de la fenetre
    Port = open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--entry", 
                               "--title=Chat ",
                               "--text=Client Chat"  
                              ]}]),
    receive
        % Lecture de ce qui est entré
        {Port, {data, Data}} ->
            % Pop_till_char sépare les arguments quand ils sont délimités par espaces
            % Donc on supprime le \n final pour le remplacer par un espace (32)
            D = lists:append(lists:droplast(Data), [32]),

            % Debug
            io:format("~w ~n", [D]),

            % On écupère le 1e argument (la fonction) et les suivants (arguments/options)
            {Fun, Args} = parse(D),
            io:format("Envoyé : ~w , ~w ~n", [list_to_atom(Fun), Args]),
            
            case whereis(client) of
                undefined -> init:stop();
                _ ->
                    % On appelle la fonction
                    client ! {list_to_atom(Fun), Args},
                    if 
                        % Dans le cas d'un leave, on le relance pas la lecture
                        (Fun == "leave") -> display_output(info, done);
                        % Sinon, on réarme le système de lecture
                        true -> main_input()
                    end
            end
    end.
        

% Pour se connecter à un serveur
join(Name, Server_Node) ->   
    case whereis(client) of
        undefined ->
            register(client, spawn(client, new_client, [Server_Node, Name])),
            main_input();
        _ -> io:fwrite("Info : Déjà connecté ~n")
    end.

% Fonction initiale
init() ->           
    Port = open_port({spawn_executable, os:find_executable("zenity")},
                     [in, use_stdio, eof, 
                      {args, ["--forms", 
                              "--title=Connection au serveur", 
                              "--separator=,",
                              "--text=Connection au serveur",
                              "--add-entry=Nom d'Utilisateur",
                              "--add-entry=Serveur"]}]),
    receive 
        {Port, {data, Data}} ->
            {Name, R} = pop_till_char(Data, 44),
            {Server, _} = pop_till_char(R, 10),
            join(Name, list_to_atom(lists:append("server@",Server)) );
        _ -> io:format("~n")    
    end.
   


% ---------- UTILITAIRE ----------

% Prend une liste de listes en entrée, renvoit la liste où toutes les listes 
% ont été concaténées entre elles en ajoutant un symbole de liaison entre chaque
% C'est l'inverse de pop_args
join_lists([], _) -> [];
join_lists([First|Rest],JoinWith) ->
    lists:flatten( [First] ++ [JoinWith] ++ (join_lists(Rest, JoinWith)) ).


% Parser les entrées

parse(Data) ->
    case Data of
        [] -> {[],[]};
        [47|T]->  % 47 = / -> S'il y a / c'est une fonction, sinon, c'est un message en all
            {F, R} = pop_till_char(T, 32), % Fonction c'est jusqu'à l'espace
            A = pop_args(R, []),
            {F, A};
        _ -> {"all", Data} % Sinon c'est un all
    end.
         
                
                   
% Pop le 1e argument d'une entrée
pop_till_char([], _) -> {[], []};
pop_till_char([H | T], Char) ->
    if
        H == Char -> {[], T};
        true -> {L, R} = pop_till_char(T, Char),
                {[H|L], R}
    end.       

% Idem que pop_till_char mais le fait récursivement sur TOUS les arguments, 
% Et pas seulement sur le 1e comme pop_till_char
pop_args([], L) -> L;
pop_args(Data, L) -> 
    {Arg, R} = pop_till_char(Data, 32),
    pop_args(R, lists:append(L, [Arg])).
