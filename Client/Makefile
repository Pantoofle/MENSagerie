LOCALIP = $(shell wget http://ipinfo.io/ip -qO -)

all : client.beam
	erl -name client@$(LOCALIP) -s client init -s init stop -noshell

client.beam : client.erl
	erlc client.erl

clean :
	rm -f *.beam 

