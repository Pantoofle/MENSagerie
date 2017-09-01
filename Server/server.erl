-module(server).
-export([init/0, server/3, pinger/1, checker/2, ping_timer/0]).

init () ->
   Port = open_port({spawn_executable, os:find_executable("zenity")},
                      [{args, ["--entry", 
                               "--title=Configuration",
                               "--text=Choisissez le mot de passe de votre serveur ",
                               "--entry-text=Mot de Passe"
                              ]}]),

    receive
        {Port, {data, Data}} -> Pswrd = lists:droplast(Data),
                                Server_PID = spawn(server, server, [[], Pswrd, false]),
                               % io:format("Password : ~w ~n", [Pswrd]),
                                spawn(server, ping_timer, []),
                                register(server, Server_PID),
                                io:format("Server allumé avec succès ! ~n");
        _ -> io:format("Erreur lors de la configuration ~n")
    end.

shutdown() -> io:format("Extinction du serveur ~n"),
              init:stop().
              
server (Users, Pswrd, Wait_From) ->
    
    receive 
% Envoi de message à un utilisateur
        {From, send, Target_Name, Msg} ->
            server_message(From, Target_Name, Msg, Users),
            server(Users, Pswrd, Wait_From);
        
        {From, send_all, Msg} ->
            server_send_all(From, Msg, Users),
            server(Users, Pswrd, Wait_From);

% Demande de la liste des utilisateurs
        {From_PID, who} -> 
            server_connected(From_PID, Users),
            server(Users, Pswrd, Wait_From);

% Connection d'un nouvel utilisateur
        {From_PID, join, Name} -> 
            U = server_join(From_PID, Name, Users),
            server(U, Pswrd, Wait_From);
                

% Déconnection d'un utilisateur
        {From_PID, leave} ->
            U = server_leave(From_PID, Users),
            server(U, Pswrd, Wait_From);

% Extinction du serveur par un Mod
         {From_PID, shutdown}->
            Success = server_exit(From_PID, Users),
            if 
                Success -> shutdown();
                true -> server(Users, Pswrd, Wait_From)
            end;

% Un mod transforme un user en mod 
        {From_PID, mod, Target_Name} -> 
            U = server_mod(From_PID, Target_Name, Users),
            server(U, Pswrd, Wait_From);

% Un utilisateur se transforme lui même en mod, avec le bon mot de passe
        {From_PID, self_mod, Password} ->
            U = self_mod(From_PID, Password, Pswrd, Users),
            server(U, Pswrd, Wait_From);
        
% ping de mise à jour des users
        {ping} ->
            if 
                Wait_From == false -> PID = spawn(server, pinger, [Users]),
                                      server(Users, Pswrd, PID);
                true -> server(Users, Pswrd, Wait_From)
            end;
            
% Réponse du pinger après la déconnection des utilisateurs déconnectés
        {From, updated_users, U} when From == Wait_From ->
            server(U, Pswrd, false)
    end.
                   


       

% --- Connecter l'utilisateur

server_join(From_PID, Name, Users) ->
    case {pid_connected(Users, From_PID), name_connected(Users, Name)} of
        {false, false} -> From_PID ! {info, joined},
                          lists:append(Users, [{Name, From_PID, false}]);
        {_ , false}    -> From_PID ! {error, already_joined},
                          Users;
        {_, _}         -> From_PID ! {fatal_error, username_taken},
                          Users
    end.


% --- Déconnecte l'utilisateur
server_leave(From_PID, Users) ->
    From_PID ! {info, disconnected},
    lists:keydelete(From_PID, 2, Users).


% ---  Envoit le Msg à la cible, si l'expediteur est loggé et si le destinataire aussi
server_message(From_PID, Target_Name, Msg, Users) ->
    case {pid_connected(Users, From_PID), name_connected(Users, Target_Name)} of
        {false, _} -> From_PID ! {error, not_identified};
        {_, false} -> From_PID ! {error, target_not_connected};
        {{From_Name, _ , _, _}, {_ , Target_PID, _}} -> 
            Target_PID ! {recu, From_Name, perso,  Msg},
            From_PID ! {info, msg_sent}
     end.

% --- Envoit un message à tous les utilisateurs connectés
server_send_all(From_PID, Msg, Users) ->
    case pid_connected(Users, From_PID) of
        false -> From_PID ! {error, not_identified};
        {From_Name, _, _} -> 
            lists:map(
              fun({_, Target_PID, _}) -> Target_PID ! {recu, From_Name, all,  Msg} end , 
              Users )
    end.


% Fonctions de groupe (pas encore au point...)

% new_group(From_PID, Users) ->
%    N = max_group_number(Users, 0),
%    case pid_connected(Users, From_PID) of
%        false -> From_PID ! {error, not_connected},
%                 Users;
%        {Name, _, Mod, _} -> 
%            D = lists:keydelete(From_PID, 2, Users),
%            lists:append(D, [{Name, From_PID, Mod, N+1 }]),
%            From_PID ! {info, group_joined}
%    end.

% max_group_number([], M) -> M;
% max_group_number([H|T], M) ->
%    case H of
%        {_,_,_,Group} ->
%            if
%                M < Group -> max_group_number(T, Group);
%                M >= Group -> max_group_number(T, M)
%            end
%    end.

% group_invite(From_PID, Users, Target_Name) ->
    





% --- Envoit la liste des utilisateurs connectés
server_connected(From_PID, Users) ->
    From_PID ! {file, list_of_users(Users)}.

list_of_users([]) -> [];
list_of_users([{Name, _, _} | T]) -> [lists:append(Name, "-") | list_of_users(T)].

% -- Eteint le serveur
server_exit(From_PID, Users) ->
    case pid_connected(Users, From_PID) of
        {_, _, false} -> From_PID ! {error, not_mod},
                         false;
        {_, _, true} -> server_msg_all(fatal_error, server_closing, Users),
                        true
    end.

server_msg_all(Tag, Reason, Users) ->
    lists:map(fun({_,Target_PID, _}) -> Target_PID ! {Tag, Reason} end , Users).
    

% --- Rendre un utilisateur Mod
server_mod(From_PID, Target_Name, Users)->
    case pid_connected(Users, From_PID) of
        false -> From_PID ! {error, not_connected},
                 Users;
        {_, _, false} -> From_PID ! {error, not_mod},
                            Users;
        {_, _, true} -> 
            case name_connected(Users, Target_Name) of
                false -> From_PID ! {error, target_not_connected},
                         Users;
                {_, Target_PID, _} -> 
                    D = lists:keydelete(Target_PID, 2, Users),
                    lists:append(D, [{Target_Name, Target_PID, true}]),
                    Target_PID ! {info, got_modded},
                    From_PID ! {info, done}
            end
    end.

% --- Se rend soi même mod, avec le bon mot de passe serveur

self_mod(From_PID, Password, Pswrd,  Users) ->
    case pid_connected(Users, From_PID) of
        false -> From_PID ! {error, not_connected},
                 Users;
        {Name, _, false} ->
          %  io:format("Pass essaye : ~w ~n Pass attendu : ~w ~n", [Password, Pswrd]),
            case (Pswrd == Password) of 
                true ->
                    From_PID ! {info, moded},
                    D = lists:keydelete(From_PID, 2, Users),
                    lists:append(D, [{Name, From_PID, true}]);
                false ->
                    From_PID ! {error, wrong_password},
                    Users
            end;
        {_, _, true} -> From_PID ! {info, already_mod},
                        Users
    end.


% Fonctions utiles

pid_connected(Users, PID)->      
    lists:keyfind(PID, 2, Users).

name_connected(Users, Name) ->
    lists:keyfind(Name, 1, Users).  

% -------------------     Fonctions du thread PINGER ----------------------

% Fonction principale qui doit pinger les Users
pinger(Users) ->
    Checker_PID = spawn(server, checker, [Users, self()]),
    register(checker, Checker_PID),
    receive
        NewUsers ->
            server ! {self(), updated_users, NewUsers},
            % On fait spawn le timer qui déclenchera la prochaine session de ping
            spawn(server, ping_timer, [])
    end.

% C'est checker qui renvoi la liste mise à jour vers pinger pour qu'il puisse la transmettre à server
checker(Users, Pinger_PID) ->
    U = checker_aux(Users),
    Pinger_PID ! U.
    
% Teste les utilisateurs par épluchage
% La réponse au ping doit être le PID de l'utilisateur, ainsi on évite qu'un client malveillant
% réponde présent à la place d'un autre utilisateur, car les clients n'ont pas accès au PID des autres.
% A l'inverse, si le mauvais PID est reçu, on ne kick pas directement l'utilisateur qu'on teste
% on le reping, 

checker_aux([]) -> [];
checker_aux([H | T]) ->
    {_, PID, _} = H,
    PID ! {ping},
    receive
        PID -> [ H | checker_aux(T) ];
% Probleme de sécutité : si un malveillant envoit énormément de fausses réponses à un ping
% Personne n'est kick, mais on va perdre du temps à recommencer le ping jusqu'à tomber sur la réponse
% de l'utilisateur. Au pire cas, on recommence à l'infini, ce qui empêche de voir qu'un user 
% s'est mal déconnecté...
        _   -> checker_aux([H | T])
    after
        % Délai de réponse toléré
        300 ->
            checker_aux(T)
    end.
             

ping_timer() ->
    receive
    after
        % On vérifie toutes les 5 sec
        5000 -> 
            case whereis(server) of
                undefined -> io:format("Serveur éteint ~n");
                _ -> server ! {ping}
            end
    end.
            
