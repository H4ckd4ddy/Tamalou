#/bin/bash

table_id=0

function init {
	mkdir -p ./tables
}

function list_tables {
	echo "Existing tables :"
	ls ./tables/
	printf "\n\n\n"
}

function create_table {
	table_id=$(( $RANDOM % 100 + 1 ))
	mkdir ./tables/$table_id
	cp full_cards.txt tables/$table_id/full_cards.txt
	cards_count='X'
	while !((cards_count > 1)); do
		read -p "How many cards in this room ? : " cards_count
	done
	echo -n $cards_count > tables/$table_id/cards_count.txt
	echo -n '0' > tables/$table_id/players_count.txt
	echo -n '0' > tables/$table_id/player_playing.txt
}

function join_table {
	table_id=$1
	./play.sh $table_id
}

init

while true; do
	list_tables
	read -p "Type game ID or + to create new : " response
	if [ "$response" = "+" ]; then
		create_table
		join_table $table_id
	else
		if [ -d "./tables/$response" ]; then
			join_table $response
		fi
	fi
done