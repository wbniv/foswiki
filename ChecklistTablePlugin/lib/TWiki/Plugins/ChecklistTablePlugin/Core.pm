# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# TODO
#    + performance fix: no sort -> render direct (without collect)
#    + own icons
#    + JavaScript based moves/edits (maybe AJAX too)
#

package TWiki::Plugins::ChecklistTablePlugin::Core;

use strict;
## use warnings;

use vars qw( %defaults @flagOptions $defaultsInitialized  %options $cgi $STARTENCODE $ENDENCODE @unknownParams );

$STARTENCODE = '--CHECKLISTTABLEPLUGIN_ENCODED[ ';
$ENDENCODE = ' ]CHECKLISTTABLEPLUGIN_ENCODED--';


# =========================
sub handle {
	# my ($text,$topic,$web) = @_;
	
	_initDefaults() unless $defaultsInitialized;

	return if _handleActions(@_);

	_render(@_);
	
}
# =========================
sub _render {

	local(%options);
	local(@unknownParams);

	my $text ="";

	my $insidePRE = 0;
	my $foundTable = 0;
	my @table = ( );
	my $tablenum = -1;
	my $row = -1;
	foreach my $line (split /\r?\n/, "$_[0]\n<nop>\n") {
		$insidePRE = 1 if $line =~ /<(pre|verbatim)\b/i;
		$insidePRE = 0 if $line =~ /<\/(pre|verbatim)>/i; 

		if ($insidePRE) {
			$text .= "$line\n";
			next;
		}

		if ($line =~ s/%CHECKLISTTABLE({(.*)})?%/_initOptions($2,$_[1],$_[2])/eg) {
			@table = ();
			$foundTable = 1;
			$row = -1;
			$tablenum++;
			$options{'_EDITTABLE_'} = (defined $cgi->param('ettablenr')) && ($cgi->param('ettablenr') == $tablenum+1)
						 && (grep(/^et(save|qsave|addrow|delrow|edit)$/,$cgi->param()));
		} elsif ($foundTable) {
			if ($line =~ /^\s*\|[^\|]*\|/) {
				$row++;
				_collectTableData(\@table, $tablenum, $line, $row);
				$line = undef;
			}  else {
				
				$line = _renderTable( _sortTable($tablenum,\@table), $tablenum).$line;
				$foundTable = 0;
			}
		}

		$text.="$line\n" if defined $line;
	}

	$_[0] = $text;
	
}
# =========================
sub _collectTableData {
	my ($tableRef, $tablenum, $line, $row) = @_;

	my @data = split( /\|/, '--'.$line.'--');
	
	shift @data; pop @data;

	my %rowdata;

	$rowdata{'data'} = \@data;
	$rowdata{'row'} = $row;
	$rowdata{'line'} = $line;
	$rowdata{'header'} = $line =~ /\|\s*\*[^\*]*\*\s*\|/;

	push @{ $tableRef }, \%rowdata;
	
}

# =========================
sub _renderTable {
	my ($tableRef, $tablenum) = @_;
	my $text = "";

	$options{"_RowCount_$tablenum"}=$#$tableRef;

	_fixFormatAndHeaderOptions((defined $tableRef && $#$tableRef > -1 ?  $$tableRef[0] : undef));

	## anchor name (an):
	my $an = "CLTP_TABLE_$tablenum";

	$text.=$cgi->start_form('post',TWiki::Func::getScriptUrl($options{'theWeb'},$options{'theTopic'},'viewauth')."#$an");
	$text.=$cgi->a({-name=>$an});


	if (!defined $cgi->param("cltp_action_$tablenum") && !$options{'_EDITTABLE_'}) {
		if ($#$tableRef>-1) {
			$text.=_renderButtons('edittable',$tablenum);
			$text.=_renderButtons('first',$tablenum);
		} elsif (!$options{'quickadd'}) {
			$text.=_renderButtons('first',$tablenum);
		}

	}
	$text.=qq@%TABLE{sort="off"}%@; ##  if !$options{'headerislabel'}; ## generally switched off
	$text.="\n";
	$text.=_renderTableHeader($tablenum);

	my $firstRendered = 0;
	foreach my $tableEntry ( @{$tableRef} ) {
		my $row = "";

		if (defined $cgi->param("cltp_action_${tablenum}_first") && !$firstRendered && !$$tableEntry{'header'}) {
			$row .= _renderForm('insertfirst',$tablenum, undef, 0) if defined $cgi->param("cltp_action_${tablenum}_first");
			$firstRendered = 1;
		}

		if ($$tableEntry{'header'} && $options{'headerislabel'}) {
			$row.=_renderTableHeader($tablenum, $tableEntry);
		} elsif ($cgi->param("cltp_action_${tablenum}_editrow_$$tableEntry{'row'}")) {
			$row.=_renderForm('editrow', $tablenum, $tableEntry);
		} elsif ($cgi->param("cltp_action_${tablenum}_edittable")) {
			$row.=_renderForm('edittable.editrow', $tablenum, $tableEntry);
		} else {
			$row.=_renderTableData($tablenum, $tableEntry);
		}
		if (defined $cgi->param("cltp_action_${tablenum}_ins_$$tableEntry{'row'}")) {
			$row.=_renderForm('insertrow',$tablenum, undef, $$tableEntry{'row'});
		}
		$row=~s/%EDITCELL{(.*?)}%/_handleEditCell($tablenum,$1)/eg;
		$text.=$row;
	}
	$text.= _renderForm('addrow',$tablenum,undef,$#$tableRef + 1) if (!defined $cgi->param("cltp_action_$tablenum"))&&($options{'changerows'}!~/^(off|false|0|no)$/i)&&($options{'quickadd'});
	$text.= _renderButtons('edittable', $tablenum) unless defined $cgi->param("cltp_action_$tablenum") || $#$tableRef<0 || $options{'_EDITTABLE_'};
	$text.= _renderButtons('savetable', $tablenum) if defined $cgi->param("cltp_action_${tablenum}_edittable");

	### preserve table sort order of all checklist tables:
	foreach my $param (grep(/^cltp_\d+_sort/,$cgi->param())) {
		$text .= $cgi->hidden(-name=>$param,-value=>$cgi->param($param));
	}


	$text.=$cgi->end_form();

	### add a hidden form for a quick insert:
	if ($options{'quickinsert'}) {
		my $hiddenTable="";
		$hiddenTable.=$cgi->div({-style=>'text-align:left;background-color:gray;width:auto;'},
			$cgi->a({-style=>'color:yellow;',-title=>'Close Insert Window',-onClick=>"cltpCloseInputForm('CLTP_HIDDEN_$tablenum')"},'[x]')
			. $cgi->span({-style=>'color:white;'},"&nbsp;&nbsp;Insert a new entry (row)"));
		$hiddenTable.=$cgi->start_form('post',TWiki::Func::getScriptUrl($options{'theWeb'},$options{'theTopic'},'viewauth')."#$an");
		$hiddenTable.=_renderForm('hidden',$tablenum,undef,0);
		$hiddenTable.=$cgi->end_form();
		$text.=$cgi->div({-id=>"CLTP_HIDDEN_$tablenum",-style=>'visibility:hidden;position:absolute;top:0;left:0;z-index:2;font: normal 8pt sans-serif;padding: 3px; border: solid 3px gray;background-color:#ffffff;min-width:95%;overflow:scroll;'}, $hiddenTable);
	}

	$text.="\n";
	return $text;
}
# =========================
sub _handleEditCell {
	my ($tablenum, $attributes) = @_;
	$attributes=~s/^\s*\"//; $attributes=~s/\"\s*$//;
	my ($type,$param,$default) = split(/\s*,\s*/,$attributes,3);

	if ($type eq 'editbutton') {
		my ($text,$url) = split(/\s*,\s*/,$default);
		$url = $options{'edittableicon'} unless defined $url;
		$text='EDIT' if !defined $text || $text eq "" ;
		return $cgi->image_button(-name=>"cltp_action_${tablenum}_edittable", -value=>$text, -src=>$url);
	} 
	return "";
}
# =========================
sub _renderForm {
	my ($what, $tablenum, $entryRef, $row) = @_;

	my @formats = split(/\|/,$options{'format'});
	shift @formats; 

	$row = $options{"_RowCount_$tablenum"} unless defined $row; 
	$row = $$entryRef{'row'} if defined $entryRef;
	$row = 0 unless $row>-1;

	my $dataRef;
	
	$dataRef = $$entryRef{'data'} if defined $entryRef;

	my $text = '| ';
	for (my $c=0; $c<=$#formats; $c++) {
		my $valname = "cltp_val_${tablenum}_${row}_${c}";
		$valname = "cltp_val_ins_${tablenum}_${row}_${c}" if $what eq 'hidden';

		my $format = $formats[$c];
		$format = $defaults{'defaultcellformat'} if defined $entryRef && $$entryRef{'header'} && !$options{'headerislabel'};

		my $value;
		if (defined $dataRef) {
			$value = $$dataRef[$c]; 
			$value =~s/^\s//; $value=~s/\s$//;
			if ($value=~/%EDITCELL{(.*?)}%/) {
				my $param = $1;
				$param=~s/^\s*\"//; $param=~s/\"\s*$//;
				if ($param !~ /^editbutton/i) {
					$format = $param; 
				}
				$text.=$cgi->hidden(-name=>$valname."_f",-value=>$param);
			}
		}

		my ($type, $param, $default) = split(/\s?,\s?/,$format,3);

		$type=~s/^\s*//; $type=~s/\s*$//; ## remove whitespaces

		
		$value = $default unless defined $value;
		$value = "" unless defined $value;
		my $evalue = $STARTENCODE._editencode($value).$ENDENCODE;
		$value=~s/\%<nop>(\w+)/\%$1/g; ## _EDITTABLE_


		if ($type eq 'item') {
			$text .=  (defined $entryRef)? $value 
					: qq@%CLI{id="blubber.$tablenum.$row.$c" static="on"@
					  .($options{'name'} ne '_default'?qq@ name="$options{'name'}"@:"")
					  .(defined $options{'template'}?qq@ template="$options{'template'}"@:"")
					  .qq@}%@;
		} elsif ($type eq 'row') {
			$text .= $row + 1;
		} elsif ($type eq 'text') {
			$text .= $cgi->textfield(-name=>$valname, -value=>$evalue, -size=>$param);
		} elsif ($type eq 'textarea') {
			my ($rows,$cols) = split(/x/i,$param);
			$text .= $cgi->textarea(-name=>$valname, -value=> $evalue, -rows=>$rows, -columns=>$cols);
		} elsif ($type eq 'select') {
			my @selopts = split(/,/,$default);
			$text .= $STARTENCODE._editencode($cgi->popup_menu(-name=>$valname, -size=>$param, -values=>\@selopts, -default=>($default ne $value)?$value:"")).$ENDENCODE;
		} elsif ($type eq 'checkbox') {
			my @selopts = split(/,/,$default);
			my @values = split(/,\s?/,$value);
			$text .= $STARTENCODE._editencode($cgi->checkbox_group(-name=>$valname, -values=>\@selopts, -columns=>$param,-defaults=>(defined $entryRef)?\@values:$selopts[0])).$ENDENCODE;
		} elsif ($type eq 'radio') {
			my @selopts = split(/,/,$default);
			$value = $selopts[0] unless defined $value && $value ne "" && grep /^\Q$value\E$/,@selopts;
			$text .= $STARTENCODE._editencode(
				$cgi->radio_group(-name=>$valname, -columns=>$param, -values=>\@selopts, -default=>$value)
				).$ENDENCODE;
		} elsif ($type eq 'date') {
			my($initval,$dateformat);
			($initval,$dateformat) = split(/,/,$default,2) if defined $default;
			$initval=&TWiki::Func::expandCommonVariables( $initval, $options{'theTopic'},$options{'theWeb'}) if defined $initval && $initval!~/^\s*$/;
			$initval="" unless defined $initval;
			$dateformat=TWiki::Func::getPreferencesValue('JSCALENDARDATEFORMAT') if (!defined $dateformat || $dateformat eq "");
			$dateformat=~s/'/\\'/g if defined $dateformat;
			$evalue = $STARTENCODE._editencode($initval).$ENDENCODE unless defined $entryRef;
			$text .= $cgi->textfield(-name=>$valname, -value=>$evalue, -size=>$param, -id=>$valname);
			$text .= $cgi->image_button(-name=>'calendar', -src=>'%PUBURLPATH%/TWiki/JSCalendarContrib/img.gif', -alt=>'Calendar', -title=>'Calendar', -onClick=>qq@return showCalendar('$valname','$dateformat')@);
		} else { # label or unkown:
			$text.= $value.'<noautolink>'.$cgi->hidden(-name=>$valname, -value=>$value).'</noautolink>';
		}
		
		$text .=' | ';

	}
	if ($options{'buttonpos'} =~ /^(left|both)$/i) {
		$text = '| *&nbsp;'._renderButtons($what,$tablenum, $row,undef,'left').'&nbsp;* '.$text;
	} 
	if ($options{'buttonpos'} =~ /^(right|both)$/i) {
		$text .= '*&nbsp;'._renderButtons($what,$tablenum, $row,undef,'right').'&nbsp;* |';
	}
	return "$text\n";
}

# =========================
sub _fixFormatAndHeaderOptions {
	my ($entryRef) = @_;

	my @format = split(/\|/, $options{'format'});
	my @header = split(/\|/, $options{'header'});
	shift @format; 
	shift @header;

	my $columns = 0;
	if (defined $entryRef) {
		$columns = $#{$$entryRef{'data'}};
	} else {
		$columns = $#format;
	}


	if ($columns != $#format) {
		my $newformat ="";
		for (my $c=0; $c<=$columns; $c++) {

			if (defined $entryRef) {
				if ($$entryRef{'data'}[$c] =~ /^\s*\%CLI[^\%]*%\s*$/) {
					$newformat.='|item';
				} else {
					$newformat.='|'.$options{'defaultcellformat'};
				}
			} else {
				$newformat.='|'.$options{'defaultcellformat'};
			}

		}
		$newformat.="|";
		$options{'format'}=$newformat;
	}

	if ($options{'header'} ne 'off') {
		$options{'header'} = 'off' if $#header != $#format;

		$options{'header'} = 'off' if (defined $entryRef)&&($$entryRef{'header'});

		$options{'header'} = 'off' if $columns != $#header;
	}

	$options{'format'} =~ s/\%<nop>/\%/g;

}
# =========================
sub _renderTableHeader {
	my ($tablenum, $entryRef) = @_;


	my $header = "";

	if (defined $entryRef) {
		$header = $$entryRef{'line'};
	} elsif ($options{'header'} ne 'off') {
		return "" if ($options{'_EDITTABLE_'}); 
		$header = $options{'header'};
	} else {
		return "";
	}
	if ($options{'sort'} && !$options{'_EDITTABLE_'}) {
		my @cells = split(/\s*\|\s*/, $header);
		shift @cells;
		$header = "|";
		for (my $c=0; $c<=$#cells; $c++) {
			my $param = "cltp_${tablenum}_sort";
			my $cell = $cells[$c];
			$cell=~s/^\s*\*//;
			$cell=~s/\*\s*$//;
			my $dir = 'asc';
			$dir = 'desc' if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_asc/);
			$dir = "default" if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_desc/);

			my $sortmarker="";
			$sortmarker=$dir eq "desc" ? $cgi->span({-title=>'ascending order'},'^') :  $cgi->span({-title=>'descending order'},'v') 
						if (defined $cgi->param($param) && $cgi->param($param)=~/^${c}_(asc|desc)$/);
			my $ncgi=new CGI($cgi);
			$ncgi->param($param,"${c}_${dir}");
			$cell = $cgi->a({-href=>$ncgi->self_url()."#CLTP_TABLE_$tablenum", -title=>"sort table"}, $cell) . " $sortmarker";

			$header.="*$cell*|";
		}
	}
	my $text =$header;

	if (!$options{'_EDITTABLE_'}) {
		if ($options{'buttonpos'} =~ /^(left|both)$/i) {
			$text = '|*&nbsp;*'.$text
		} 
		if ($options{'buttonpos'} =~ /^(right|both)$/i) {
			$text .= '*&nbsp;*|';
		}
	}

	return "$text\n";
}
# =========================
sub _renderTableData {
	my ($tablenum, $entryRef) = @_;

	my $rowcount = $options{"_RowCount_$tablenum"};
	my $row = $$entryRef{'row'};


	my $text = "";

	if (!$options{'_EDITTABLE_'})  {
		$text .= $$entryRef{'line'};
		$text =~ s/\%<nop>(\w+)/\%$1/g; ## _EDITTABE_

		if ($options{'buttonpos'}=~/^(left|both)$/i) {
			my $ntext = '| *&nbsp;';
			$ntext .= _renderButtons('show', $tablenum, $row, $rowcount, 'left') unless defined $cgi->param("cltp_action_$tablenum");
			$ntext .= '&nbsp;*';
			$text = $ntext.$text;
		} 
		if ($options{'buttonpos'}=~/^(right|both)$/i) {
			$text .= '*&nbsp;';
			$text .= _renderButtons('show', $tablenum, $row, $rowcount, 'right') unless defined $cgi->param("cltp_action_$tablenum");
			$text .= '&nbsp;* |';
		}

		$text=~s/\%CLTP_ROWNUMBER\%/($row+1)/ge;
	} else { # _EDITTABLE_
		$text.='|';
		foreach my $cell (@{$$entryRef{'data'}}) {
			$cell =~s /\%(?!<nop>)(\w+)/\%<nop>$1/sg;
			$text.="$cell|";
			#$text.=_editencode($cell).'|';

		}
	}

	return "$text\n";
}
# =========================
sub _renderButtons {
	my ($what, $tablenum, $row, $rowcount, $pos) = @_;
	my $text = "";
	if ($what eq 'show') {
		sub _renderEditRowButton {
			my ($tablenum,$row) = @_;
			return $cgi->image_button(-name=>"cltp_action_${tablenum}_editrow_${row}", -title=>'Edit Entry', -value=>' E ', -src=>$options{'editrowicon'});
		}
		sub _renderInsertRowButton {
			my ($tablenum,$row,$rowcount) = @_;
			my $text ="";
			if ((!$options{'quickadd'}) || (($row < $rowcount)&&($options{'changerows'}!~/^(off|no|false|0)$/i))) {
				$text.=$cgi->img({-id=>"cltp_action_${tablenum}_ins_${row}",-name=>"cltp_action_${tablenum}_ins_${row}", -title=>'Insert Entry', -alt=>' + ',-src=>$options{'insertrowicon'}, 
						-onClick=>$options{'quickinsert'}?"cltpShowInsertForm('CLTP_HIDDEN_${tablenum}','cltp_action_${tablenum}_ins_${row}',0,15,1,$tablenum,$row);":""
						});
			} else {
				$text.=$cgi->image_button(-border=>0,-name=>"cltp_action_${tablenum}_cancel", -title=>'Insert Entry', -value=>'   ',-src=>$options{'dummyicon'}); 
			}
			return $text;
		};
		sub _renderMoveButtons {
			my ($tablenum, $row, $rowcount) = @_;
			my $text = "";
			if ($options{'allowmove'} && $options{'changerows'}!~/^(off|no|false|0)$/i) {
				if ($row > 0 ) {
					$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_up_".($row-1), -title=>'Move Entry Up', -value=>' ^ ',-src=>$options{'moverowupicon'}); 
				} else {
					$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_cancel", -title=>'Move Entry Up', -value=>'   ',-src=>$options{'dummyicon'}); 
				}
				if ($row < $rowcount) {
					$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_down_${row}", -title=>'Move Entry Down', -value=>' v ',-src=>$options{'moverowdownicon'});
					
				} else {
					$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_cancel", -title=>'Move Entry Down', -value=>'   ',-src=>$options{'dummyicon'});
				}
			}
			return $text;
		};
		sub _renderDeleteButton {
			my ($tablenum, $row) = @_;
			return $cgi->image_button(-name=>"cltp_action_${tablenum}_delrow_${row}", -title=>'Remove Entry', -value=>' - ',-src=>$options{'deleterowicon'}) 
					if ($options{'changerows'}!~/^(off|0|no|false|add)$/i);
			return "";
		}
		if (defined $pos) {
			if (! defined $options{"_CODE_${tablenum}_${pos}_"}) {
				$options{"_CODE_${tablenum}_${pos}_"} = <<'EOT'
					my $buttonpositions = $options{"buttonorder$pos"};
					for (my $i=0; $i<length($buttonpositions);$i++) {
						my $b=substr($buttonpositions,$i,1);
						$text.=_renderEditRowButton($tablenum, $row) if ($b eq 'E');
						$text.=_renderInsertRowButton($tablenum, $row, $rowcount) if ($b eq 'I');
						$text.=_renderMoveButtons($tablenum, $row, $rowcount) if ($b eq 'M');
						$text.=_renderDeleteButton($tablenum, $row, $rowcount) if ($b eq 'D');
					}
EOT
			}
			eval $options{"_CODE_${tablenum}_${pos}_"};
		} else {
			$text.=_renderEditRowButton($tablenum, $row);
			$text.=_renderInsertRowButtons($tablenum, $row, $rowcount);
			$text.=_renderMoveButtons($tablenum, $row, $rowcount);
			$text.=_renderDeleteButton($tablenum, $row, $rowcount);
		}
	} elsif ($what eq 'addrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_addrow_${row}", -value=>'Add');
	} elsif ($what eq 'insertrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_addrow_${row}", -value=>'Insert');
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>'Cancel');
	} elsif ($what eq 'editrow') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_saverow_${row}", -value=>'Save');
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_qsaverow_${row}", -value=>'Quiet Save') if $options{'quietsave'};
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>'Cancel');
	} elsif ($what eq 'first' && ($options{'changerows'} !~ /^(off|no|0|false)$/i)) {
		if ($options{'quickinsert'}) {
			$text.=$cgi->img({-id=>"cltp_action_${tablenum}_first",-name=>"cltp_action_${tablenum}_first", -title=>"Insert entry", -alt=>' + ',-src=>$options{'insertrowicon'},
				-onClick=>$options{'quickinsert'}?"cltpShowInsertForm('CLTP_HIDDEN_${tablenum}','cltp_action_${tablenum}_first',0,15,1,$tablenum,-1);":""
				}); 
		} else {
			$text.=$cgi->image_button(-id=>"cltp_action_${tablenum}_first",-name=>"cltp_action_${tablenum}_first", -title=>"Insert entry", -value=>' + ',-src=>$options{'insertrowicon'},
				-onMouseOver=>$options{'quickinsert'}?"cltpShowInsertForm('CLTP_HIDDEN_${tablenum}','cltp_action_${tablenum}_first',0,15,1,$tablenum,-1);":""
				); 
		}
	} elsif ($what eq 'insertfirst') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_insertfirst", -value=>"Insert");
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>"Cancel");
	} elsif ($what eq 'edittable') {
		$text.=$cgi->image_button(-name=>"cltp_action_${tablenum}_edittable", -title=>'Edit table', -value=>'EDIT', -src=>$options{'edittableicon'});
	} elsif ($what eq 'savetable') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_savetable", -value=>"Save");
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_qsavetable", -value=>"Quiet Save") if $options{'quietsave'};
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_cancel", -value=>"Cancel");
	} elsif ($what eq 'hidden') {
		$text.=$cgi->submit(-name=>"cltp_action_${tablenum}_addrow_${row}", -value=>"Insert");
		$text.=$cgi->button(-name=>"cltp_action_${tablenum}_cancel", -onClick=>"cltpCloseInputForm('CLTP_HIDDEN_$tablenum')", -value=>"Cancel");
		
	}
	return $text;
}
# =========================
sub _handleActions {
	my ($text,$theTopic,$theWeb) = @_;
	

	my @cltpactions = grep(/^cltp_action_\d+_(ins|first|edittable|editrow|addrow|delrow|up|down|cancel|saverow|qsaverow|savetable|qsavetable|insertfirst)(_\d+)?/, $cgi->param());
	return 0 if ($#cltpactions < 0);

	#### support for EDITTABLE tag before CHECKLISTTABLE
	$cgi->delete('etedit','ettablenr','etrows'); 

	#### Check access permissions (before any action...):
	my $mainWebName=&TWiki::Func::getMainWebname();
	my $user =TWiki::Func::getWikiName();
	$user = "$mainWebName.$user" unless $user =~ m/^$mainWebName\./;

	if (! TWiki::Func::checkAccessPermission("CHANGE",$user,undef,$theTopic, $theWeb)) {
		eval { require TWiki::AccessControlException; };
		if ($@) {
			TWiki::Func::redirectCgiQuery($cgi,TWiki::Func::getOopsUrl($theWeb,$theTopic,"oopsaccesschange"));
		} else {
			require Error;
			 throw TWiki::AccessControlException(
					'CHANGE', 
					$TWiki::Plugins::SESSION->{user},
					$theTopic, $theWeb, 'denied'
				);
		}
		return 1;
	}

	my( $oopsUrl, $lockUser ) = TWiki::Func::checkTopicEditLock( $theWeb, $theTopic );
	if (defined $lockUser && $lockUser ne "" && $lockUser ne TWiki::Func::wikiToUserName($user)) {
		TWiki::Func::redirectCgiQuery($cgi, $oopsUrl);
		return 1;
	}

	my $action = $cltpactions[0];
	$cgi->param($action,"1") if $action =~ s/\.(x|y)$//;

	$action =~ s/^cltp_action_(\d+)_([^_]+)(_(\d+))?.*$/$2/;
	my ($tablenum, $rownum) = ($1,$4);

	if ($action ne 'cancel') {
		$oopsUrl = TWiki::Func::setTopicEditLock($theWeb, $theTopic, 1);
		if ($oopsUrl) {
			TWiki::Func::redirectCgiQuery($cgi, $oopsUrl);
			return 1;
		}
	}

	$cgi->param("cltp_action_$tablenum","1");
	if ($action =~ /^(cancel|saverow|qsaverow|savetable|qsavetable|addrow|delrow|up|down|insertfirst)$/) {
		my $error;
		$error = _handleChangeAction($theTopic, $theWeb, $action, $tablenum, $rownum) unless $action eq 'cancel';

		TWiki::Func::setTopicEditLock($theWeb, $theTopic, 0);

		my $url = TWiki::Func::getViewUrl($theWeb,$theTopic);
		## preserve sort order:
		if (!$error) {
			my $anchor;
			$anchor = $1 if ($url=~s/(\#.*)$//);
			$url.="?";
			foreach my $param (grep(/^cltp_\d+_sort$/,$cgi->param())) {
				$url.="$param=".$cgi->param($param).";";
			}
			$url.=$anchor if defined $anchor;
		}
		TWiki::Func::redirectCgiQuery($cgi, $error ? $error : $url );
		return 1;
	}

	return 0; ### no actions (better: redirects) done
}

# =========================
sub _handleChangeAction {
	my ($theTopic, $theWeb, $action, $tablenum, $rownum) = @_;

	local(%options);

	return if $action eq 'cancel';
	my $newText = "";
	my $text = TWiki::Func::readTopicText($theWeb,$theTopic);

	$rownum=-2 unless defined $rownum;

	my $insidePRE = 0;
	my $tablefound = 0;
	my $table = -1;
	my $row = -1;

	my @topic =  split(/\r?\n/, $text."\n<nop>\n");
	my $linenumber = -1;
	my $firstInserted = 0;
	foreach my $line ( @topic ) {
		$linenumber++;
		$insidePRE = 1 if $line =~ /<(pre|verbatim)\b/i;
		$insidePRE = 0 if $line =~ /<\/(pre|verbatim)>/i; 

		if ($insidePRE) {
			$newText .= "$line\n";
			next;
		}

		if ($line =~ /\%CHECKLISTTABLE({(.*)})?\%/) {
			my $attributes = $2;
			$table++; $row=-1;
			$tablefound = ($tablenum == $table);
			$firstInserted = 0;
			_initOptions($attributes) if ($tablefound) ;
		} elsif ($tablefound) {
			$row++; 

			if ($line =~ /^\s*\|[^\|]*\|/) {
				my @data = split(/\|/, '--'.$line.'--');
				shift @data; pop @data;

				_fixFormatAndHeaderOptions(_getHashRef(\@data,$row,($data[0]=~/\*[^\*]*\*/))) if $row == 0;

				if (($line=~/\|\s*\*[^\*]*\*/)&&$options{'headerislabel'}) { # ignore header
					$newText .= "$line\n";
					next;
				}
				if (($action eq 'insertfirst')&&(!$firstInserted))  {
					$line = _createRowFromCgi('new',$tablenum, 0) ."\n$line";
					$firstInserted = 1;
				}
	

				if ($action eq 'savetable' || $action eq 'qsavetable') {
					$line = _createRowFromCgi('update', $tablenum, $row, \@data);
				} elsif ($row == $rownum) {
					if ($action eq 'saverow' || $action eq 'qsaverow') {
						$line = _createRowFromCgi('update', $tablenum, $row, \@data);
					} elsif ($action eq 'delrow') {
						$line = undef;
					} elsif ($action eq 'addrow') {
						$line = "$line\n"._createRowFromCgi('new',$tablenum, $row);
					} elsif ($action =~ /^(down|up)$/) {
						my $bline = $line;
						$line = $topic[$linenumber + 1];
						$topic[$linenumber + 1]  = $bline;
					}
				}
			
			} else {
				if (($row == $rownum)&&($action eq 'addrow')) {
					$line = _createRowFromCgi('new',$tablenum, $row)."\n$line";
				} elsif (!$firstInserted && ($action eq 'insertfirst')) {
					$line = _createRowFromCgi('new',$tablenum, $row)."\n$line";
					$firstInserted = 1;
				}
		
				$tablefound = 0;
			}
		}

		$newText.="$line\n" if defined $line;
	}
	$newText=~s/\n<nop>\n$//s;

	return TWiki::Func::saveTopicText($theWeb, $theTopic, $newText, 1, $action =~ /^(qsaverow|qsavetable)$/);
	
}
# =========================
sub _getHashRef {
	my ($dataRef, $row, $header) = @_;
	my %data;
	$data{'data'} = $dataRef;
	$data{'row'} = $row;
	$data{'header'} = $header;
	return \%data;
}
# =========================
# two actions: 'new' or 'update'
sub _createRowFromCgi {
	my($action,$tablenum, $row, $dataRef) = @_;
	my @formats = split(/\|/, $options{'format'});
	shift @formats; 
	
	my $text = '| ';
	for (my $c=0; $c<=$#formats; $c++) {
		my $paramname = "cltp_val_${tablenum}_${row}_$c";

		$paramname = "cltp_val_ins_${tablenum}_${row}_$c" unless defined $cgi->param($paramname);

		my $value;
		$value  = _encode(join(', ',$cgi->param($paramname))) if defined $cgi->param($paramname);

		my $format = $formats[$c];
		$format = $cgi->param($paramname.'_f') if (defined $cgi->param($paramname.'_f')); 
		my ($type,$attribute,$val) = split(/,/,$format);

		$value = $val unless defined $value;


		$cgi->delete($paramname);


		if ($action eq 'new') {
			if ($type eq 'item') {
				$value  = qq@%CLI{id="@.sprintf("%d-%03d-%03d",time(),$tablenum,$row).qq@"@;
				$value .= qq@ template="$options{'template'}"@ if defined $options{'template'};
				$value .= qq@ name="$options{'name'}"@ unless $options{'name'} eq '_default';
				$value .= qq@}%@;
			} elsif ($type eq 'row') {
				$value = '%CLTP_ROWNUMBER%';
			}
		} else {
			if (($type eq 'item')||($type eq 'row')) {
				$value = $$dataRef[$c];
				$value =~ s/^\s//; $value =~ s/\s$//;
			}
		}

		$text.="$value | ";
		
	}
	return $text;
}

# =========================
sub _initDefaults {
	%defaults = ( 
		'_DEFAULT' => undef,
		'unknownparamsmsg' => '%RED% %SYSTEMWEB%.ChecklistTablePlugin: Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see %SYSTEMWEB%.ChecklistTablePlugin topic for more details): %KNOWNPARAMSLIST%',
		'header' => '|*State*|*Item*|*Comment*|',
		'format' => '|item|text,30|textarea,3x30|',
		'name' => '_default',
		'template'=> undef,
		'defaultcellformat'=> 'textarea,3x20',
		'allowmove' => 0,
		##'edittableicon'=>'%PUBURLPATH%/%SYSTEMWEB%/EditTablePlugin/edittable.gif',
		'edittableicon'=>'%ICONURL{edittopic}%',
		'moverowupicon'=>'%ICONURL{up}%',
		'moverowdownicon'=>'%ICONURL{down}%',
		'insertrowicon'=>'%ICONURL{plus}%',
		'editrowicon'=>'%ICONURL{pencil}%',
		'deleterowicon'=>'%ICONURL{choice-no}%',
		'dummyicon'=>'%ICONURL{empty}%',
		'quietsave'=>1,
		'headerislabel'=>1,
		'sort'=>1,
		'changerows'=>1,
		'quickinsert'=>1,
		'quickadd'=>1,
		'buttonpos'=>'right',
		'buttonorderright'=>'EIMD', # Edit, Insert, Move (up/down), Delete
		'buttonorderleft' =>'DMIE', 
		'initsort'=>undef,
		'initdirection'=>undef,
	);
	@flagOptions = ('allowmove', 'quietsave', 'headerislabel', 'sort','quickadd','quickinsert');
	$cgi = TWiki::Func::getCgiQuery();
	$defaultsInitialized = 1;
}
# =========================
sub _initOptions {
	my ($attributes,$topic,$web) = @_;
	my %params = TWiki::Func::extractParameters($attributes);

	my @allOptions = keys %defaults;

	@unknownParams= ( );
	foreach my $option (keys %params) {
		push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
	}

	## _DEFAULT:
	$params{'name'} = $params{'_DEFAULT'} if defined $params{'_DEFAULT'} && ! defined $params{'name'};

	## all options:
	foreach my $option (@allOptions) {
		my $v = $params{$option};
		if (defined $v) {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$options{$option} = ($v!~/^(false|no|off|0|disable)$/i);
			} else {
				$options{$option} = $v;
			}
		} else {
			if (grep /^\Q$option\E$/, @flagOptions) {
				$v = ( TWiki::Func::getPreferencesFlag("\U${TWiki::Plugins::ChecklistTablePlugin::pluginName}_$option\E") || undef );
			} else {
				$v = TWiki::Func::getPreferencesValue("\U${TWiki::Plugins::ChecklistTablePlugin::pluginName}_$option\E"); 
			}
			$v = undef if (defined $v) && ($v eq "");
			$options{$option}= (defined $v?$v:$defaults{$option});
		}
	}

	$options{'theWeb'}=$web;
	$options{'theTopic'}=$topic;

	return $#unknownParams>-1?_createUnknownParamsMessage():"";

}
# =========================
sub _createUnknownParamsMessage {
	my $msg="";
	$msg = TWiki::Func::getPreferencesValue('UNKNOWNPARAMSMSG') || undef;
	$msg = $defaults{'unknownparamsmsg'} unless defined $msg;
	$msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
	my @params = sort grep {!/^(_DEFAULT|unknownparamsmsg)$/} keys %defaults;
	$msg =~ s/\%KNOWNPARAMSLIST\%/join(', ',@params)/eg;

	return $msg;
}
# =========================
sub _encode {
	my ($text) =@_;

	return $text unless defined $text;

	$text =~ s/\|/&#124;/g;
	$text =~ s/\r?\n/<br\/>/g;
	
	return $text;
}
# =========================
sub _editencode  {
	my ($text) = @_;
	
	#$text =~ s/\&/&amp;/g;
	$text =~ s/\|/&#124;/g;
	$text =~ s/\r?\n/<br\/>/g;
	$text =~ s/<br\s*\/?>/&#10;/g;	 ## prevent <br/> -> \r\n
	$text =~ s/\*/&#35;/g; ## prevent *..* -> <strong>...
	$text =~ s/_/&#95;/g; ## prevent _.._ -> <i>...
	$text =~ s/=/&#61;/g;
	$text =~ s/:/&#58;/g; ## -> http: 
	$text =~ s/\[/&#91;/g; ## -> [[ForcedLink]]
	$text =~ s/!/&#33;/g;
	$text =~ s/</&#60;/g;
	$text =~ s/>/&#62;/g;
	$text =~ s/ /&#32;/g; ## -> prevent WikiWord substitions
	
	$text =~ s/(\%)/'&#'.ord($1).';'/eg;

	return $text;
}
# =========================
sub _editdecode {
	my ($text) = @_;
	$text =~ s/&(amp;)?#124;/\|/g;
	$text =~ s/&(amp;)?#10;/\r\n/g;
	$text =~ s/&(amp;)?#35;/*/g;
	$text =~ s/&(amp;)?#95;/_/g;
	$text =~ s/&(amp;)?#61;/=/g;
	$text =~ s/&(amp;)?#58;/:/g;
	$text =~ s/&(amp;)?#91;/[/g;
	$text =~ s/&(amp;)?#33;/!/g;
	$text =~ s/&(amp;)?#60;/</g;
	$text =~ s/&(amp;)?#62;/>/g;
	$text =~ s/&(amp;)?#32;/ /g;

	$text =~ s/&amp;#(\d+);/&#$1;/g; ## fix encoded characters &amp;#....;
	return $text;
}
# =========================
sub handlePost {
	$_[0] =~ s/\Q$STARTENCODE\E(.*?)\Q$ENDENCODE\E/_editdecode($1)/esg;
}
# =========================
sub _sortTable {
	my ($tablenum, $tabledataRef) = @_;

	return $tabledataRef if !$options{'sort'} && !defined $options{'initsort'};
	my @newtabledata = @{$tabledataRef};

	my ($column, $dir) = (undef, undef);
	foreach my $param (grep /^cltp_\Q$tablenum\E_sort$/, $cgi->param()) {
		($column,$dir)=split(/\_/,$cgi->param($param));
	}

	if ((defined $options{'initsort'})&&(!defined $column)&&(!defined $dir)) {
		$dir='asc';
		$dir='desc' if defined $options{'initdirection'} && $options{'initdirection'}=~/^(down|desc)$/i;
		$column=$options{'initsort'};
		($column,$dir) = split(/\_/,$options{'initsort'}) if ($options{'initsort'}=~/^\d+_(asc|desc)/);
		$column=1 if $column !~ /^\d+$/;
		$column--; ## start with 1 but here we need 0
		$cgi->param('sort',1);
		$cgi->param("cltp_${tablenum}_sort","${column}_${dir}");
	}

	if (defined $column && defined $dir && $dir ne "default") {

		sub _mysort {
			my ($dir,$column) = @_;
			if ($$a{'header'}) {
				return -1;
			} elsif ($$b{'header'}) {
				return +1;
			}
			return uc($$a{'data'}[$column]) cmp uc($$b{'data'}[$column]) if $dir eq 'asc';
			return uc($$b{'data'}[$column]) cmp uc($$a{'data'}[$column]);
		};

		@newtabledata = sort { _mysort($dir,$column); }  @{$tabledataRef};
	}
	return \@newtabledata;
}


1;
