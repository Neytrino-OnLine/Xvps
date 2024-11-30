#!/bin/sh

VERSION="beta 1"
INBOUNDS='/opt/etc/xray/configs/03_inbounds.json'
OUTBOUNDS='/opt/etc/xray/configs/04_outbounds.json'
ROUTING='/opt/etc/xray/configs/05_routing.json'
OBSERVATORY='/opt/etc/xray/configs/07_observatory.json'
BUTTON='/opt/etc/ndm/button.d/xvps.sh'
BACKUP='/opt/backup-xvps'

function fileSave
	{
	local FILE_PATH="$1"
	local CONTENT="$2"
	if [ -f "$FILE_PATH" ];then
		local FILE=`basename "$FILE_PATH"`
		echo ""
		echo -e "\tВ: `dirname $FILE_PATH` уже существует файл: $FILE,"
		local DT=`date +"%C%y.%m.%d_%H-%M-%S"`
		local BACKUP_PATH="$BACKUP/$DT/"
		mkdir -p "$BACKUP_PATH"
		mv "$FILE_PATH" "$BACKUP_PATH$FILE"
		if [ -f "$BACKUP_PATH$FILE" ];then
			echo -e "\tон перемещён в каталог: $BACKUP_PATH"
		else
			echo ""
			echo -e "\tОшибка: не удалось создать резервную копию файла..."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
			exit
		fi
	fi
	if [ -n "$CONTENT" ];then
		echo -e "$CONTENT" > $FILE_PATH
		echo ""
		echo -e "\tФайл: $FILE_PATH - сохранён."
	fi
	}

function filterGet
	{
	RESULT=""
	local OUT=""
	local STRING=""
	local NAME=""
	local NEW=""
	local FLAG="1"
	local NUM="1"
	IFS=$'\n\t'
	for LINE in $(cat $ROUTING);do
		if [ "`echo "$LINE" | grep -c '// '`" -gt "0" -a ! "$FLAG" = "3" ];then
			if [ "$NUM" -lt "10" ];then
				local SPACE=' '
			else
				local SPACE=""
			fi
			local NAME=$SPACE$NUM'\t'`echo "$LINE" | awk '{sub(/\/\/ /,"")}1'`'\t'
			local STRING=""
			local FLAG='2'
		elif [ "`echo "$LINE" | grep -c '"domain": \[\|"ip": \['`" -gt "0" -a "$FLAG" = "2" ];then
			local STRING=$NEW$NAME$STRING'\t'$LINE'\t'
			local FLAG='3'
			local NEW='\n'
		elif [ "`echo "$LINE" | grep -c '{'`" = "0" -a "$FLAG" = "2" ];then
			local STRING=$STRING$LINE
		elif [ "`echo "$LINE" | grep -c '],'`" -gt "0" -a "$FLAG" = "3" ];then
			local OUT=$OUT$STRING
			local STRING=""
			local NUM=`expr $NUM + 1`
			local FLAG='1'
		elif [ "$FLAG" = "3" ];then
			local STRING=$STRING`echo "$LINE" | awk '{gsub(/"/,"")}1'`
		fi
	done
	local OUT=`echo -e "$OUT"`
	local STRING=""
	local NEW=""
	IFS=$'\n'
	for LINE in $OUT;do
		local STRING=$STRING$NEW`echo $LINE | awk -F"\t" '{print $1": "$2}'`
		local NEW='\n'
	done
	if [ -n "$STRING" ];then
		local LIST=`echo -e "$STRING\n 0:\tОтмена" | awk -F"\t" '{print "\t"$1, $2}'`
		local STRING=""
		echo "Следующие правила - содержат фильтры:"
		echo ""
		echo "$LIST"
		echo ""
		read -r -p "Введите номер правила:"
		if [ -z "`echo "$REPLY" | sed 's/[0-9]//g'`" -a ! "$REPLY" = "0" -a ! "$REPLY" = "" ];then
			if [ "$REPLY" -lt "10" ];then
				REPLY=" $REPLY"
			fi
			IFS=$'\n'
			for LINE in $OUT;do
				if [ "`echo "$LINE" | awk -F"\t" '{print $1}'`" = "$REPLY" ];then
					local STRING=$LINE
					break
				fi
			done
			if [ -n "$STRING" ];then
				RESULT=$STRING
			else
				echo ""
				echo -e "\tОшибка: введено некорректное значение."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
				filterEditor
				exit
			fi
		else
			filtersMenu
			exit
		fi
	else
		echo ""
		echo -e "\tВ конфигурации нет правил - содержащих фильтры."
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		filtersMenu
		exit
	fi
	}

function noFilterGet
	{
	RESULT=""
	local OUT=""
	local STRING=""
	local NAME=""
	local NEW=""
	local FLAG="1"
	local NUM="1"
	IFS=$'\n\t'
	for LINE in $(cat $ROUTING);do
		if [ "`echo "$LINE" | grep -c '// '`" -gt "0" -a ! "$FLAG" = "3" ];then
			if [ "$NUM" -lt "10" ];then
				local SPACE=' '
			else
				local SPACE=""
			fi
			local STRING=$SPACE$NUM'\t'`echo "$LINE" | awk '{sub(/\/\/ /,"")}1'`'\t'
			local FLAG='2'
		elif [ "`echo "$LINE" | grep -c '"domain": \[\|"ip": \['`" -gt "0" -a "$FLAG" = "2" ];then
			local FLAG='1'
		elif [ "`echo "$LINE" | grep -c '"type": "field"'`" -gt "0" -a "$FLAG" = "2" ];then 
			local OUT=$OUT$NEW$STRING
			local NEW='\n'
			local STRING=""
			local NUM=`expr $NUM + 1`
			local FLAG='1'
		elif [ "`echo "$LINE" | grep -c '{'`" = "0" -a "$FLAG" = "2" ];then
			local STRING=$STRING$LINE
		fi
	done
	local OUT=`echo -e "$OUT"`
	local STRING=""
	local NEW=""
	IFS=$'\n'
	for LINE in $OUT;do
		local STRING=$STRING$NEW`echo $LINE | awk -F"\t" '{print $1": "$2}'`
		local NEW='\n'
	done
	if [ -n "$STRING" ];then
		local LIST=`echo -e "$STRING\n 0:\tОтмена" | awk -F"\t" '{print "\t"$1, $2}'`
		local STRING=""
		echo "Следующие правила - не содержат фильтров:"
		echo ""
		echo "$LIST"
		echo ""
		read -r -p "Введите номер правила:"
		if [ -z "`echo "$REPLY" | sed 's/[0-9]//g'`" -a ! "$REPLY" = "0" -a ! "$REPLY" = "" ];then
			if [ "$REPLY" -lt "10" ];then
				REPLY=" $REPLY"
			fi
			IFS=$'\n'
			for LINE in $OUT;do
				if [ "`echo "$LINE" | awk -F"\t" '{print $1}'`" = "$REPLY" ];then
					local STRING=$LINE
					break
				fi
			done
			if [ -n "$STRING" ];then
				echo ""
				echo "Укажите тип фильтра:"
				echo ""
				echo -e "\t1: По доменному имени (по умолчанию)"
				echo -e "\t2: По IP-адресу"
				echo ""
				read -r -p "Ваш выбор:"
				if [ "$REPLY" = "2" ];then
					RESULT=$STRING'	"ip": ['
				else
					RESULT=$STRING'	"domain": ['
				fi
				echo ""
			else
				echo ""
				echo -e "\tОшибка: введено некорректное значение."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
				filterNew
				exit
			fi
		else
			filtersMenu
			exit
		fi
	else
		echo -e "\tВ конфигурации нет правил - не содержащих фильтры."
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		filtersMenu
		exit
	fi
	}

function filterAdd
	{
	local NEW=""
	echo ""
	read -r -p "Добавить в фильтр:"
	REPLY=`echo "$REPLY" | awk '{gsub(/"/,"%22")}1' | awk '{gsub(/,/,"%2C")}1'`
	if [ -n "$FILTER_LIST" ];then
		local NEW=','
	fi
	if [ -n "$REPLY" ];then
		FILTER_LIST=$FILTER_LIST$NEW$REPLY
		local NEW=','
		filterAdd "$1"
	else
		if [ "$1" = "a" ];then
			filterAction
			exit
		fi
	fi
	}

function filterDelete
	{
	read -r -p "Удалить из фильтра:" DEL_FIELD
	echo ""
	if [ -n "$DEL_FIELD" ];then
		local LIST=`echo $FILTER_LIST | awk '{gsub(/,/,"\n")}1'`
		local LIST=`echo -e "$LIST"`
		if [ -n "`echo "$LIST" | grep "$DEL_FIELD"`" ];then
			echo "Обнаружены следующие совпадения:"
			echo ""
			echo "$LIST" | grep "$DEL_FIELD" | awk -F"\t" '{print "\t- "$1}'
			echo ""
			echo "Удалить все совпадения?"
			echo ""
			echo -e "\t1: Да"
			echo -e "\t0: Нет (по умолчанию)"
			echo ""
			read -r -p "Ваш выбор:"
			if [ "$REPLY" = "1" ];then
				local LIST=`echo "$LIST" | grep -v "$DEL_FIELD"`
				FILTER_LIST=""
				local NEW=""
				IFS=$'\n'
				for LINE in $LIST;do
					FILTER_LIST=$FILTER_LIST$NEW$LINE
					local NEW=','
				done
				filterAction
				exit
			else
				filterDelete
				exit
			fi
		else
		echo -e "\tОшибка: ничего не найдено"
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		echo ""
		filterDelete
		exit
		fi
	else
		filterAction
		exit
	fi
	}

function filterNew
	{
	clear
	echo "================================= Новый фильтр ================================="
	echo "$MODE"
	noFilterGet
	FILTER_LIST=""
	filterAction
	exit
	}

function filterEditor
	{
	clear
	echo "=============================== Редактор фильтров =============================="
	echo "$MODE"
	filterGet
	FILTER_LIST=`echo $RESULT | awk -F"\t" '{print $5}'`
	filterAction
	exit
	}

function filterSave
	{
	local NEW_FILTERS="\n\t\t\t{\n"
	local NEW=""
	local RULE=`echo $RESULT | awk -F"\t" '{print $3}'`
#echo -e "R=$RULE"
	IFS=$','
	for LINE in $RULE;do
		local NEW_FILTERS=$NEW_FILTERS$NEW'\t\t\t'$LINE
		local NEW=',\n'
	done
	local NEW_FILTERS=$NEW_FILTERS','
	if [ -n "$FILTER_LIST" ];then
		local NEW_FILTERS=$NEW_FILTERS'\n\t\t\t'`echo $RESULT | awk -F"\t" '{print $4}'`'\n'
		local NEW=""
		IFS=$','
		for LINE in $FILTER_LIST;do
			local NEW_FILTERS=$NEW_FILTERS$NEW'\t\t\t\t"'$LINE'"'
			local NEW=',\n'
		done
		local NEW_FILTERS=$NEW_FILTERS'\n\t\t\t\t],'
	fi
	local NEW=""
	local STRING=""
	local BEGINING=""
	local ENDING=""
	local NAME=`echo "$RESULT" | awk -F"\t" '{print $2}'`
	local FLAG="1"
	IFS=$'\n'
	for LINE in $(cat $ROUTING);do
		if [ "`echo "$LINE" | grep -c "$NAME"`" -gt "0" -a "$FLAG" = "1" ];then
			if [ "`echo $LINE | awk '{gsub(/\t/,"")}1' | awk '{sub(/\/\/ /,"")}1'`" = "$NAME" ];then
				local FLAG='2'
			fi
			local BEGINING=$BEGINING$DOUBLE$NEW$LINE
			local DOUBLE='\n'
		elif [ "`echo "$LINE" | grep -c "// "`" -gt "0" -a "$FLAG" = "1" ];then
			local BEGINING=$BEGINING$DOUBLE$NEW$LINE
			local DOUBLE='\n'
		elif [ "`echo "$LINE" | grep -c "$NAME"`" = "0" -a "$FLAG" = "1" ];then
			local BEGINING=$BEGINING$NEW$LINE
		elif [ "`echo "$LINE" | grep -c '"type": "field"'`" -gt "0" -a "$FLAG" = "2" ];then
			local ENDING=$ENDING$NEW$LINE
			local FLAG="3"
		elif [ "`echo "$LINE" | grep -c '// '`" -gt "0" -a "$FLAG" = "3" ];then
			local ENDING=$ENDING$DOUBLE$NEW$LINE
			local DOUBLE='\n'
		elif [ "$FLAG" = "3" ];then
			local ENDING=$ENDING$NEW$LINE
		fi
		local NEW='\n'
	done
	RESULT=$BEGINING$NEW_FILTERS$ENDING
	echo "Хотите просмотреть результат?"
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		clear
		echo "==================================== ROUTING ==================================="
		echo -e "$RESULT"
		echo "================================================================================"
	fi
	echo ""
	echo "Сохранить результат?"
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет, вернуться к редактированию (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		fileSave "$ROUTING" "$RESULT"
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		filtersMenu
		exit
	else
		filterAction
		exit
	fi
	}

function filterAction
	{
	clear
	if [ -n "$RESULT" ];then
		echo "==================================== Фильтр ===================================="
		local LIST=`echo $FILTER_LIST | awk '{gsub(/,/,"\n\t")}1'`
		if [ -n "$LIST" ];then
			echo -e "\t$LIST"
		else
			echo -e "\t- cписок пуст"
		fi
		echo "================================================================================"
		echo ""
		echo "Доступные действия:"
		echo ""
		echo -e "\t1: Сохранить"
		echo -e "\t2: Добавить элементы"
		echo -e "\t3: Удалить элементы"
		echo -e "\t4: Очистить список"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		if [ "$REPLY" = "1" ];then
			echo ""
			filterSave
			exit
		elif [ "$REPLY" = "2" ];then
			echo ""
			echo -e "\tВы можете добавлять строку за строкой... Для завершения процесса"
			echo "добавления - нажмите ввод (оставив строку пустой)."
			filterAdd 'a'
			exit
		elif [ "$REPLY" = "3" ];then
			echo ""
			echo -e "\tВведите последовательность символов,  содержащеюся в строках - которые"
			echo "нужно удалить. Или нажмите ввод, для выхода из диалога удаления..."
			echo ""
			filterDelete
			exit
		elif [ "$REPLY" = "4" ];then
			FILTER_LIST=""
			echo ""
			filterAction
			exit
		else
			filtersMenu
			exit
		fi
	fi
	}

function listsGet
	{
	if [ "$1" = "2" ];then
		local LIST=`echo -e $INBOUNDS_TEMP | grep '//\|"tag"\|"listen"\|"port"'`
	else
		local LIST=`cat $INBOUNDS | grep '//\|"tag"\|"listen"\|"port"'`
	fi
	local STRING=""
	local OUT=""
	local NUM="1"
	IFS=$'\n\t'
	for LINE in $LIST;do
		if [ "`echo "$LINE" | grep -c '//'`" -gt "0" ];then
			if [ -n "$STRING" ];then
				local OUT="$OUT$STRING\n"
			fi
			local STRING=`echo "$LINE" | awk '{sub(/\/\/ /,"")}1'`
		elif [ "`echo "$LINE" | grep -c '"tag"'`" -gt "0" ];then
			if [ "`echo "$LINE" | grep -c '"policy",'`" -gt "0" ];then
				local STRING="pl\t$STRING\tpolicy"
			elif [ "`echo "$LINE" | grep -c '"proxy'`" -gt "0" ];then
				if [ "$NUM" -lt "10" ];then
					local SPACE=' '
				else
					local SPACE=""
				fi
				local STRING="$SPACE$NUM\t$STRING\t`echo "$LINE" | awk '{sub(/"tag": "/,"")}1' | awk '{sub(/",/,"")}1'`"
				local NUM=`expr $NUM + 1`
			fi
		elif [ "`echo "$LINE" | grep -c '"listen"'`" -gt "0" ];then
			local STRING="$STRING\t`echo "$LINE" | awk '{sub(/"listen": "/,"")}1' | awk '{sub(/",/,"")}1'`"
		elif [ "`echo "$LINE" | grep -c '"port"'`" -gt "0" ];then
			if [ "`echo "$LINE" | grep -c '"port": 61219'`" = "0" ];then
				local STRING="$STRING\t`echo "$LINE" | awk '{sub(/"port": /,"")}1' | awk '{sub(/,/,"")}1'`"
			fi
		fi
	done
	IN_LIST="$OUT$STRING"
	if [ "$1" = "2" ];then
		local LIST=`echo -e $OUTBOUNDS_TEMP | grep '//\|"tag"\|"address"'`
	else
		local LIST=`cat $OUTBOUNDS | grep '//\|"tag"\|"address"'`
	fi
	local STRING=""
	local OUT=""
	local NUM="1"
	IFS=$'\n\t'
	for LINE in $LIST;do
		if [ "`echo "$LINE" | grep -c '//'`" -gt "0" ];then
			if [ -n "$STRING" ];then
				local OUT="$OUT$STRING\n"
			fi
			local STRING=`echo "$LINE" | awk '{sub(/\/\/ /,"")}1'`
		elif [ "`echo "$LINE" | grep -c '"tag"'`" -gt "0" ];then
			if [ "`echo "$LINE" | grep -c '"provider"'`" -gt "0" ];then
				local STRING="pr\t$STRING\tprovider"
			elif [ "`echo "$LINE" | grep -c '"block"'`" -gt "0" ];then
				local STRING="bl\t$STRING\tblock"
			elif [ "`echo "$LINE" | grep -c '"vps'`" -gt "0" ];then
				if [ "$NUM" -lt "10" ];then
					local SPACE=' '
				else
					local SPACE=""
				fi
				local STRING="$SPACE$NUM\t$STRING\t`echo "$LINE" | awk '{sub(/"tag": "/,"")}1' | awk '{sub(/",/,"")}1'`"
				local NUM=`expr $NUM + 1`
			fi
		elif [ "`echo "$LINE" | grep -c '"address"'`" -gt "0" ];then
			local STRING="$STRING\t`echo "$LINE" | awk '{sub(/"address": "/,"")}1' | awk '{sub(/",/,"")}1'`"
		fi
	done
	OUT_LIST="$OUT$STRING"
	}

function inSelect
	{
	RESULT=""
	local NEW=""
	local TAG=""
	echo -e "$IN_LIST" | awk -F"\t" '{print "\t"$1": "$2"     "$4":"$5}'
	local LIST=`echo -e $IN_LIST`
	echo ""
	read -r -p "Введите один (или несколько, через пробел) идентификатор(ов) подключения:"
	local READ=`echo $REPLY | awk '{sub(/ /,"\n")}1'`
	IFS=$'\n'
	for LIST_ID in $LIST;do
		for READ_ID in $READ;do
			if [ -z "`echo "$READ_ID" | sed 's/[0-9]//g'`" ];then
				if [ "$READ_ID" -lt "10" ];then
					READ_ID=" $READ_ID"
				fi
			fi
			if [ "`echo $LIST_ID | awk -F"\t" '{print $1}'`" = "$READ_ID" ];then
				local TAG=$TAG$NEW'"'`echo $LIST_ID | awk -F"\t" '{print $3}'`'"'
				local NEW=', '
			fi
		done
	done
	if [ -z "$TAG" ];then
		echo ""
		echo -e "\tОшибка: введено некорректное значение."
		echo ""
		echo "Попробуйте ещё раз:"
		echo ""
		inSelect
	else
		RESULT="$TAG"
	fi
	}

function balancerSelect
	{
	RESULT=""
	local NEW=""
	local COUNT="0"
	local TAG=""
	echo -e "$OUT_LIST" | grep -v "provider\|block" | awk -F"\t" '{print "\t"$1": "$2"     "$4}'
	echo ""
	local LIST=`echo -e $OUT_LIST | grep -v "provider\|block"`
	read -r -p "Введите два (или больше, через пробел) идентификатора(ов) подключений:"
	local READ=`echo $REPLY | awk '{sub(/ /,"\n")}1'`
	IFS=$'\n'
	for LIST_ID in $LIST;do
		for READ_ID in $READ;do
			if [ "$READ_ID" -lt "10" ];then
				READ_ID=" $READ_ID"
			fi
			if [ "`echo $LIST_ID | awk -F"\t" '{print $1}'`" = "$READ_ID" ];then
				local TAG=$TAG$NEW'"'`echo $LIST_ID | awk -F"\t" '{print $3}'`'"'
				local NEW=', '
				local COUNT=`expr $COUNT + 1`
			fi
		done
	done
	if [ "$COUNT" -lt "2" ];then
		echo ""
		echo -e "\tОшибка: введено некорректное значение или выбрано слишком мало"
		echo "подключений."
		echo ""
		echo "Попробуйте ещё раз:"
		echo ""
		balancerSelect
	else
		RESULT=$TAG
	fi
	}

function outSelect
	{
	RESULT=""
	local TAG=""
	echo -e "$OUT_LIST" | awk -F"\t" '{print "\t"$1": "$2"     "$4}'
	echo ""
	local LIST=`echo -e $OUT_LIST`
	read -r -p "Введите идентификатор подключения:"
	local READ=`echo $REPLY | awk '{sub(/ /,"\n")}1'`
	IFS=$'\n'
	for LIST_ID in $LIST;do
		for READ_ID in $READ;do
			if [ -z "`echo "$READ_ID" | sed 's/[0-9]//g'`" ];then
				if [ "$READ_ID" -lt "10" ];then
					READ_ID=" $READ_ID"
				fi
			fi
			if [ "`echo $LIST_ID | awk -F"\t" '{print $1}'`" = "$READ_ID" ];then
				local TAG=$TAG'"'`echo $LIST_ID | awk -F"\t" '{print $3}'`'"'
				break
			fi
		done
		if [ -n "$TAG" ];then
			break
		fi
	done
	if [ -z "$TAG" ];then
		echo ""
		echo -e "\tОшибка: введено некорректное значение."
		echo ""
		echo "Попробуйте ещё раз:"
		echo ""
		outSelect
	else
		RESULT="$TAG"
	fi
	}

function balancers
	{
	PART_BALANCERS=""
	OBSERVATORY_TEMP=""
	local BAL_LIST=""
	clear
	echo "================================= Распределение ================================"
	echo "$MODE"
	echo "Хотите ли вы использовать случайное распределение (для исходящих подключений)?"
	echo ""
	echo -e "\tЭто позволит распределять трафик между выбранными подключениями,"
	echo "с заданным соотношением..."
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		echo ""
		echo "Нужно выбрать два (или больше) подключения(ий) из списка ниже."
		echo ""
		balancerSelect
		local SELECTOR=$RESULT
		local LIST=`echo -e "$OUT_LIST" | grep -v "prpvider\|block"`
		local READ=`echo $SELECTOR | awk '{gsub(/"/,"")}1' | awk '{sub(/, /,"\n")}1'`
		local WEIGHTS=""
		IFS=$'\n'
		for LIST_ID in $LIST;do
			for READ_ID in $READ;do
				if [ "`echo $LIST_ID | awk -F"\t" '{print $3}'`" = "$READ_ID" ];then
					echo ""
					echo $LIST_ID | awk -F"\t" '{print "Введите вес (в распределении) для подключения: "$2}'
					echo ""
					read -r -p "Вес:" WEIGHT
					if [ -n "$WEIGHTS" ];then
						local WEIGHTS=$WEIGHTS', '
					fi	
					if [ -z "`echo "$WEIGHT" | sed 's/[0-9]//g'`" -a ! "$WEIGHT" = "0" -a ! "$WEIGHT" = "" ];then
						local WEIGHTS="$WEIGHTS$WEIGHT"
					else
						local WEIGHTS=$WEIGHTS'1'
						echo ""
						echo -e "\t- Вес для данного подключения задан как: 1"
					fi
				fi
			done
		done
		local TEXT="\n\t\"balancers\": ["
		local TEXT=$TEXT"\n\t\t\t{\n\t\t\t\"tag\": \"random\",\n\t\t\t\"selector\": [$SELECTOR],\n\t\t\t\"strategy\": {\n\t\t\t\t\"type\": \"Random\",\n\t\t\t\t\"settings\": {\"weights\": [$WEIGHTS]}\n\t\t\t\t}"
		BAL_LIST=$BAL_LIST'rn\tСлучайное распределение\trandom\n'
	fi
	echo ""
	echo "Хотите ли вы использовать резервирование (для исходящих подключений)?"
	echo ""
	echo -e "\tЭто позволит переключаться на другое исходящее подключение (из"
	echo "выбранных), при отсутствии доступа к текущему..."
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		echo ""
		echo "Нужно выбрать два (или больше) подключения(ий) из списка ниже."
		echo ""
		balancerSelect
		local SELECTOR=$RESULT
		echo ""
		echo "Выберите подключение - через которое будет направлен трафик,"
		echo "если Xray не удастся сделать выбор..." 
		echo ""
		outSelect
		local OUTTAG=$RESULT
		echo ""
		echo -e "\tДля выбора исходящего подключения - используется PING. Укажите адрес"
		echo "узла, для которого будет измеряться задержка передачи данных..."
		echo ""
		read -r -p "URL-адрес (для проверки подключений):" PING_URL
		PING_URL=`echo "$PING_URL" | awk '{gsub(/"/,"%22")}1' | awk '{gsub(/,/,"%2C")}1'`
		if [ -z "$PING_URL" ];then
			local PING_URL="https://www.google.com/generate_204"
		fi
		echo ""
		echo -e "\tДля своевременного переключения между исходящими подключениями,"
		echo "нужно настроить период проверки..."
		echo ""
		echo "Выберите единицы измерения времени."
		echo ""
		echo -e "\t1: Микросекунды"
		echo -e "\t2: Секунды"
		echo -e "\t3: Минуты (по умолчанию)"
		echo -e "\t4: Часы"
		echo ""
		read -r -p "Единицы измерения:"
		if [ "$REPLY" = "1" ];then
			local UNITS="ms"
		elif [ "$REPLY" = "2" ];then
			local UNITS="s"
		elif [ "$REPLY" = "4" ];then
			local UNITS="h"
		else
			local UNITS="m"
		fi
		echo ""
		read -r -p "Продолжительность периода проверки:" TIME
		if [ -n "$TIME" -a -z "`echo "$TIME" | sed 's/[0-9]//g'`" ];then
			TIME=$TIME$UNITS
		else
			TIME="1$UNITS"
			echo ""
			echo -e "\t- Продолжительность периода установлена на: $TIME"
		fi
		if [ -z "$BAL_LIST" ];then
			local TEXT="\n\t\"balancers\": ["
		else
			local TEXT=$TEXT"\n\t\t\t},"
		fi
		local TEXT=$TEXT"\n\t\t\t{\n\t\t\t\"tag\": \"reservation\",\n\t\t\t\"selector\": [$SELECTOR],\n\t\t\t\"strategy\": {\n\t\t\t\t\"type\": \"leastPing\"\n\t\t\t\t},\n\t\t\t\"fallbackTag\": $OUTTAG"
		OBSERVATORY_TEMP="{\n\"observatory\": {\n\t\"subjectSelector\": [$SELECTOR],\n\t\"probeURL\": \"$PING_URL\",\n\t\"probeInterval\": \"$TIME\",\n\t\"enableConcurrency\": true\n\t}\n}"
		local BAL_LIST=$BAL_LIST'rs\tРезервирование\treservation\n'
	fi
	if [ -n "$BAL_LIST" ];then
		OUT_LIST=$BAL_LIST$OUT_LIST
		local TEXT=$TEXT"\n\t\t\t}\n\t\t],"
		PART_BALANCERS=$TEXT
	fi
	echo ""
	echo -e "\tНастройка распределения - завершена."
	}

function ruleName
	{
	RESULT=""
	local NUM=$1
	local COUNT="0"
	local BLOCK=`echo -e $PART_BLOCK`
	local FILTER=`echo -e $PART_FILTER`
	local DIRECT=`echo -e $PART_DIRECT`
	read -r -p "Название правила:"
	REPLY=`echo $REPLY | awk '{gsub(/\t/," ")}1'`
	if [ "$REPLY" = "" ];then
		REPLY="Правило $NUM"
	fi
	IFS=$'\n\t'
	for LINE in $BLOCK;do
		if [ "`echo $LINE | awk '{sub(/\/\/ /,"")}1'`" = "$REPLY" ];then
			local COUNT="1"
			break
		fi
	done
	for LINE in $FILTER;do
		if [ "`echo $LINE | awk '{sub(/\/\/ /,"")}1'`" = "$REPLY" ];then
			local COUNT="1"
			break
		fi
	done
	for LINE in $DIRECT;do
		if [ "`echo $LINE | awk '{sub(/\/\/ /,"")}1'`" = "$REPLY" ];then
			local COUNT="1"
			break
		fi
	done
	if [ "$COUNT" -gt "0" ];then
		if [ "$REPLY" = "Правило $NUM" ];then
			RESULT="$REPLY (2)"
		else
			echo ""
			echo -e "\tВ конфигурации уже есть правило: $REPLY."
			echo ""
			ruleName $NUM
		fi
	else
		RESULT=$REPLY
	fi
	}

function ruleFilter
	{
	local TEXT=$1
	FILTER_LIST=""
	echo ""
	echo -e "\tВы можете добавлять строку за строкой... Для завершения процесса"
	echo "добавления - нажмите ввод (оставив строку пустой)."
	filterAdd
	if [ -n "$FILTER_LIST" ];then
		local NEW_FILTERS=$NEW_FILTERS'\n\t\t\t'$1'\n'
		local NEW=""
		IFS=$','
		for LINE in $FILTER_LIST;do
			local NEW_FILTERS=$NEW_FILTERS$NEW'\t\t\t\t"'$LINE'"'
			local NEW=',\n'
		done
		local NEW_FILTERS=$NEW_FILTERS'\n\t\t\t\t],'
	fi
	RESULT=$NEW_FILTERS
	}

function rule
	{
	local NUM="$1"
	if [ ! "$NUM" = "1" ];then
		echo "Хотите добавить ещё одно правило?"
		echo ""
		echo -e "\t1: Да"
		echo -e "\t0: Нет (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		echo ""
	fi
	if [ "$REPLY" = "1" -o "$NUM" = "1" ];then
		echo "Выберите одно (или несколько) входящих подключений..."
		echo ""
		inSelect
		local INTAG="$RESULT"
		echo ""
		echo "Выберите исходящее подключение..."
		echo ""
		outSelect
		local OUTTAG=$RESULT
		echo ""
		echo -e "\tОсмысленное название правила - поможет вам при работе с фильтрами. Вы"
		echo "можете оставить поле пустым (и просто нажать ввод), оно будет сгенерировано"
		echo "автоматически..."
		echo ""
		ruleName $NUM
		NAME=$RESULT
		local NUM=`expr $NUM + 1`
		echo ""
		echo "Нужно ли добавить в правило фильтрацию?"
		echo ""
		echo -e "\t1: Да, по доменным именам"
		echo -e "\t2: Да, по IP-адресам"
		echo -e "\t0: Нет (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:" FILTER
		if [ "`echo "$OUTTAG" | grep -c '"random"'`" -gt "0" -o "`echo "$OUTTAG" | grep -c '"reservation"'`" -gt "0" ];then
			local TAG="balancerTag"
		else
			local TAG="outboundTag"
		fi
		local TEXT="\n\t\t\t// $NAME\n\t\t\t{\n\t\t\t\"inboundTag\": [$INTAG],\n\t\t\t\"$TAG\": $OUTTAG,"
		if [ "$FILTER" = "1" ];then
			ruleFilter '"domain": ['
			local TEXT=$TEXT$RESULT
		elif [ "$FILTER" = "2" ];then
			ruleFilter '"ip": ['
			local TEXT=$TEXT$RESULT
		else
			RESULT=""
		fi
		local TEXT=$TEXT"\n\t\t\t\"type\": \"field\""
		if [ "$OUTTAG" = '"block"' ];then
			if [ -n "$PART_BLOCK" ];then
				PART_BLOCK=$PART_BLOCK"\n\t\t\t},\n"
			fi
			PART_BLOCK="$PART_BLOCK$TEXT"
		elif [ "$FILTER" = "1" -o "$FILTER" = "2" ];then
			if [ -n "$PART_FILTER" ];then
				PART_FILTER=$PART_FILTER"\n\t\t\t},\n"
			fi
			PART_FILTER="$PART_FILTER$TEXT"
		else
			if [ -n "$PART_DIRECT" ];then
				PART_DIRECT=$PART_DIRECT"\n\t\t\t},\n"
			fi
			PART_DIRECT="$PART_DIRECT$TEXT"
		fi
		echo ""
		rule $NUM
	fi
	if [ -n "$PART_DIRECT" ];then
		echo ""
		echo -e "\tДобавление правил - завершено."
	else
		#echo ""
		echo -e "\tНеобходимо добавить хотя бы одно правило - пропускающее трафик без"
		echo "фильтрации..."
		echo ""
		rule $NUM
	fi
	}

function routing
	{
	local FLAG=$1
	listsGet $FLAG
	PART_BALANCERS=""
	PART_BLOCK=""
	PART_FILTER=""
	PART_DIRECT=""
	OBSERVATORY_TEMP=""
	ROUTING_TEMP=""
	if [ "`echo -e $OUTBOUNDS_TEMP | grep -c '"protocol": "vless",'`" -gt "1" -a "$FLAG" = "2" ];then
		balancers $FLAG
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	elif [ -f "$OUTBOUNDS"  -a ! "$FLAG" = "2" ];then
		if [ "`cat $OUTBOUNDS | grep -c '"protocol": "vless",'`" -gt "1" ];then
			balancers
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
	fi
	clear
	echo "==================================== Правила ==================================="
	echo "$MODE"
	echo -e "\tТеперь нужно добавить правила, по которым Xray будет распределять"
	echo "трафик (от входящих подключений, к исходящим)..."
	echo ""
	rule "1"
	if [ -n "$PART_DIRECT" -o -n "$PART_FILTER" ];then
		local TEXT="{\n\"routing\": {"
		local TEXT="$TEXT$PART_BALANCERS"
		local TEXT=$TEXT"\n\t\"rules\": ["
		local TEXT="$TEXT$PART_BLOCK"
		if [ -n "$PART_BLOCK" -a -n "$PART_FILTER" ];then
			local TEXT=$TEXT"\n\t\t\t},\n"
		fi 
		local TEXT="$TEXT$PART_FILTER"
		if [ -n "$PART_DIRECT" -a -n "$PART_FILTER" -o -n "$PART_BLOCK" -a -n "$PART_DIRECT" ];then
			local TEXT=$TEXT"\n\t\t\t},\n"
		fi 
		local TEXT="$TEXT$PART_DIRECT"
		local TEXT=$TEXT"\n\t\t\t}\n\t\t]\n\t}\n}"
		ROUTING_TEMP="$TEXT"
		clear
		echo "================================= Маршрутизация ================================"
		echo "$MODE"
		echo -e "\tНастройки маршрутизации - сформированы."
		echo ""
		echo "Хотите просмотреть результат?"
		echo ""
		echo -e "\t1: Да"
		echo -e "\t0: Нет (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		if [ "$REPLY" = "1" ];then
			clear
			echo "==================================== ROUTING ==================================="
			echo -e "$ROUTING_TEMP"
			if [ -n "$OBSERVATORY_TEMP" ];then
				echo "================================= OBSERVATORY ================================"
				echo -e "$OBSERVATORY_TEMP"
			fi
			echo "================================================================================"
		fi
		echo ""
		if [ "$FLAG" = "2" ];then
			echo "Сохранить конфигурацию?"
		else
			echo "Сохранить результат?"
		fi
		echo ""
		echo -e "\t1: Да"
		echo -e "\t2: Нет, настроить маршрутизацию заново"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		if [ "$REPLY" = "1" ];then
			if [ "$FLAG" = "2" ];then
				fileSave "$INBOUNDS" "$INBOUNDS_TEMP"
				fileSave "$OUTBOUNDS" "$OUTBOUNDS_TEMP"
			fi
			fileSave "$ROUTING" "$ROUTING_TEMP"
			fileSave "$OBSERVATORY" "$OBSERVATORY_TEMP"
		elif [ "$REPLY" = "2" ];then
			routing "$FLAG"
		else
			if [ ! "$FLAG" = "1" -a ! "$FLAG" = "2" ];then
				mainMenu
				exit
			fi
		fi
	fi
	}

function vps
	{
	local TEXT=""
	local NUM="$1"
	if [ ! "$NUM" = "1" ];then
		echo "Хотите добавить ещё один ключ vless?"
		echo ""
		echo -e "\t1: Да"
		echo -e "\t0: Нет (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
	else
		echo -e "\tУ вас должен быть ключ vless (он выглядит примерно так:"
		echo "vless://UniVeRsa-LlYU-nICu-eiDe-NTiFieRuNivE@some.domain:123?type=setting&"
		echo "security=setting&pbk=pUblIC-KeYpuBlICkeyPUbLickEyPubLIckEyPuliCk&fp=torbrowser&"
		echo "sni=doma.in&sid=sHOrtidENtifIerS&spx=%2F&flow=setting#Country-Username),"
		echo "его можно скопировать и вставить в окно терминала - правой кнопкой мыши..."
	fi
	if [ "$REPLY" = "1" -o "$NUM" = "1" ];then
		echo ""
		read -r -p "Ключ vless:"
		if [ -z "$REPLY" ];then
			echo ""
			echo -e "\tВвод ключей - завершён."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			local KEY=`echo "$REPLY" | awk '{sub(/^vless:\/\//,"uuid=")}1' | awk '{sub(/:/,"&port=")}1' | awk '{sub(/@/,"&doip=")}1' | awk '{sub(/#/,"#name=")}1' | tr \&:?@# \\\n`
			local UUID=`echo -e "$KEY" | grep "uuid=" | awk '{sub(/uuid=/,"")}1'`
			local DOIP=`echo -e "$KEY" | grep "doip=" | awk '{sub(/doip=/,"")}1'`
			local PORT=`echo -e "$KEY" | grep "port=" | awk '{sub(/port=/,"")}1'`
			local TYPE=`echo -e "$KEY" | grep "type=" | awk '{sub(/type=/,"")}1'`
			local SEC=`echo -e "$KEY" | grep "security=" | awk '{sub(/security=/,"")}1'`
			local PBK=`echo -e "$KEY" | grep "pbk=" | awk '{sub(/pbk=/,"")}1'`
			local FP=`echo -e "$KEY" | grep "fp=" | awk '{sub(/fp=/,"")}1'`
			local SNI=`echo -e "$KEY" | grep "sni=" | awk '{sub(/sni=/,"")}1'`
			local SID=`echo -e "$KEY" | grep "sid=" | awk '{sub(/^sid=/,"")}1'`
			local FLOW=`echo -e "$KEY" | grep "flow=" | awk '{sub(/^flow=/,"")}1'`
			local NAME=`echo -e "$KEY" | grep "name=" | awk '{sub(/^name=/,"")}1' | awk -F"-" '{print $1}'`
			if [ -z "$NAME" ];then
				local NAME="Подключение $NUM"
			fi
			if [ -n "$UUID" -a -n "$DOIP" -a -n "$PORT" -a -n "$TYPE" -a -n "$SEC" -a -n "$PBK" -a -n "$FP" -a -n 	"$SNI" -a -n "$SID" -a -n "$FLOW" ];then
				echo ""
				echo -e "\tКлюч - принят."
				local TEXT=$TEXT"\n\t\t},\n\n\t\t// $NAME\n\t\t{\n\t\t\"tag\": \"vps$NUM\",\n\t\t\"domainStrategy\": \"UseIPv4\",\n\t\t\"protocol\": \"vless\",\n\t\t\"settings\": {\n\t\t\t\"vnext\": [\n\t\t\t\t\t{\n\t\t\t\t\t\"address\": \"$DOIP\",\n\t\t\t\t\t\"port\": $PORT,\n\t\t\t\t\t\"users\": [\n\t\t\t\t\t\t\t{\n\t\t\t\t\t\t\t\"encryption\": \"none\",\n\t\t\t\t\t\t\t\"flow\": \"$FLOW\",\n\t\t\t\t\t\t\t\"id\": \"$UUID\"\n\t\t\t\t\t\t\t}\n\t\t\t\t\t\t]\n\t\t\t\t\t}\n\t\t\t\t]\n\t\t\t},\n\t\t\"streamSettings\": {\n\t\t\t\"network\": \"$TYPE\",\n\t\t\t\"security\": \"$SEC\",\n\t\t\t\"realitySettings\": {\n\t\t\t\t\"publicKey\": \"$PBK\",\n\t\t\t\t\"fingerprint\": \"$FP\",\n\t\t\t\t\"serverName\": \"$SNI\",\n\t\t\t\t\"shortId\": \"$SID\",\n\t\t\t\t\"spiderX\": \"/\"\n\t\t\t\t}\n\t\t\t}"
				echo ""
				echo -e "\tПодключение: $NAME - добавлено."
				echo ""
				local NUM=`expr $NUM + 1`
				OUTBOUNDS_TEMP="$OUTBOUNDS_TEMP$TEXT"
				vps "$NUM"

			else
				echo ""
				echo -e "\tОшибка: введён некорректный ключ."
				echo ""
				vps "$NUM"
			fi
		fi
	fi
	}

function outbounds
	{
	local FLAG=$1
	clear
	echo "============================= Исходящие подключения ============================"
	echo "$MODE"
	OUTBOUNDS_TEMP="{\n\"outbounds\": [\n\t\t// Провайдер\n\t\t{\n\t\t\"tag\": \"provider\",\n\t\t\"protocol\": \"freedom\""
	vps "1"
	OUTBOUNDS_TEMP=$OUTBOUNDS_TEMP"\n\t\t},\n\n\t\t// Блокировка\n\t\t{\n\t\t\"tag\": \"block\",\n\t\t\"protocol\": \"blackhole\",\n\t\t\"response\": {\n\t\t\t\"type\": \"none\"\n\t\t\t}\n\t\t}\n\t]\n}"
	clear
	echo "============================= Исходящие подключения ============================"
	echo ""
	echo -e "\tНастройки исходящих подключений - сформированы."
	echo ""
	echo "Хотите просмотреть результат?"
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		clear
		echo "=================================== OUTBOUNDS =================================="
		echo -e "$OUTBOUNDS_TEMP"
		echo "================================================================================"
	fi
	echo ""
	if [ "$FLAG" = "2" ];then
		echo "Зафиксировать результат?"
	else
		echo "Сохранить результат?"
	fi
	echo ""
	echo -e "\t1: Да"
	echo -e "\t2: Нет, настроить исходящие подключения заново"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		if [ "$FLAG" = "2" ];then
			routing "2"
		else
			fileSave "$OUTBOUNDS" "$OUTBOUNDS_TEMP"
		fi
	elif [ "$REPLY" = "2" ];then
		outbounds "$FLAG"
	else
		if [ ! "$FLAG" = "1" -a ! "$FLAG" = "2" ];then
			mainMenu
			exit
		fi
	fi
	}

function authRead
	{
	USER_NAME=""
	PASS=""
	echo -e "\tЕсли есть необходимость использовать авторизацию (при работе с прокси),"
	echo "введите имя пользователя и пароль. Или нажмите ввод - чтобы отключить её, для"
	echo "этого подключения."
	echo ""
	read -r -p "Имя пользователя:" USER_NAME
	if [ ! "$USER_NAME" = "`echo $USER_NAME | awk '{gsub(/"/,"")}1'`" ];then
		USER_NAME=`echo $USER_NAME | awk '{gsub(/"/,"")}1'`
		echo ""
		echo -e "\t- Имя пользователя изменено на: '$USER_NAME'"
	fi
	if [ -z "$USER_NAME" ];then
		echo ""
		echo -e "\tАвторизация - отключена."
	else
		echo ""
		read -r -p "Пароль:" PASS
		if [ ! "$PASS" = "`echo $PASS | awk '{gsub(/"/,"")}1'`" ];then
			PASS=`echo $PASS | awk '{gsub(/"/,"")}1'`
			echo ""
			echo -e "\t- Пароль изменён на: '$PASS'"
		fi
echo "p=$PASS|"
		if [ -z "$PASS" ];then
			echo ""
			echo -e "\tАвторизация - отключена."
			echo ""
		fi
	fi
	}

function portRead
	{
	read -r -p "Номер порта:"
	PORT=`echo "$REPLY" | grep -E '^-?[[:digit:]]+$'`
	if [ -n "$PORT" -a -z "`echo "$REPLY" | sed 's/[0-9]//g'`" -a ! "$REPLY" = "0" -a "$REPLY" -lt "65536" ];then
		if [ "`echo -e "$INBOUNDS_TEMP" | grep -c '"port": '$PORT`" -gt "0" ];then
			echo ""
			echo "Порт: $PORT - уже используется в конфигурации. Что следует сделать?"
			echo ""
			echo -e "\t1: Изменить номер порта"
			echo -e "\t2: Всё равно использовать порт $PORT (по умолчанию)"
			echo ""
			read -r -p "Ваш выбор:"
			if [ "$REPLY" = "1" ];then
				echo ""
				portRead
			else
				echo ""
				authRead
			fi
		else
			echo ""
			authRead
		fi
	else
		echo ""
		echo -e "\tОшибка: введено некорректное значение."
		echo ""
		portRead
	fi
	}

function ipRead
	{
	echo "В каких сегментах, должно быть доступно данное прокси-подключение?"
	echo ""
	echo -e "\t1: Только в домашнем"
	echo -e "\t2: Ввести IP-адрес вручную"
	echo -e "\t0: Во всех (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		IP=`ip addr show br0 | awk -F" |/" '{gsub(/^ +/,"")}/inet /{print $2}'`
		echo ""
		portRead
	elif [ "$REPLY" = "2" ];then
		local SEG_LIST=`ip addr show | awk -F" |/" '{gsub(/^ +/,"")}/inet /{print "\t"$(NF), $2}'`
		echo ""
		echo "Доступны следующие варианты:"
		echo ""
		echo "$SEG_LIST"
		echo ""
		read -r -p "IP-адрес:"
		if [ -n "$REPLY" -a  "`echo "$SEG_LIST" | grep -c "$REPLY"`" -gt "0" ];then
			IP=$REPLY
			echo ""
			portRead
		else
			echo ""
			echo -e "\tОшибка: введено некорректное значение."
			echo ""
			ipRead
		fi
	else
		IP="0.0.0.0"
		echo ""
		portRead
	fi
	}

function proxy
	{
	PROXY_NAME=""
	local NUM="$1"
	if [ "$NUM" = "1" ];then
		echo -e "\tВы можете добавить в конфигурацию прокси-подключения - для организации"
		echo "доступа к VPS по протоколам SOCKS4/5 (с авторизацией, при желании)..."
		echo ""
		echo "Хотите добавить прокси-подключение?"
	else
		echo "Хотите добавить ещё одно прокси-подключение?"
	fi
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		if [ "$NUM" = "1" ];then
			echo ""
			echo -e "\tВы можете ввести название для прокси-подключения, а можете оставить"
			echo "поле пустым (и нажать ввод). Название будет сгенерировано автоматически..."
		fi
		echo ""
		read -r -p "Название подключения:" PROXY_NAME
		PROXY_NAME=`echo $PROXY_NAME | awk '{gsub(/\t/," ")}1'`
		if [ -z "$PROXY_NAME" ];then
			PROXY_NAME="Прокси $NUM"
		fi
		echo ""
		ipRead
		if [ -n "$PROXY_NAME" -a -n "$IP" -a -n "$PORT" ];then
			if [ -z "$INBOUNDS_TEMP" ];then
				local TEXT="{\n\"inbounds\": ["
			else
				local TEXT="\t\t},\n"
			fi
			local TEXT=$TEXT"\n\t\t// $PROXY_NAME\n\t\t{\n\t\t\"tag\": \"proxy$NUM\",\n\t\t\"listen\": \"$IP\",\n\t\t\"port\": $PORT,\n\t\t\"protocol\": \"socks\",\n\t\t\"settings\": {"
			if [ -n "$USER_NAME" -a -n "$PASS" ];then
				local TEXT=$TEXT"\n\t\t\t\"auth\": \"password\",\n\t\t\t\"accounts\": [\n\t\t\t\t{\n\t\t\t\t\"user\": \"$USER_NAME\",\n\t\t\t\t\"pass\": \"$PASS\"\n\t\t\t\t}\n\t\t\t],"
			else
				local TEXT=$TEXT"\n\t\t\t\"auth\": \"noauth\","
			fi
			local TEXT=$TEXT"\n\t\t\t\"udp\": false,\n\t\t\t\"ip\": \"$IP\"\n\t\t\t},\n\t\t\"sniffing\": {\n\t\t\t\"destOverride\": [\"http\", \"tls\"],\n\t\t\t\"enabled\": true,\n\t\t\t\"metadataOnly\": false\n\t\t\t}"
			INBOUNDS_TEMP="$INBOUNDS_TEMP$TEXT"
			echo ""
			echo -e "\tПодключение: $PROXY_NAME - добавлено."
			echo ""
		fi
		local NUM=`expr $NUM + 1`	
		proxy "$NUM"
	fi
	}

function inbounds
	{
	INBOUNDS_TEMP=""
	local FLAG=$1
	clear
	echo "============================= Входящие подключения ============================="
	echo "$MODE"
	echo "Хотите ли вы использовать политику Xkeen?"
	echo ""
	echo -e "\tЭто позволит направлять трафик устройств через VPS - добавляя их"
	echo "в политику Xkeen (в настройках маршрутизатора)..."
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:" POLICY
	if [ "$POLICY" = "1" ];then
		INBOUNDS_TEMP="{\n\"inbounds\": [\n\t\t// Политика Xkeen\n\t\t{\n\t\t\"tag\": \"policy\",\n\t\t\"port\": 61219,\n\t\t\"protocol\": \"dokodemo-door\",\n\t\t\"settings\": {\n\t\t\t\"network\": \"tcp\",\n\t\t\t\"followRedirect\": true\n\t\t\t},\n\t\t\"sniffing\": {\n\t\t\t\"enabled\": true,\n\t\t\t\"routeOnly\": true,\n\t\t\t\"destOverride\": [\"http\", \"tls\"]\n\t\t\t}"
		echo ""
		echo "Политика Xkeen - добавлена."
		echo ""
		echo -e "\tНе забудьте создать в веб-конфигураторе маршрутизатора (Интернет/"
		echo "Приоритеты подключений) политику, с названием \"Xkeen\". И добавить в неё все"
		echo "подключения - которые используются для доступа в интернет..."
	fi
	echo ""
	proxy "1"
	if [ -n "$INBOUNDS_TEMP" ];then
		INBOUNDS_TEMP=$INBOUNDS_TEMP"\n\t\t}\n\t]\n}"
	fi
	if [ -z "$INBOUNDS_TEMP" ];then
		echo ""
		echo -e "\tОшибка: необходимо добавить хотя бы одно входящее подключение."
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		inbounds $FLAG
	fi
	clear
	echo "============================= Входящие подключения ============================="
	echo "$MODE"
	echo -e "\tНастройки входящих подключений - сформированы."
	echo ""
	echo "Хотите просмотреть результат?"
	echo ""
	echo -e "\t1: Да"
	echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		clear
		echo "=================================== INBOUNDS ==================================="
		echo -e "$INBOUNDS_TEMP"
		echo "================================================================================"
	fi
	echo ""
	if [ "$FLAG" = "2" ];then
		echo "Зафиксировать результат?"
	else
		echo "Сохранить результат?"
	fi
	echo ""
	echo -e "\t1: Да"
	echo -e "\t2: Нет, настроить входящие подключения заново"
	echo -e "\t0: Отмена (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		if [ "$FLAG" = "2" ];then
			outbounds "2"
		else
			fileSave "$INBOUNDS" "$INBOUNDS_TEMP"
		fi
	elif [ "$REPLY" = "2" ];then
		inbounds "$FLAG"
	else
		if [ ! "$FLAG" = "1" -a ! "$FLAG" = "2" ];then
			mainMenu
			exit
		fi
	fi
	}

function installXkeen
	{
	clear
	echo "================================ Установка Xkeen ==============================="
	echo "$MODE"
	opkg update
	opkg install curl
	curl -sOfL https://raw.githubusercontent.com/Skrill0/XKeen/main/install.sh
	chmod +x ./install.sh
	./install.sh
	}

function uninstallXkeen
	{
	clear
	echo "================================ Удаление Xkeen ================================"
	echo "$DEMO"
	echo "Вы уверенны что хотите удалить Xkeen?"
	echo ""
	echo -e "\t1: Да"
		echo -e "\t0: Нет (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		echo "Удаление Xkeen:"
		opkg remove xkeen
		echo ""
		echo "Удаление Xray"
		opkg remove xray
		echo ""
		echo "Хотите ли вы удалить резервные копии Xkeen?"
		echo ""
		echo -e "\t1: Да"
		echo -e "\t0: Нет (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:"
		if [ "$REPLY" = "1" ];then
			rm -rf /opt/backups
			echo -e "\tРезервные копии Xkeen - удалены."
		fi
	fi
	echo ""
	}

function buttonSelect
	{
	local FLAG=$1
	echo "Выберите кнопку:"
	echo ""
	echo -e "\t1: Кнопка WiFi"
	echo -e "\t2: Кнопка FN1"
	echo -e "\t3: Кнопка FN2"
	if [ "$FLAG" = "1" ];then
		echo -e "\t0: Отмена (по умолчанию)"
	else
		echo -e "\t0: Завершить процесс настройки (по умолчанию)"
	fi
	echo ""
	read -r -p "Ваш выбор:" BUTTON_NAME
	if [ "$BUTTON_NAME" = "1" -o "$BUTTON_NAME" = "2" -o "$BUTTON_NAME" = "3" ];then
		echo ""
		echo "Выберите тип нажатия:"
		echo ""
		echo -e "\t1: Короткое нажатие"
		echo -e "\t2: Двойное нажатие"
		echo -e "\t3: Длинное нажатие"
		echo -e "\t0: Отмена (по умолчанию)"
		echo ""
		read -r -p "Ваш выбор:" TYPE
		if [ "$TYPE" = "1" -o "$TYPE" = "2" -o "$TYPE" = "3" ];then
			echo ""
			echo "Выберите действие:"
			echo ""
			echo -e "\t1: Запустить Xkeen"
			echo -e "\t2: Остановить Xkeen"
			echo -e "\t3: Перезапустить Xkeen"
			echo -e "\t0: Отмена (по умолчанию)"
			echo ""
			read -r -p "Ваш выбор:" ACTION
			if [ "$ACTION" = "1" -o "$ACTION" = "2" -o "$ACTION" = "3" ];then
				if [ "$ACTION" = "1" ];then
					ACTION='xkeen -start'
				elif [ "$ACTION" = "2" ];then
					ACTION='xkeen -stop'
				else
					ACTION='xkeen -restart'
				fi
				if [ "$TYPE" = "1" ];then
					TYPE='click'
				elif [ "$TYPE" = "2" ];then
					TYPE='double-click'
				else
					TYPE='hold'
				fi
				if [ "$BUTTON_NAME" = "1" ];then
					WLAN=$WLAN$TYPE'&'$ACTION'\t'
				elif [ "$BUTTON_NAME" = "2" ];then
					FN1=$FN1$TYPE'&'$ACTION'\t'
				else
					FN2=$FN2$TYPE'&'$ACTION'\t'
				fi
				echo ""
				echo -e "\tНастройка - добавлена в конфигурацию."
				echo ""
				read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
				clear
				echo "=============================== Настройка кнопки ==============================="
				echo "$MODE"
				buttonSelect
			fi
		fi
	else
		if [ "$FLAG" = "1" ];then
			buttonMenu
			exit
		fi
	fi
	}

function buttonConfig
	{
	WLAN=""
	FN1=""
	FN2=""
	clear
	echo "=============================== Настройка кнопки ==============================="
	echo "$MODE"
	echo -e "\tНекоторые кнопки (из списка ниже) могут физически отсутствовать на вашей"
	echo "модели маршрутизатора. Пожалуйста выбирайте только те кнопки - которые есть на"
	echo "устройстве..."
	echo ""
	buttonSelect "1"
	if [ -n "$WLAN" -o -n "$FN1" -o -n "$FN2" ];then
		local TEXT='#!/opt/bin/sh\n\ncase "$button" in\n\n'
		if [ -n "$WLAN" ];then
			local TEXT=$TEXT'"WLAN")\n\tcase "$action" in\n'
			WLAN=`echo -e $WLAN`
			IFS=$'\t'
			for LINE in $WLAN;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		if [ -n "$FN1" ];then
			local TEXT=$TEXT'"FN1")\n\tcase "$action" in\n'
			FN1=`echo -e $FN1`
			IFS=$'\t'
			for LINE in $FN1;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		if [ -n "$FN2" ];then
			local TEXT=$TEXT'"FN2")\n\tcase "$action" in\n'
			FN2=`echo -e $FN2`
			IFS=$'\t'
			for LINE in $FN2;do
				local TEXT=$TEXT'\t"'`echo $LINE | awk '{gsub(/&/,"\")\n\t\t")}1'`'\n\t\t;;\n' 
			done
			local TEXT=$TEXT'\tesac\n\t;;\n'
		fi
		local TEXT=$TEXT'esac'
		fileSave "$BUTTON" "$TEXT"
		echo ""
		echo -e "\tНе забудьте выбрать вариант \"OPKG - Запуск скриптов button.d\" в"
		echo "веб-конфигураторе маршрутизатора (Управление/Параметры системы/Назначение кнопок"
		echo "и индикаторов интернет-центра) для всех кнопок и типов нажатия - которые вы"
		echo "настроили..."
		echo ""
		else
		echo ""
		echo -e "\tНовая конфигурация - не задана..."
		echo ""
	fi
	
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	}

function buttonMenu
	{
	clear
	echo "=============================== Настройка кнопок ==============================="
	echo "$MODE"
	echo "Доступные действия:"
	echo ""
	echo -e "\t1: Настроить новую конфигурацию кнопок"
	if [ -f "$BUTTON" ];then
		echo -e "\t2: Сбросить текущую конфигурацию кнопок"
	fi
	echo -e "\t0: Вернуться в главное меню (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		buttonConfig
		buttonMenu
		exit
	elif [ "$REPLY" = "2" ];then
		rm -rf $BUTTON
		if [ ! -f "$BUTTON" ];then
			echo ""
			echo -e "\tФайл: $BUTTON - удалён."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		fi
		buttonMenu
		exit
	else
		mainMenu
		exit
	fi
	}

function masterMenu
	{
	clear
	echo "============================= Мастер настройки Xray ============================"
	echo "$MODE"
	echo -e "\tВас приветствует мастер настройки Xray. Он поможет вам"
	echo "настроить конфигурацию: входящих, исходящих подключений и маршрутизацию (в режиме диалога)..."
	echo
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	inbounds "2"
	echo ""
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	if [ ! "$1" = "1" ];then
		mainMenu
	fi
	exit
	}

function filtersMenu
	{
	clear
	echo "=============================== Фильтры =============================="
	echo "$MODE"
	echo -e "\t1: Добавить новый фильтр"
	echo -e "\t2: Редактировать имеющиеся фильтры"
	echo -e "\t0: Вернуться в главное меню (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" ];then
		filterNew
	elif [ "$REPLY" = "2" ];then
		filterEditor
	else
		mainMenu
		exit
	fi
	}

function extraMenu
	{
	clear
	echo "================================= Дополнительно ================================"
	echo "$MODE"
	echo "Что вы хотите сделать?"
	echo ""
	echo -e "\t1: Удалить Xvps"
	if [ -d "$BACKUP" ];then
		echo -e "\t2: Удалить резервные копии Xvps"
	fi
	if [ -d "/opt/backups" ];then
		echo -e "\t3: Удалить резервные копии Xkeen"
	fi
	echo -e "\t0: Вернуться в главное меню (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
		if [ "$REPLY" = "1" ];then
			clear
			if [ ! "$DEMO" = "1" ];then
				rm -rf /opt/bin/xvps
			else
				echo ""
				echo -e "\t- Xvps условно удалён"
			fi
			exit
		elif [ "$REPLY" = "2" -a -d "$BACKUP" ];then
			rm -rf $BACKUP
			echo ""
			echo -e "\tРезервные копии Xvps - удалены."
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		elif [ "$REPLY" = "3" -a -d "/opt/backups" ];then
			if [ ! "$DEMO" = "1" ];then
				rm -rf /opt/backups
				echo ""
				echo -e "\tРезервные копии Xkeen - удалены."
				echo ""
			else
				echo ""
				echo -e "\t- Резервные копии Xkeen - условно удалены"
			fi
			echo ""
			read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		else
			mainMenu
			exit
		fi
	extraMenu
	exit
	}

function mainMenu
	{
	if [ "$DEMO" = "1" -a -d "/opt/_xvps" ];then
		local XKEEN="1"
	elif [ ! "$DEMO" = "1" -a "`opkg list-installed | grep -c "xkeen"`" -gt "0" ];then
		local XKEEN="1"
	else
		local XKEEN="0"
	fi
	clear
	echo "===================================== Xvps ====================================="
	echo "$MODE"
	echo "Доступные функции:"
	echo ""
	if [ "$XKEEN" = "1" ];then
		echo -e "\t1: Удаление Xkeen"
		echo -e "\t2: Запуск/перезапуск Xkeen"
		echo -e "\t3: Настройка входящих подключений (inbounds)"
		echo -e "\t4: Настройка исходящих подключений (outbounds)"
	else
		echo -e "\t1: Установка Xkeen"
	fi
	if [ "$XKEEN" = "1" -a -f "$INBOUNDS" -a -f "$OUTBOUNDS" ];then
		echo -e "\t5: Настройка маршрутизации (routing)"
	fi
	if [ "$XKEEN" = "1" ];then
		echo -e "\t6: Мастер настройки конфигурации Xray"
		echo -e "\t7: Настройка кнопок"
		if [ -f "$ROUTING" ];then
			echo -e "\t8: Фильтры"
		fi
	fi
	echo -e "\t9: Дополнительно"
	echo -e "\t0: Выход (по умолчанию)"
	echo ""
	read -r -p "Ваш выбор:"
	if [ "$REPLY" = "1" -a "$XKEEN" = "0" ];then
		if [ ! "$DEMO" = "1" ];then
			installXkeen
		else
			echo ""
			echo -e "\t- Условная установка Xkeen (создан каталог: /opt/_xvps)"
			echo ""
			echo -e "\tЧтобы удалить его, и всё его содержимое - выберите \"Удаление Xkeen\" (в"
			echo "демонстрационном режиме)..."
			mkdir -p "/opt/_xvps/button.d"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "1" -a "$XKEEN" = "1" ];then
		if [ ! "$DEMO" = "1" ];then
			uninstallXkeen
		else
			echo ""
			echo -e "\t- Условное удаление Xkeen (удалён каталог: /opt/_xvps)"
			rm -rf "/opt/_xvps"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "2" -a "$XKEEN" = "1" ];then
		clear
		if [ ! "$DEMO" = "1" ];then
			xkeen -restart
		else
			echo ""
			echo -e "\t- Условный перезапуск Xkeen"
		fi
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "3" -a "$XKEEN" = "1" ];then
		inbounds
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "4" -a "$XKEEN" = "1" ];then
		outbounds
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "5" -a "$XKEEN" = "1" -a -f "$INBOUNDS" -a -f "$OUTBOUNDS" ];then
		routing
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "6" -a "$XKEEN" = "1" ];then
		masterMenu
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		mainMenu
		exit
	elif [ "$REPLY" = "7" -a "$XKEEN" = "1" ];then
		buttonMenu
		exit
	elif [ "$REPLY" = "8" -a "$XKEEN" = "1" -a -f "$ROUTING" ];then
		filtersMenu
		exit
	elif [ "$REPLY" = "9" ];then
		extraMenu
		exit
	else
		echo ""
		read -t 1 -n 1 -r -p " $VERSION                                               © 2024 rino Software Lab." keypress
		clear
		exit
	fi
	}

echo;while [ -n "$1" ];do
case "$1" in

-d)	DEMO="1"
	MODE='                                                                           DEMO'
	INBOUNDS='/opt/_xvps/03_inbounds.json'
	OUTBOUNDS='/opt/_xvps/04_outbounds.json'
	ROUTING='/opt/_xvps/05_routing.json'
	OBSERVATORY='/opt/_xvps/07_observatory.json'
	BUTTON='/opt/_xvps/button.d/xvps.sh'
	BACKUP='/opt/_xvps/backup-xvps'
	clear
	echo "============================ Демонстрационный режим ============================"
	echo "$MODE"
	echo -e "\tXvps запущен в демонстрационном режиме. Он не будет взаимодействовать с"
	echo "установленным Xkeen и конфигурационными файлами Xray. Все результаты работы в"
	echo "данном режиме - будут сохранены в каталог: /opt/_xvps. Все полученные файлы -"
	echo "будут полностью функциональны, и могут быть использованы в конфигурации Xray"
	echo "(если переместить их на свои места)..."
	echo ""
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	mainMenu
	exit
	;;

-i)	MODE='                                                                             -i'
	inbounds "1"
	echo ""
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	exit
	;;

-o)	MODE='                                                                             -o'
	outbounds '1'
	echo ""
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	exit
	;;

-r)	MODE='                                                                             -r'
	if [ -f "$INBOUNDS" -a -f "$OUTBOUNDS" ];then
		routing '1'
		echo ""
		read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
		exit
	else
		echo -e "\tОшибка: отсутствует один из следующих файлов:"
		echo ""
		echo -e "\t$INBOUNDS"
		echo -e "\t\t$OUTBOUNDS"
		echo ""
		echo -e "\t\tОни необходимы для формирования списков подключений..."
		exit
	fi
	;;

-m)	MODE='                                                                             -m'
	masterMenu '1'
	echo ""
	read -n 1 -r -p "(Чтобы продолжить - нажмите любую клавишу...)" keypress
	exit
	;;

-u)	clear
	opkg update
	opkg install ca-certificates wget-ssl
	opkg remove wget-nossl
	wget -O /tmp/xvps.sh https://raw.githubusercontent.com/Neytrino-OnLine/Xvps/refs/heads/main/xvps.sh
	if [ ! "`cat "/tmp/xvps.sh" | grep -c 'function filterGet'`" -gt "0" ];then
		echo "Ошибка: проблемы со скачиванием файла..."
	else
		mv /tmp/xvps.sh /opt/bin/xvps
		chmod +x /opt/bin/xvps
		echo "Сейчас установлен: Xvps `cat "/opt/bin/xvps" | grep '^VERSION="' | awk '{gsub(/VERSION="/,"")}1' | awk '{gsub(/"/,"")}1'`"
	fi
	exit
	;;

-v)	echo " $VERSION"
	exit
	;;

*) echo "Ошибка: введён некорректный ключ.

Доступные ключи:

	-d: Демонстрационный режим
	-i: Настройка входящих подключений (inbounds)
	-o: Настройка исходящих подключений (outbounds)
	-r: Настройка маршрутизации (routing)
	-m: Мастер настройки конфигурации Xray
	-u: Обновление Xvps
	-v: Отображение текущей версии Xvps"
	exit
	;;
	
esac;shift;done
mainMenu
