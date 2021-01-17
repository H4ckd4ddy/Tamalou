#/bin/bash

# Get arg table ID
table_id=$1
table_path="./tables/$table_id/"

# Init global vars
players_count=0
cards_count=0
player_playing=0
card_in_hand=''
card_dropped=''
stop=0

# Init personal vars
player_id=0
visible_card_id=0

# Utils
function lock {
	touch $table_path/table.lock
}
function unlock {
	rm -f $table_path/table.lock
}
function wait_unlock {
	while [ -f "$table_path/table.lock" ]; do
		sleep 0.5
	done
}
function get_stop {
	if [ -f "$table_path/stop.txt" ]; then
		stop=$(cat $table_path/stop.txt)
	fi
}


# Cards
function get_cards_count {
	cards_count=$(cat $table_path/cards_count.txt)
}
function generate_cards_stack {
	sort --random-sort $table_path/full_cards.txt > $table_path/cards.txt
}
function take_card {
	card_in_hand=$(head -n 1 $table_path/cards.txt)
	sed -i '1d' $table_path/cards.txt
}
function take_card_dropped {
	card_in_hand=$card_dropped
	card_dropped=''
}
function distribute {
	rm -f player_*
	for player in $(seq 1 $players_count);do
		for card in $(seq 1 $cards_count);do
		take_card
		echo $card_in_hand >> $table_path/player_$player.txt
		card_in_hand=''
		done
	done
}
function get_card_dropped {
	card_dropped=$(cat $table_path/card_dropped.txt)
}
function drop_card {
	card_dropped=$card_in_hand
	card_in_hand=''
	echo -n "$card_dropped" > $table_path/card_dropped.txt
	if [ "$card_dropped" == "D#" ] || [ "$card_dropped" == "DC" ]; then
		card_look 1
	fi
}
function switch_card {
	card_id_to_switch=$1
	visible_card_id=$card_id_to_switch
	card_dropped=$(head -n $card_id_to_switch $table_path/player_$player_id.txt | tail -1)
	echo -n "$card_dropped" > $table_path/card_dropped.txt
	sed -i "s/$card_dropped/$card_in_hand/" "$table_path/player_$player_id.txt"
	card_in_hand=''
	display_game
	sleep 1
	visible_card_id=0
}
function card_look {
	clear
	display_player_cards $player_id
	look_count=$1
	for look in $(seq 1 $look_count);do
		visible_card_id='X'
		while !((visible_card_id > 0 && visible_card_id <= cards_count)); do
			read -p "Which cards would like to see ? : " visible_card_id
		done
		clear
		display_player_cards $player_id
	done
	response='X'
	while [ "$response" != " " ]; do
		IFS= read -n 1 -p "Press [space] to continue" response
	done
	visible_card_id=''
}
function drop_hidden_card {
	clear
	display_player_cards $player_id
	card_id_to_drop='X'
	while !((card_id_to_drop > 0 && card_id_to_drop <= cards_count)); do
		read -p "Which cards would like to drop ? : " card_id_to_drop
	done
	card_to_drop=$(head -n $card_id_to_drop $table_path/player_$player_id.txt | tail -1)
	actual_card_number=$(echo -n $card_dropped | sed 's/.$//')
	card_number_to_drop=$(echo -n $card_to_drop | sed 's/.$//')
	if [ "$actual_card_number" == "$card_number_to_drop" ]; then
		card_in_hand=$card_to_drop
		drop_card
		sed -i -e "${card_id_to_drop}d" $table_path/player_$player_id.txt
		cards_count=$((cards_count-1))
	else
		take_card
		echo "$card_in_hand" >> $table_path/player_$player_id.txt
		card_in_hand=''
		cards_count=$((cards_count+1))
	fi
}

# Players
function get_players_count {
	players_count=$(cat $table_path/players_count.txt)
}
function update_players_count {
	echo -n "$players_count" > $table_path/players_count.txt
}
function get_player_playing {
	player_playing=$(cat $table_path/player_playing.txt)
}
function next_player {
	player_playing=$((player_playing+1))
	if (($player_playing > $players_count)); then
		player_playing=1
	fi
	echo -n "$player_playing" > $table_path/player_playing.txt
}

# Display
function display_player_cards {
	player=$1
	printf "\n\n"
	indicator=''
	if (( player == player_id )); then
		indicator="(You) "
	fi
	if (( player == stop )); then
		indicator="$indicator[stop] "
	fi
	echo "Player $player $indicator: "
	printf "\n"
	for line in $(seq 1 6);do
		card_id=1
		while read card; do
			card_name='  '
			if (( card_id == visible_card_id && player == player_id )); then
				card_name=$card
			fi
			case $line in
				1) echo -n "######   ";;
				2) echo -n "#    #   ";;
				3) echo -n "# $card_name #   ";;
				4) echo -n "#    #   ";;
				5) echo -n "######   ";;
				6) echo -n "  $card_id      ";;
			esac
			card_id=$((card_id+1))
		done <$table_path/player_$player.txt
		printf "\n"
	done
	printf "\n\n"
}
function display_special_cards {
	printf "\n\n"
	for line in $(seq 1 6);do
		for card in $(seq 1 2);do
			card_name="  " 
			card_value="  " 
			case $card in
				1) card_name="Dropped";card_value=$card_dropped;;
				2) card_name="Hand   ";card_value=$card_in_hand;;
			esac
			while ((${#card_value} < 2)); do
				card_value="$card_value "
			done
			case $line in
				1) echo -n "######       ";;
				2) echo -n "#    #       ";;
				3) echo -n "# $card_value #       ";;
				4) echo -n "#    #       ";;
				5) echo -n "######       ";;
				6) echo -n "$card_name      ";;
			esac
		done
		printf "\n"
	done
	printf "\n\n"
}
function display_game {
	get_stop
	get_card_dropped
	clear
	echo "------------ Table $table_id ------------"
	printf '\n\n\n'
	if ((stop == player_playing)); then
		for player in $(seq 1 $players_count);do
			player_score=0
			while read card; do
				card_number=$(echo -n $card | sed 's/.$//')
				if [ "$card_number" == "V" ] || [ "$card_number" == "D" ]; then
					card_number=10
				fi
				if [ "$card" == "R#" ] || [ "$card" == "RC" ]; then
					card_number=0
				fi
				if [ "$card" == "RP" ] || [ "$card" == "RT" ]; then
					card_number=15
				fi
				player_score=$((player_score+card_number))
			done <$table_path/player_$player.txt
			echo "Player $player : $player_score"
		done
		printf "\n\n\n\n\n\n"
	else
		display_special_cards
		for player in $(seq 1 $players_count);do
			display_player_cards $player
		done
	fi
}

# Game
function start_game {
	generate_cards_stack
	distribute
	touch $table_path/card_dropped.txt
	player_playing=$(( $RANDOM % $players_count + 1 ))
	next_player
	touch $table_path/started.lock
}
function wait_game_start {
	while [ ! -f "$table_path/started.lock" ]; do
		get_players_count
		clear
		echo "Actually $players_count at this table"
		IFS= read -n 1 -t 1 -p "Press [space] to start" response
		if [ "$response" = " " ]; then
			start_game
		fi
	done
	get_player_playing
}
function say_stop {
	echo -n $player_id > $table_path/stop.txt
	next_player
}
function chose_card {
	display_game
	printf "\n\n"
	echo "1 - Take a new card"
	echo "2 - Take dropped card"
	printf "\n"
	choice='X'
	while !((choice > 0 && choice <= 2)); do
		read -n 1 -p "What would you like to do ? : " choice
	done
	case $choice in
		1) take_card;;
		2) take_card_dropped;;
	esac
}
function chose_action {
	display_game
	printf "\n\n"
	choice=99
	while !((choice >= 0 && choice <= cards_count)); do
		read -n 1 -p "Type card to switch or 0 to drop the card : " choice
	done
	if ((choice == 0)); then
		drop_card
	else
		switch_card $choice
	fi
}
function chose_end_action {
	display_game
	printf "\n\n"
	echo "1 - Try to drop hidden card"
	echo "2 - Say STOP"
	echo "3 - End turn"
	printf "\n"
	choice='X'
	while !((choice > 0 && choice <= 3)); do
		read -n 1 -p "What would you like to do ? : " choice
	done
	case $choice in
		1) drop_hidden_card;;
		2) say_stop;;
		3) next_player;;
	esac
}
function wait_my_turn {
	while ((player_playing != player_id)); do
		get_player_playing
		display_game
		sleep 1
	done
}



function init_game {
	get_cards_count
	get_players_count
	players_count=$((players_count+1))
	player_id=$players_count
	echo $players_count
	update_players_count
}

wait_unlock
lock
init_game
unlock

wait_game_start

card_look 2

while ((stop != player_playing)); do
	wait_my_turn
	chose_card
	chose_action
	while (($player_playing == $player_id)); do
		chose_end_action
	done
	get_stop
done
display_game
