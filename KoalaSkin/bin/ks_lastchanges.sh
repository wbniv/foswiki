#!/bin/bash
# usage: /n for changes in last n days (default 7)
#        [/n]/all for showing even hidden webs
#   /n,web1,web2,web3... to search only these webs
#   (alternate syntax: /n|web1|web2|web3...)
shopt -s extglob

trap exit PIPE

export wiki wikiurl wiki_bin wiki_lib
# autodetects path if script is in WIKIDIR/bin/scripts/ or bin/sh/ or subdirs
wiki=${SCRIPT_FILENAME%/*}
wiki=${wiki%/scripts}
wiki=${wiki%/sh}
wiki=${wiki%/bin}
wiki_bin=${wiki}/bin
wiki_lib=${wiki}/lib
# computes URL of standard wiki scripts
wikiurl=${SCRIPT_NAME%/*}
wikiurl=${wikiurl%/scripts}

parse_webs () {
    echo "<html><head><title>$title $wikiname</title>"
    echo "<style type='text/css'>"
    if test -n "$WEBS"; then Webs="$WEBS,"
    else Webs=
      for i in [A-Z]*;do 
        if test -d "$i"; then
          if grep "^		[*] Set  *NOSEARCHALL  *=  *on" "$i/WebPreferences.txt">/dev/null
            then case "$PATH_INFO" in */all) :;;
              *) continue;; esac
          fi
          Webs="$Webs,$i"
        fi
      done
      Webs="$Webs,"
    fi
    for i in ${Webs//,/ }; do
      color=`grep "^		[*] Set  *WEBBGCOLOR  *= " "$i/WebPreferences.txt"`
      color="${color##*= }"
      echo "span.$i {background: $color;}"
    done
    echo "</style></head><body>"
    echo "<h2>$title <a href=$wikiurl>$wikiname</a></h2>$others"
}

parse_webs_koalaskin () {
    echo "<html><head><title>$title $wikiname</title>"
    echo "<style type='text/css'>"
    if test -n "$WEBS"; then Webs="$WEBS,"
    else Webs=
      for i in [A-Z]*;do 
	if test -d "$i"; then
          if grep "^		[*] Set  *NOSEARCHALL  *=  *on" "$i/WebPreferences.txt">/dev/null
            then case "$PATH_INFO" in */all) :;;
	      *) continue;; esac
          fi
          Webs="$Webs,$i"
        fi
      done
      Webs="$Webs,"
    fi
    cat ../templates/Main/style.koala.tmpl 
    echo "</style></head><body>"
    echo "<h2>$title <a href=$wikiurl>$wikiname</a></h2>$others"
}

parse_log_color () {
  IFS='|'
  echo "<table border=0><tr><th>Web<th>Topic<th>date<th>who"
  while read nope when who how what rest;do
    #echo "<br>nope=$nope, when=$when, who=$who, how=$how, what=$what, rest=$rest"
    what="${what## }";what="${what%% }"
    web=${what%.*}
    day="${when%-*}";day="${day##+( )}"
    case "$Webs" in *,$web,*) 
      topic=`echo ${what#*.} | tr ,+=- _` # take care of - in topics
      case "$topic" in
	[A-Z]*)
          let nchanges=nchanges+1
	  if let "$web$topic<1"; 
	  then let "$web$topic=2"
	    if test "$prevday" != "$day"; then
	      ndays=`days $day`
	      if let 'ndays>max'; then let nchanges=nchanges-1; break; fi
	      echo "<tr><td bgcolor=#dddddd>&nbsp;<td bgcolor=#dddddd>&nbsp;<td bgcolor=#dddddd><b>${day// /&nbsp;}</b><td bgcolor=#dddddd>&nbsp;"
	    fi
            echo "<tr><td>"
#	    echo "<span class='$web'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>"
# koalaskin
	    echo "<span class='bg1-${web}'>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</span>"
	    echo "<td><a href=$wikiurl/view/$web/$topic>$what</a><td> <i>${when#*-}</i> <td><a href=$wikiurl/view/Main/${who#*.}>${who#*.}</a>"
	    prevday="$day"
	    let ntopics=ntopics+1
	  fi;;
      esac;;
    esac
  done
  echo "</table><p>$nchanges changes in $ntopics topics during last $max days.</body></html>"
  cat >/dev/null #empty pipe
}

parse_webs_webcore () {
bgcolor="`grep '[*] Set WEBBGCOLOR =' TWiki/DefaultPreferences.txt|sed -e 's/.*=[ 	]*//' -e 's///g'`"
fgcolor="`grep '[*] Set WEBFGCOLOR =' TWiki/DefaultPreferences.txt|sed -e 's/.*=[ 	]*//' -e 's///g'`"
cat <<EOF
<html><head><title>$title $wikiname</title>
<link href="/webcore-layout/v2.0/templates/style/wikiinfo.css" rel="stylesheet" type="text/css" />
<style type='text/css'>
div.WCinfo {margin: 1em 0.5em 1em 0.5em; padding: 2em 2em 2em 2em; border: 1px solid #77858c; width: auto;}
table.WClastchanges {border-collapse: collapse; background-color: #DFE6EC;}
table.WClastchanges tr th {font-weight: bold;font-size: 105%;white-space: nowrap;}
table.WClastchanges tr td {font-size: 85%;}
table.WClastchanges tr.day {background-color: #7CA9D1; border-bottom-color: #4E8AC2; border-bottom-style: solid; border-bottom-width: 3px;}
table.WClastchanges td.day {background-color: #4E8AC2; color: FFFFFF;}
table.WClastchanges td.day {font-weight: bold;}
table.WClastchanges tr.odd {background-color: #F7F7F7;}
table.WClastchanges tr.even {background-color: #EBEBEB;}
table.WClastchanges td.web {text-align: right}
table.WClastchanges td.topic {font-weight: bold}
table.WClastchanges td.author {font-size: 80%}
EOF
    if test -n "$WEBS"; then Webs="$WEBS,"
    else Webs=
      for i in [A-Z]*;do 
        if test -d "$i"; then
          if grep "^		[*] Set  *NOSEARCHALL  *=  *on" "$i/WebPreferences.txt">/dev/null
            then case "$PATH_INFO" in */all) :;;
              *) continue;; esac
          fi
          Webs="$Webs,$i"
        fi
      done
      Webs="$Webs,"
    fi
    echo "</style></head><body>"
    echo "<div class=\"WCinfo\">"
    echo "<h2>$title <a href=$wikiurl>$wikiname</a></h2>$others"
}

parse_log_mono () {
  local rowclass difflabel rev
  IFS='|'
  echo "<table border=0 class=\"WClastchanges\"><tr><th>Web<th><th>Topic<th>Date (GMT)<th>Who<th>View"
  while read nope when who how what rest;do
    #echo "<br>nope=$nope, when=$when, who=$who, how=$how, what=$what, rest=$rest"
    what="${what## }";what="${what%% }"
    web=${what%.*}
    day="${when%-*}";day="${day##+( )}"
    case "$Webs" in *,$web,*) 
      topic=`echo ${what#*.} | tr ,+=- _` # take care of - in topics
      case "$topic" in
	[A-Z]*)
          let nchanges=nchanges+1
	  if let "$web$topic<1"; 
	  then let "$web$topic=2"
	    if test "$prevday" != "$day"; then
	      ndays=`days $day`
	      if let 'ndays>max'; then let changes=nchanges-1; break; fi
	      echo "<tr class=\"day\"><td>&nbsp;<td><td>&nbsp;<td class=\"day\">${day// /&nbsp;}<td>&nbsp;<td>"
	      rowclass=odd
	    fi
	    rev=`grep '^%META:TOPICINFO{author=.*}%' "$web/$topic.txt" 2>/dev/null`
	    rev="${rev##*version=\"}";rev="${rev%%\"*}";rev="${rev:-1.1}"
	    if [ "$rev" = 1.1 ]; then
	      difflabel=new
	    else difflabel="<a href='$wikiurl/rdiff/$web/$topic?curvers=$rev'>diffs</a>"
	    fi
            echo "<tr class=\"$rowclass\"><td class=\"web\"><a href='$wikiurl/view/$web/WebHome'>$web</a><td>.<td class=\"topic\"><a href='$wikiurl/view/$web/$topic'>${what#*.}</a><td class=\"time\">${when#*-}<td class=\"author\"><a href='$wikiurl/view/Main/${who#*.}'>${who#*.}</a><td class=\"view\">$difflabel"
	    prevday="$day"
	    if [ $rowclass = odd ]; then rowclass=even; else rowclass=odd; fi
	    let ntopics=ntopics+1
	  fi;;
      esac;;
    esac
  done
  echo "</table><p>$nchanges changes in $ntopics topics during last $max days.</p></div></body></html>"
  cat >/dev/null #empty pipe
}

parse_log=parse_log_color

tac_with_tail () {
    for tacfile in "$@";do tail -r "$tacfile";done
}

export secs_in_days=86400
export ndays_today=`date +%s`; let ndays_today=ndays_today/secs_in_days
days () { # $1=day $2=month (3 letters) $3=year
    local ndays
    ndays=`date -d "$1 $2 $3" +%s`; let ndays=ndays/secs_in_days
    let ndays=ndays_today-ndays
    echo $ndays
}

echo "Content-type: text/html"
echo "Expires: Monday, 1-Jan-99 01:01:01 GMT"
echo

#wikiprefs
cd $wiki/data

export max=7

export rev=`which tac`;if test ! -x "$rev";then rev="tac_with_tail"; fi

export WEBS=
PATH_INFO="${PATH_INFO//|/,}"
case "$PATH_INFO" in *,*) 
    WEBSL="${PATH_INFO#*,}";WEBS=",$WEBSL";PATH_INFO="${PATH_INFO%%,*}";; 
esac

case "$PATH_INFO" in /[0-9]*) max="${PATH_INFO#/}"; max="${max%%/*}";; esac

wikiname=`grep '^[ 	]*[*] Set WIKITOOLNAME =' TWiki/DefaultPreferences.txt | sed -e 's/[^=]*=[ 	]*//' -e 's/[ 	
]*$//'`
wikiname=${wikiname:-Wiki}

others="See changes in last "
if test -n "$WEBS"; then others="In webs ${WEBSL//,/, }:<br>$others";fi
comma=''
for n in 7 31 100 365 1000 10000; do
  if [ $max != $n ]; then
    others="$others$comma<a href='$SCRIPT_NAME/$n$WEBS'>$n<a>"
    comma=', '
  fi
done
others="$others days.<p>"
title="Changed topics in last $max days in"

if grep '^		[*]  *Set  *SKIN  *=  *koala' TWiki/DefaultPreferences.txt >/dev/null 2>&1; then
    if grep '^		[*]  *Set  *KSTHEME  *=  *webcore' TWiki/KoalaSkinWebList.txt >/dev/null 2>&1
    then parse_webs_webcore; parse_log=parse_log_mono 2>&1
    else parse_webs_koalaskin 2>&1
    fi
else
    parse_webs 2>&1
fi
OIFS="$IFS";prevday='';ntopics=0;ndays=0;nchanges=0
logs=`ls -1t log*.txt`

$rev $logs | grep ' | save | ' | $parse_log 2>/dev/null

