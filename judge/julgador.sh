#!/bin/bash

source #CONFDIR#/judge.conf
source #CONFDIR#/common.conf
source #SCRIPTSDIR#/enviar-spoj.sh
source #SCRIPTSDIR#/enviar-uri.sh

function updatescore()
{
    contest=$1

    CLASSIFICACAO=1
    cat $CONTESTSDIR/$contest/controle/*.score|sort -n -t ':' -k3|
      sort -s -n -r -t ':' -k2|
      cut -d: -f1|
      while read LINE; do
        echo "<tr><td>$CLASSIFICACAO</td>$LINE";
        ((CLASSIFICACAO++))
      done  > $CONTESTSDIR/$CONTEST/controle/SCORE
}

function updatedotscore()
{
  local NOME="$2"
  local LOGIN="$1"
  local CONTEST="$3"

  source $CONTESTSDIR/$CONTEST/conf

  #gerar arquivo para montar o score
  local ACUMPENALIDADES=0
  local ACUMACERTOS=0
  local TAMARRAY=${#PROBS[@]}
  #Ordem tabela de score
  #nome | A | B | C | D | ... | Acertos | Penalidade |
  {
    printf "<td>$NOME</td>"
    for((prob=0;prob<TAMARRAY;prob+=5)); do
      PENALIDADES=0
      JAACERTOU=0
      TENTATIVAS=0
      PENDING=0
      source $CONTESTSDIR/$CONTEST/controle/$LOGIN.d/$prob 2>/dev/null
      if (( TENTATIVAS == 0 )) ; then
        printf "<td></td>"
      elif (( JAACERTOU > 0 )); then
        ((ACUMACERTOS++))
        ((ACUMPENALIDADES+=PENALIDADES))
        ((JAACERTOU = JAACERTOU/60))
        printf "<td>Yes<br/><small>$TENTATIVAS/$JAACERTOU</small></td>"
      else
        PENDINGBLINK=
        if (( PENDING > 0 )); then
          PENDINGBLINK="<blink>?Yes?</blink>"
        fi
        printf "<td>$PENDINGBLINK<small>$TENTATIVAS/-</small></td>"
      fi
    done
    printf "<td>$ACUMACERTOS ($ACUMPENALIDADES)</td></tr>:$ACUMACERTOS:$ACUMPENALIDADES\n"
  } > $CONTESTSDIR/$CONTEST/controle/$LOGIN.score
}


mkdir -p $SUBMISSIONDIR-julgados
mkdir -p $SUBMISSIONDIR-enviaroj

#make $SUBMISSIONDIR world writtable
chmod 777 $SUBMISSIONDIR

#ordem de ARQ: $CONTEST:$AGORA:$RAND:$LOGIN:comando:$PROBLEMA:$FILETYPE:$RESP
for ARQ in $SUBMISSIONDIR/*; do
  if [[ ! -e "$ARQ" ]]; then
    continue
  fi
  N="$(basename "$ARQ")"
  CONTEST="$(cut -d: -f1 <<< "$N")"
  ID="$(cut -d: -f2,3 <<< "$N")"
  LOGIN="$(cut -d: -f4 <<< "$N")"
  COMANDO="$(cut -d: -f5 <<< "$N")"
  PROBID="$(cut -d: -f6 <<< "$N")"
  LING="$(cut -d: -f7 <<< "$N")"
  RESP="$(cut -d: -f8 <<< "$N")"
  #LING="$(file $ARQ|awk '{print $3}')"

  #carregar contest
  source $CONTESTSDIR/$CONTEST/conf

  if [[ "$CONTEST" == "admin" && "$COMANDO" == "newcontest" ]]; then
    LOGIN="$(cut -d: -f2 <<< "$N")"
    FILENAME="$(cut -d: -f3 <<< "$N")"
    TMPDIR=$(mktemp -d)
    tar xf "$ARQ" -C $TMPDIR/
    CAMINHO="$(dirname $(find $TMPDIR -name 'contest-description.txt'))"
    bash #SCRIPTSDIR#/../bin/cria-contest.sh $CAMINHO
    rm -rf $TMPDIR

  elif [[ "$COMANDO" == "login" ]]; then

    if [[ ! -d $CONTESTSDIR/$CONTEST/controle/$LOGIN.d ]]; then
      mkdir -p $CONTESTSDIR/$CONTEST/controle/$LOGIN.d

      {
        NOME="$(grep "^$LOGIN:" $CONTESTSDIR/$CONTEST/passwd|cut -d: -f3)"
        printf "<td>$NOME</td>"
        TAMARRAY=${#PROBS[@]}
        for ((prob=0;prob<TAMARRAY;prob+=5)); do
            printf "<td></td>"
        done
        printf "<td>0</td></tr>:0:0\n"
      } > $CONTESTSDIR/$CONTEST/controle/$LOGIN.score
      echo "<tr><td>--</td>$(<$CONTESTSDIR/$CONTEST/controle/$LOGIN.score)"|
        cut -d: -f1 >> $CONTESTSDIR/$CONTEST/controle/SCORE
    fi

  elif [[ "$COMANDO" == "corrigido" ]]; then

    PROBIDFILE=$CONTESTSDIR/$CONTEST/controle/$LOGIN.d/$PROBID

    PENALIDADES=0
    JAACERTOU=0
    TENTATIVAS=0
    PENDING=0
    if [[ -e $PROBIDFILE ]]; then
      source $PROBIDFILE
    fi

    TEMPO="$(cut -d: -f1 <<< "$ID")"
    ((TEMPO= (TEMPO - CONTEST_START) ))

    if [[ "$RESP" == "Accepted"  && "$JAACERTOU" == "0" ]] ; then
      (( PENALIDADES= PENALIDADES + TEMPO/60 ))
      JAACERTOU=$TEMPO
      ((PENDING--))
      {
        echo "PENALIDADES=$PENALIDADES"
        echo "JAACERTOU=$JAACERTOU"
        echo "TENTATIVAS=$TENTATIVAS"
        echo "PENDING=$PENDING"
      } > $PROBIDFILE
    elif [[ "$JAACERTOU" == "0" && "$RESP" != "Ignored" ]]; then
      ((PENALIDADES+=20))
      ((PENDING--))
      {
        echo "PENALIDADES=$PENALIDADES"
        echo "JAACERTOU=0"
        echo "TENTATIVAS=$TENTATIVAS"
        echo "PENDING=$PENDING"
      } > $PROBIDFILE
    fi

    if [[ "$RESP" != "Ignored" ]]; then
      echo "$TEMPO:$LOGIN:$PROBID:$LING:$RESP" >> $CONTESTSDIR/$CONTEST/controle/history
    fi


    #gravar no arquivo de solucoes
    #TODO colocar um lock no arquivo do usuario
    USRFILE="$CONTESTSDIR/$CONTEST/data/$LOGIN"
    sed -i -e "s/^$ID:.*/$ID:$PROBID:$RESP/" "$USRFILE"
    chmod 777 "$USRFILE"
    cp "$ARQ" $SUBMISSIONDIR-julgados/

    NOME="$(grep "^$LOGIN:" $CONTESTSDIR/$CONTEST/passwd|cut -d: -f3)"
    updatedotscore "$LOGIN" "$NOME" "$CONTEST"
    updatescore $CONTEST

  elif [[ "$COMANDO" == "submit" ]]; then
    #SITE do problema:
    SITE=${PROBS[PROBID]}

    PROBIDFILE=$CONTESTSDIR/$CONTEST/controle/$LOGIN.d/$PROBID

    PENALIDADES=0
    JAACERTOU=0
    TENTATIVAS=0
    PENDING=0
    if [[ -e $PROBIDFILE ]]; then
      source $PROBIDFILE
    fi

    if (( $JAACERTOU > 0 )) ; then
      RESP=Ignored
      #gravar no arquivo de solucoes
      USRFILE="$CONTESTSDIR/$CONTEST/data/$LOGIN"
      sed -i -e "s/^$ID:.*/$ID:$PROBID:$RESP/" "$USRFILE"
      chmod 777 "$USRFILE"
    elif [[ "$JAACERTOU" == "0" ]] ; then
      cp "$ARQ" $SUBMISSIONDIR-enviaroj/

      ((TENTATIVAS++))
      ((PENDING++))
      {
        echo "PENALIDADES=$PENALIDADES"
        echo "JAACERTOU=0"
        echo "TENTATIVAS=$TENTATIVAS"
        echo "PENDING=$PENDING"
      } > $PROBIDFILE
    fi

    NOME="$(grep "^$LOGIN:" $CONTESTSDIR/$CONTEST/passwd|cut -d: -f3)"
    updatedotscore "$LOGIN" "$NOME" "$CONTEST"
    updatescore $CONTEST


    #copiar $ARQ para o diretorio com historico de submissoes
    cp "$ARQ" "$CONTESTSDIR/$CONTEST/submissions/$ID-$LOGIN-${PROBS[PROBID+3]}.$LING"

  fi
    rm -f "$ARQ"
done
