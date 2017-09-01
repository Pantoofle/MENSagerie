###################################################################
##########                                               ##########
##########  READ  READM  EAD  READ        RE   ER READM  ##########
##########  E   M E     R   M E   M       E A M E E      ##########
##########  ADME  ADME  EADME A   E       A  D  A ADME   ##########
##########  D   R D     A   R D   R       D     D D      ##########
##########  M   E M     D   E M   E       M     M M      ##########
##########  E   A EREAD M   A EMDA        E     E EREAD  ##########
##########                                               ##########
###################################################################

-------------------------------------------------------------------
---------------------------  La mENSagerie ------------------------
-------------------------------------------------------------------

Copyrights :
Ce logiciel est libre et open-source,vous pouvez utiliser ce code,
le modifier, le publier, le distriuer, du moment que vous citez
l'auteur.

Programmeur : Simon Fernandez - ENS de Lyon

Version : 1.1

Fichiers :
   * Serveur
      -server.erl
      -Makefile
      -Readme.txt

   * Client
      -client.erl
      -Makefile
      -Readme.txt


Commandes CLIENT :
   * Lancer le client :
      - Se placer dans le repertoir contenant Makefile
      - Dans un terminal, entrer
            $ make

   * Contrôler le client
      - Fenêtre de connection
         ~ Choisir un nom d'utilisateur libre
         ~ Entrer l'adresse du serveur, de la forme
              127.0.0.1

      - Commandes pour tous
         ~ /m <User> <Message> : Envoit <Message> à <User> s'il est connecté
         ~ /all <Message> : Envoit <Message> à tous les utilisateurs connectés
         ~ /r <Message> : Envoit <Message> à la dernière personne qui vous a écrit
         ~ /leave : Se déconnecte du serveur
         ~ /who : Renvoit la liste des utilisateurs connectés
         ~ /self_mod <MdP> : Se donne les autorisations de Modérateur si
                      le mot de passe renseigné est bien celui du serveur
         ~ Du texte sans aucune commande est considérée comme un /all  

      - Commandes modérateur
         ~ mod <User> : Donne les autorisations de modérateur à <User>
         ~ shutdown : Eteint le serveur à distance, déconnecte tous les
                      utilisateurs

Commandes SERVEUR :
   * Lancer le serveur :
      - Se placer dans le repertoir contenant Makefile
      - Dans un terminal, entrer
            $ make
      - Dans la fenetre qui s'ouvre, choisir le nom du serveur, et le mot de
        passe permettant de s'identifier Modérateur
      - Le serveur est alors lancé !
      - Dans le terminal, l'IP du serveur à communiquer aux clients s'affiche

   * Eteindre le serveur :
      - Se connecter en modérateur avec un client et utiliser la commande shutdown 

Ajouts futurs prévus :
   - Reserver un nom d'utilisateur avec un mot de passe
   - Communications persistantes
   - Discussion de groupe (création de rooms)
