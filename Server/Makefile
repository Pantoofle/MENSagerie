LOCALIP = $(shell wget http://ipinfo.io/ip -qO -)

all : server.beam
	erl -name server@$(LOCALIP) -s server init -noshell

server.beam : server.erl
	erlc server.erl

clean :
	rm -f *.beam 


