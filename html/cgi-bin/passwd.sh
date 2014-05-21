#!/bin/bash

source common.sh

POST="$(cat )"

AGORA=$(date +%s)

#limpar caminho, exemplo
#www.brunoribas.com.br/~ribas/moj/cgi-bin/contest.sh/contest-teste/oi
#vira 'contest-teste/oi'
CAMINHO="$PATH_INFO"
#TESTE="$0"
#CAMINHO="$(sed -e 's#.*/contest.sh/##' <<< "$CAMINHO")"

#contest é a base do caminho
CONTEST=$(cut -d'/' -f2 <<< "$CAMINHO")

if [[ "x$CONTEST" == "x" ]] || [[ ! -d "$CONTESTSDIR/$CONTEST" ]]; then
  tela-erro
  exit 0
fi

#o contest é valido, tem que verificar o login
if verifica-login $CONTEST| grep -q Nao; then
  tela-login $CONTEST
fi
source $CONTESTSDIR/$CONTEST/conf
LOGIN=$(pega-login)

if [[ "x$POST" != "x" ]]; then
  SENHAVELHA=$(grep -A2 'name="senhaantiga"' <<< "$POST" |tail -n1|tr -d '\n'|tr -d '\r')
  SENHA=$(grep -A2 'name="senha"' <<< "$POST" |tail -n1|tr -d '\n'|tr -d '\r')
  if ! grep -q "^$LOGIN:$SENHAVELHA:" $CONTESTSDIR/$CONTEST/passwd; then
    tela-login $CONTEST
  fi
  #avisa troca de senha
  touch  $SUBMISSIONDIR/$CONTEST:$AGORA:$RANDOM:$LOGIN:passwd:$SENHAVELHA:$SENHA

  printf "Set-Cookie: login=$LOGIN; Path=/;  expires=$(date --date=@$AGORA)\n"
  printf "Set-Cookie: hash=0000; Path=/; expires=$(date --date=@$AGORA)\n"
  printf "Content-type: text/html\n\n"
  cat << EOF
  <script type="text/javascript">
    window.alert("Senha Trocada com Sucesso");
    top.location.href = "$BASEURL/cgi-bin/contest.sh/$CONTEST"
  </script>

EOF
  exit 0
fi

#estamos logados
cabecalho-html
printf "<h1>Trocar SENHA de $(pega-nome $CONTEST) em \"<em>$CONTEST_NAME</em>\"</h1>\n"

#formulário para trocar a senha
  cat << EOF
<form enctype="multipart/form-data" action="$BASEURL/cgi-bin/passwd.sh/$CONTEST" method="post">
  Senha Antiga: <input name="senhaantiga" type="password"><br/>
  Nova Senha: <input name="senha" type="password"><br/>
  <br/>
  <input type="submit" value="Trocar">
  <br/>
</form>
EOF

cat ../footer.html
exit 0