# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
#		 
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".	If not, see 
# <http://www.gnu.org/licenses/>.
#
########################################################################

sub &web2osis($$) {
  my $cf = shift;
  my $out_osis = shift;
  
  &Log("\n--- CONVERTING HTML TO OSIS\n-----------------------------------------------------\n\n");
  open(OUTF, ">:encoding(UTF-8)", $out_osis) || die "Could not open web2osis output file $out_osis\n";

  $ISVERSEKEY = ($MODDRV =~ /Text$/ || $MODDRV =~ /Com\d*$/);
  if ($ISVERSEKEY) {&getCanon($VERSESYS, \%mycanon, \%mybookorder);}

  # Read the command file, converting each book as it is encountered
  &removeRevisionFromCF($cf);
  open(COMF, "<:encoding(UTF-8)", $cf) || die "Could not open html2osis command file $cf\n";

  $ClassInstructions = "GENBOOK_CHAPTER_LEVEL_\\d+|CHAPTER_NUMBER|VERSE_NUMBER|BOLD|ITALIC|REMOVE|CROSSREF|CROSSREF_MARKER|FOOTNOTE|FOOTNOTE_MARKER|IGNORE|INTRO_PARAGRAPH|INTRO_TITLE_1|LIST_TITLE|LIST_ENTRY|TITLE_1|TITLE_2|CANONICAL_TITLE_1|CANONICAL_TITLE_2|BLANK_LINE|PARAGRAPH|POETRY_LINE_GROUP|POETRY_LINE|TABLE|TABLE_ROW|TABLE_CELL";
  $TagInstructions = "IGNORE_KEY_TAGS|IGNORE_KEY_TAG_ATTRIBUTES|IGNORE_KEY_TAG_ATTRIBUTE_VALUES";
  $TrueFalseInstructions = "DUPLICATE_CHAPTER_TITLES|UPPERCASE_CHAPTER_TITLES|ALLOW_OVERLAPPING_HTML_TAGS|ALLOW_REDUCED_TAG_CLASSES|GATHER_CLASS_INFO";
  $SetInstructions = "addScripRefLinks|addDictLinks|addCrossRefs";
  $SetTrueFalse = "addScripRefLinks|addDictLinks|addCrossRefs";

  $InlineTags = "(span|font|sup|a|b|i)";

  @GenBookHierarchy = ("majorSection", "chapter", "section", "subSection");

  $R = 0;
  $Filename = "";
  $Linenum	= 0;
  $line=0;
  while (<COMF>) {
    $line++;
    
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^($ClassInstructions):\s*(\((.*?)\))?\s*$/) {if ($2) {$ClassInstruction{$1} = $3;}}
    elsif ($_ =~ /^($TagInstructions):\s*((<[^>]*>)+)?\s*$/) {if ($2) {$TagInstruction{$1} = $2;}}
    elsif ($_ =~ /^($TrueFalseInstructions):\s*(true|false)?\s*$/) {if ($2) {$TrueFalseInstruction{$1} = ($2 eq "true" ? 1:0);}}
    elsif ($_ =~ /^OSISBOOK:\s*(.*?)\s*=\s*(.*?)\s*$/) {$OsisBook{$1} = $2;}
    elsif ($_ =~ /^SPAN_CLASS:.*?(\S+)=((<[^>]*>)+)\s*$/) {$SpanClassName{$2} = $1;}
    elsif ($_ =~ /^DIV_CLASS:.*?(\S+)=((<[^>]*>)+)\s*$/) {$DivClassName{$2} = $1;}
    elsif ($_ =~ /^SET_($SetInstructions):(\s*(\S+)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        $$par = $val;
        if ($par =~ /^($SetTrueFalse)$/) {
          $$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
        }
        &Log("INFO: Setting $par to $$par\n");
      }
    }
    elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
      my $htmlfile = $1;
      $htmlfile =~ s/\\/\//g;
      if ($htmlfile =~ /^\./) {
        chdir($INPD);
        $htmlfile = File::Spec->rel2abs($htmlfile);
        chdir($SCRD);
      }
      my $htmlfileName = $htmlfile;
      $htmlfileName =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
      if (!$ISVERSEKEY || (exists($OsisBook{$htmlfileName}) && exists($mycanon{$OsisBook{$htmlfileName}}))) {
        
        # process this book now...
        $TrueFalseInstruction{"GATHER_CLASS_INFO"} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} || !%SpanClassName && !%DivClassName);
        if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {&Log("INFO: Gathering class information. OUTPUT IS NOT OSIS!\n");}
        
        $Book = ($ISVERSEKEY ? $OsisBook{$htmlfileName}:$MOD);
        
        my $osisfile = &HTMLtoOSIStags($htmlfile);
        
        &handleNotes("crossref", \$osisfile);
        &handleNotes("footnote", \$osisfile);
        
        if ($DEBUG) {
          open(OUTTMP, ">>:encoding(UTF-8)", "$out_osis.osis") || die "Could not open web2osis output file $out_osis.osis\n";
          print OUTTMP $osisfile;
          close(OUTTMP);
        }
        
        &osis2SWORD(\$osisfile);
        
        # save output for sorting and writing later
        $OsisBookText{$Book} = $osisfile;
      }
      else {&Log("ERROR: SKIPPING \"$htmlfile\". Could not determine OSIS book.\n");}
    }
    else {&Log("ERROR: Unhandled entry \"$_\" in $cf\n");}
  }
  close(COMF);

  # print out the OSIS file in v11n correct book order
  if (!$TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
    
    my $osisRefWork = ($ISVERSEKEY ? "defaultReferenceScheme":"book");
    my $workTitle = ($ISVERSEKEY ? "$MOD Bible":"OSISGenbook");
    my $workIdentifier = ($ISVERSEKEY ? "<identifier type=\"OSIS\">Bible.$MOD</identifier>":"");
    
    &Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"$osisRefWork\" xml:lang=\"".$ConfEntryP->{"Lang"}."\"><header><work osisWork=\"$MOD\"><title>$workTitle</title>$workIdentifier<refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n");
    
    if ($ISVERSEKEY) {
      &Write("<div type=\"bookGroup\">\n");
      foreach my $bk (sort {$mybookorder{$a} <=> $mybookorder{$b}} keys %OsisBookText) {
        if ($wasWritingOT && $mybookorder{$bk} > 39) {&Write("</div>\n<div type=\"bookGroup\">\n");}
        &Write($OsisBookText{$bk});
        $wasWritingOT = ($mybookorder{$bk} <= 39);
      }
      &Write("</div>\n");
    }
    
    else {&Write($OsisBookText{$MOD});}
    
    &Write("</osisText>\n</osis>\n");
  }
  close (OUTF);

  # log a bunch of stuff now...
  &Log("\nLISTING OF SPAN CLASSES:\n");
  foreach my $classTags (sort keys %SpanClassName) {
    &Log(sprintf("SPAN_CLASS:%5i %3s=%s\n", $SpanClassCounts{$SpanClassName{$classTags}}, $SpanClassName{$classTags}, $classTags));
  }

  &Log("\nLISTING OF DIV CLASSES:\n");
  foreach my $classTags (sort keys %DivClassName) {
    &Log(sprintf("DIV_CLASS:%5i %3s=%s\n", $DivClassCounts{$DivClassName{$classTags}}, $DivClassName{$classTags}, $classTags));
  }

  if (!$TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
    &Log("\nLISTING OF REMOVED TEXT:\n");
    foreach my $t (sort {length($b) <=> length($a)} keys %AllRemoves) {
      &Log("$t (".$AllRemoves{$t}.")\n");
    }
    
    &Log("\nLISTING OF DROPPED TAGS:\n");
    foreach my $t (sort {length($b) <=> length($a)} keys %AllDroppedTags) {
      &Log("$t (".$AllDroppedTags{$t}.")\n");
    }
    
    &Log("\nLISTING OF UNUSED CLASSES:\n");
    foreach my $classTags (sort keys %SpanClassName) {
      if (!exists($UtilizedClasses{$SpanClassName{$classTags}})) {
        &Log(sprintf("SPAN_CLASS: %5s=%s\n", $SpanClassName{$classTags}, $classTags));
      }
    }
    foreach my $classTags (sort keys %DivClassName) {
      if (!exists($UtilizedClasses{$DivClassName{$classTags}})) {
        &Log(sprintf("DIV_CLASS: %5s=%s\n", $DivClassName{$classTags}, $classTags));
      }
    }
    
    &Log("\nLISTING OF OSIS TYPE X ATTRIBUTES IN OUTPUT:\n");
    foreach my $type (sort keys %XTypesInText) {
      &Log($type." ");
    }
    &Log("\n");
  }

  &Log("\nLISTING OF TAGS:\n");
  foreach my $t (sort keys %AllHTMLTags) {
    &Log($t." ");
  }
  &Log("\nlisting complete\n");
}

########################################################################
########################################################################

# All this really does is convert HTML tags into OSIS tags according to
# ClassInstructions, and reformats the markup with generally one tag per line. 
# It does not output SWORD compatible OSIS markup, and it uses xCHx 
# xVSSx, xVSx, xGENBOOKCHAPTERx placeholders for Bible verse and chapter, etc.
sub HTMLtoOSIStags() {
	my $file = shift;
	
	my $outText = "";
	
	$Filename = $file;
	$Filename =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
	$Linenum = 0;
	
	$CrossRefMarkerID = 0;
	$CrossRefID = 0;
	$FootnoteMarkerID = 0;
	$FootnoteID = 0;
	
	&Log("Processing $Book\n");
	&logProgress($Book);

	open(INP1, "<:encoding(UTF-8)", $file) or print getcwd." ERROR: Could not open file $file.\n";
	my $processing = 0;
	my $incomment = 0;
	my $multiLineTag = "";
	my $text = "";
	while(<INP1>) {
		$Linenum++;
		$_ =~ s/[\n\l\r]+$//;
		print "HTMLtoOSIStags line:$Linenum\n";	
		
		if ($text) {$text .= " ";} # a previous line feed in text requires a space
		
		# report and remove contitional tags
		while ($_ =~ s/(<\!\[[^>]*\]\s*>)//) {
			my $conditional = $1;
			if (!$Reported_Conditionals{$conditional}) {
				&Log("INFO: line $Linenum: Found conditional \"$conditional\". All will be removed.\n");
			}
			$Reported_Conditionals{$conditional}++;
		}
		
		# process body only and ignore all else
		if ($_ =~ /<body[^>]*>(.*)$/i) {
			$_ = $1;
			$processing = 1;
		}
		if (!$processing) {next;}
		if ($_ =~ /^(.*)<\/body[> ]/i) {
			$_ = $1;
			$processing = 0;
		}
		
		# ignore comments in body
		$_ =~ s/<!--.*?-->//g;
		if ($_ =~ s/<!--.*$//) {$incomment = 1;}
		elsif ($incomment && $_ !~ s/^.*?-->//) {next;}
		
PROCESS_TEXT:
		while($_) {
			if (!$multiLineTag && $_ =~ s/^([^<]+)(<|$)/$2/) {$text .= $1;}
			if ($_ =~ s/^(<[^>]*>)// || ($multiLineTag && $_ =~ s/^([^>]*>)//)) {
				my $tag = $1;
				if ($multiLineTag) {
					$tag = $multiLineTag." ".$tag;
					$multiLineTag = "";
				}
				
				if ($tag =~ /^<img/i) {next;} # TODO: strips out images for now...
		
				# process previously collected text, adding Osis tags around applicable text
				$outText .= &getOsisText(\$text);
				
				# process the new tag
				my $tagname = $tag;
				if ($tagname !~ s/^<(\/)?([\w:]+)\s*([^>]*?)>$/$2/) {
					&Log("ERROR: $file line $Linenum: failed to parse tag \"$tag\".\"\n");
				}
				my $isEndTag = ($1 ? 1:0);
				my $attribs = $3;
				
				# IGNORE_KEY_TAGS entries do not contribute to any tag's key, but are converted here straight to OSIS tags
				my @ignoreTags = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAGS"});
				foreach my $ignoreTag (@ignoreTags) {
					if (!$ignoreTag || $ignoreTag !~ /<([\w:]+)/) {next;}
					if (lc($1) eq lc($tagname)) {
						my $inlineTag;
						if (lc($tagname) eq "b") {$inlineTag= (!$isEndTag ? "<hi type=\"bold\">":"</hi>");}
						elsif (lc($tagname) eq "i") {$inlineTag= (!$isEndTag ? "<hi type=\"italic\">":"</hi>");}
						else {
							if (!exists($IgnoreTagErrorReported{$tagname})) {
								&Log("WARN: IGNORE_KEY_TAGS \"$tagname\" will be completely ignored.\n");
							}
							$IgnoreTagErrorReported{$tagname}++;
						}
						if ($inlineTag) {
							if (!$isEndTag) {$R++;} else {$R--;}
							$outText .= $inlineTag;
						}
						next PROCESS_TEXT;
					}
				}
				
				# get an OSIS tag, if any, and add this HTML tag to the current tagstack used for creation of tag classes
				$outText .= &getStackTag($tag);
			}
			elsif ($_ =~ s/^(<[^>]*)$//) {$multiLineTag = $1;}
			elsif ($multiLineTag && $_ =~ s/^([^<>]*)$//) {$multiLineTag .= " ".$1;}
		}
	}
	close(INP1);
	
	if ($text && $text !~ /^\s*$/) {&Log("ERROR: $file line $Linenum: unwritten text \"$text\"\n");}
	if ($tagstack{"level"}) {&Log("ERROR: $file line $Linenum: tag level not zero \"".$tagstack{"level"}."\"\n");}
	
	return $outText;
}

# Adds OSIS tags around input text IF current tag stack requires it.
sub getOsisText(\$) {
	my $textP = shift;
	if (length($$textP) == 0) {return;}
	
	my $outText = "";
	my $class = "";
	
	if (!$TagStack{"level"} && $$textP !~ /^\s*$/) {
		&Log("WARN: $Filename line $Linenum: Top level text \"$$textP\"\n");
	}
	else {
		# create a key by combining all current tags
		my $key = "";
		my @tkeys;
		my %count;
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			my $ktagval = $TagStack{"tag-key"}{$i};
			if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
				# include only inline tags in key
				if ($TagStack{"tag-name"}{$i} !~ /^$InlineTags$/i) {next;}
				# exclude empty and duplicate keys
				if ($ktagval eq "" || exists($count{$ktagval})) {next;}
				$count{$ktagval}++;
			}
			push(@tkeys, $ktagval);
		}
		
		if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
			# then tkeys are sorted, merged, and normalized
			my %tags;
			undef(%tags);
			foreach my $k (@tkeys) {
				if ($k !~ /^<([^\s\/\>]+)([^>]*)>$/) {&Log("ERROR: Bad sub-key \"".@tkeys[$i]."\"\n"); @tkeys[$i] = ""; next;}
				my $tag = lc($1);
				my $att = $2;
				my @atts = split(/([\w:]+="[^"]*")/, $att);
				foreach $att (@atts) {
					if ($att !~ /([\w:]+)="([^"]*)"/) {next;}
					my $a = $1;
					my $v = $2;
					$tags{$tag}{$a}{$v}++;
				}
			}
			
			foreach my $t (sort keys %tags) {
				my $tmpkey .= "<$t ";
				foreach my $a (sort keys %{$tags{$t}}) {
					my $allvals = "";
					foreach my $v (sort keys %{$tags{$t}{$a}}) {$allvals .= $v." ";}
					if ($a eq "style") {
						my %normRules;
						undef(%normRules);
						my @rules = split(/([^\:]+\:[^\;]+(\;|$))/, $allvals);
						foreach my $rule (@rules) {
							if ($rule eq "" || $rule =~ /^[\s\;]*$/) {next;}
							if ($rule !~ /([^\:]+)\:([^\;]+)(\;|$)/) {print "ERROR: Bad style rule \"$rule\" in $allvals\n"; next;}
							my $r = $1;
							my $s = $2;
							$r =~ s/^\s*(.*?)\s*$/$1/;
							$s =~ s/^\s*(.*?)\s*$/$1/;
							$normRules{$r} = $s;
						}
						# now reorder style rules
						$allvals = "";
						foreach my $s (sort keys %normRules) {$allvals .= "$s:".$normRules{$s}."; ";}
					}
					if ($allvals && $allvals !~ /^\s*$/) {
						$allvals =~ s/\s+/ /g;
						$allvals =~ s/\s*$//;
						$tmpkey .= "$a=\"$allvals\" ";
					}
				}
				$tmpkey .= ">";
				$tmpkey =~ s/\s*>/>/g;
				
				if ($tmpkey ne "<span>") {$key .= $tmpkey;} # ignore useless empty spans
			}
		}
		else {foreach my $tkey (@tkeys) {$key .= $tkey;}}

		if ($key ne "") {
			if (!exists($SpanClassName{$key})) {
				$ClassNumber++;
				$SpanClassName{$key} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} ? "s":"gs").$ClassNumber;
			}
			$SpanClassCounts{$SpanClassName{$key}}++;
			
			$class = $SpanClassName{$key};
		}
	}
	
	$outText = ($class ? &getOsisTag("span", $class, 0):"").$$textP.($class ? &getOsisTag("span", $class, 1):"");
	if ($R <= 0) {$outText .= "\n"; $R = 0;}
	
	$$textP = "";
	return $outText;
}

sub getStackTag($\%) {
	my $tag = shift;
	
	my $outText = "";
	
	# handle <br>
	if ($tag =~ /<br[\s>\/]+/i) {
		$outText .= "<lb\/>\n";
		$AllHTMLTags{"br"}++;
		return;
	}
	
	# handle <hr>
	if ($tag =~ /<hr[\s>\/]+/i) {
		$AllHTMLTags{"hr"}++;
		return;
	}
	
	# milestone tags
	if ($tag =~ /^<([\w:]+)[^>]+\/>$/) {
		my $mileStoneTag = $1;
		if (!$MileStoneTags{$mileStoneTag}) {&Log("INFO: line $Linenum: Found milestone tag \"<$mileStoneTag />\". All will be removed.\n");}
		$MileStoneTags{$mileStoneTag}++;
	}
	
	# start tags
	elsif ($tag !~ /^<\/([\w:]+)/) {
		$tag =~ /^<([\w:]+)\s*(.*)?\s*>$/;
		my $tagname = $1;
		my $atts = $2;
		
		$AllHTMLTags{$tagname}++;
		
		# Get this tag's attributes
		my $tagkey = "<".lc($tagname);
		my $tagvalue = $tagkey;
		if ($atts) {
			
			# parse all the tag attributes out
			my %attrib;
			if ($atts =~ /^(([\w:]+)(=("([^"]*)"|'([^']*)'|[\w\d\-]+))?\s*)+$/) {
				while ($atts) {
					if ($atts =~ s/^([\w:]+)=("([^"]*)"|'([^']*)'|([\w\d\-]+))\s*//) {
						$attrib{$1} = ($3 ? $3:($4 ? $4:$5));
					}
					$atts =~ s/^[\w:]+(\s+|$)//; # some HTML has empty attribs so just remove them
				}
			}
			else {&Log("ERROR: $Filename line $Linenum: bad tag attributes \"$atts\"\n");}
			
			# Ignore requested attributes and requested attribute values
			my @ignoreAttribs = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAG_ATTRIBUTES"});
			my @ignoreAttribVals = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAG_ATTRIBUTE_VALUES"});
			foreach my $a (sort keys %attrib) {
				if (lc($a) eq "style") {$attrib{$a} =~ s/[;\s]*$/;/;} # insure style rules all end with ";"
				
				# remove requested attribute values
				foreach my $ignoreAttribVals (@ignoreAttribVals) {
					if (!$ignoreAttribVals) {next;}
					if ($ignoreAttribVals !~ /^<([\w:\*]+)\s+([\w:\*]+)="([^"]+)"\s*>$/) {
						&Log("ERROR: Bad IGNORE_KEY_TAG_ATTRIBUTE_VALUES value \"$ignoreAttribVals\"\n");
						next;
					}
					my $it = $1;
					my $ia = $2;
					my $iv = $3;
					if (($ia eq "*" || lc($ia) eq lc($a)) && ($it eq "*" || lc($it) eq lc($tagname))) {
						$attrib{$a} =~ s/$iv//g;
					}
				}
				
				if ($attrib{$a} =~ /^\s*$/) {next;}
				
				my $skipme = 0;
				
				# skip listed tag/attribute pairs which are not relavent to key
				foreach my $ignoreAttrib (@ignoreAttribs) {
					if (!$ignoreAttrib) {next;}
					if ($ignoreAttrib !~ /^<([\w:\*]+)\s+([\w:\*]+)\s*>$/) {
						&Log("ERROR: Bad IGNORE_KEY_TAG_ATTRIBUTES value \"$ignoreAttrib\"\n");
						next;
					}
					my $it = $1;
					my $ia = $2;
					if (($ia eq "*" || lc($ia) eq lc($a)) && ($it eq "*" || lc($it) eq lc($tagname))) {
						$skipme = 1;
					}
				}
				
				if ($skipme) {next;}
				
				# save attribute to key
				$attrib{$a} =~ s/"/'/g;
				$attrib{$a} =~ s/\s+$//;
				$tagkey .= " ".lc($a)."=\"".$attrib{$a}."\"";
			}
		}
		$tagkey .= ">";
		$tagvalue .= ">";
		
		# write out all block tags now, but inline tags will be handled in getOsisText()
		if ($tagname !~ /^$InlineTags$/i) {
			if (!exists($DivClassName{$tagkey})) {
				$DivClassNumber++;
				$DivClassName{$tagkey} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} ? "d":"gd").$DivClassNumber;
			}
			$DivClassCounts{$DivClassName{$tagkey}}++;
			
			$outText .= &getOsisTag($tagname, $DivClassName{$tagkey}, 0);
			if ($R <= 0) {$outText .= "\n"; $R = 0;}
		}

		$TagStack{"level"}++;
		$TagStack{"tag-name"}{$TagStack{"level"}} = $tagname;
		$TagStack{"tag-key"}{$TagStack{"level"}} = $tagkey;
		$TagStack{"tag-value"}{$TagStack{"level"}} = $tagvalue;
	}
	
	#end tags
	else {
		my $tagname = $1;
		my $taglevel = $TagStack{"level"};
		
		$AllHTMLTags{$tagname}++;
		
		if ($tagname ne $TagStack{"tag-name"}{$TagStack{"level"}}) {
			if ($TrueFalseInstruction{"ALLOW_OVERLAPPING_HTML_TAGS"}) {
				for (my $i = $TagStack{"level"}; $i > 0; $i--) {
					if ($tagname eq $TagStack{"tag-name"}{$i}) {
						$taglevel = $i;
						last;
					}
				}
			}
			else {
				&Log("ERROR: $Filename line $Linenum: Bad tag stack \"$tag\" != \"".$TagStack{"tag-name"}{$TagStack{"level"}}."\"\n");
			}
		}
		
		# write out all block tags now, but inline tags will be handled in getOsisText()
		if ($tagname !~ /^$InlineTags$/i) {
			$outText .= &getOsisTag($tagname, $DivClassName{$TagStack{"tag-key"}{$taglevel}}, 1);
			if ($R <= 0) {$outText .= "\n"; $R = 0;}
		}
		
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			if ($i == $taglevel) {
				delete($TagStack{"tag-name"}{$i});
				delete($TagStack{"tag-key"}{$i});
				delete($TagStack{"tag-value"}{$i});
			}
			if ($i > $taglevel) {
				$TagStack{"tag-name"}{$i-1} = $TagStack{"tag-name"}{$i};
				$TagStack{"tag-key"}{$i-1} = $TagStack{"tag-key"}{$i};
				$TagStack{"tag-value"}{$i-1} = $TagStack{"tag-value"}{$i};
			}
		}
		$TagStack{"level"}--;
	}
	
	return $outText;
}

sub getOsisTag($$$) {
	my $htmltagname = lc(shift);
	my $class = shift;
	my $isEndTag = shift;
	
	my $t = "";
	if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
		$t .= "<";
		if ($isEndTag) {$t .= "/";}
		$t .= $htmltagname;
		if (!$isEndTag && $class ne "") {$t .= " type=\"x-$class\"";}
		$t .= ">";
	}
	else {
		if ($class eq "") {
			if (!exists($ReportDroppedTag{"$htmltagname-$class"})) {
				&Log("INFO: Began dropping \"$htmltagname\" tags with null class.\n");
			}
			$ReportDroppedTag{"$htmltagname-$class"}++;
			return "";
		}
		$UtilizedClasses{$class}++;

		$t .= &getOsisTagForElement(&getOsisElementForClass($class, $htmltagname), $isEndTag);
	}
	
	return $t;
}

sub getOsisElementForClass($$) {
	my $class = shift;
	my $htmltagname = shift;

	# convert the tag class to an OsisElement based on CF_html2osis.txt ClassInstructions
	my $myOsisElement = "";
	foreach my $elem (keys %ClassInstruction) {
		my $c = $ClassInstruction{$elem};
		if ($class =~ /^($c)$/) {
			if ($myOsisElement) {&Log("ERROR: Multiple OSIS elements assigned to class \"$class\" (\"$myOsisElement\" and \"$elem\").\n");}
			$myOsisElement = $elem;
		}
	}
	if (!$myOsisElement) {
		$myOsisElement = "PARAGRAPH-".$class;
		if ($htmltagname =~ /^$InlineTags$/i) {$myOsisElement = "SEG-".$class;}
		if (!exists($DefErrorReported{$class})) {
			&Log("INFO: ($Filename line $Linenum) No OSIS element assigned to class \"$class\" using default: \"$myOsisElement\" ($class=".&getTagsOfClass($class).").\n");
		}
		$DefErrorReported{$class}++;
	}
	
	return $myOsisElement;
}

sub getOsisTagForElement($$) {
	my $element = shift;
	my $isEndTag = shift;

	my $tagname = "";
	my $attribs = "";
	my $isMilestone = 0;

	if    ($element eq "VERSE_NUMBER") {$tagname = "verse";}
	elsif($element eq "CHAPTER_NUMBER") {$tagname = "chapter";}
	elsif($element =~ /^GENBOOK_CHAPTER_LEVEL_(\d+)$/) {$tagname = "div"; $attribs = "type=\"".@GenBookHierarchy[$1]."\" osisID=\"xGENBOOKCHAPTERx\"";}
	elsif($element eq "BOLD") {$tagname = "hi"; $attribs = "type=\"bold\"";}
	elsif($element eq "ITALIC") {$tagname = "hi"; $attribs = "type=\"italic\"";}
	elsif($element eq "REMOVE") {$tagname = "remove";}
	elsif($element eq "CROSSREF_MARKER") {$tagname = "OC_crossrefMarker"; if (!$isEndTag) {$attribs = "id=\"".++$CrossRefMarkerID."\"";}}
	elsif($element eq "CROSSREF") {$tagname = "OC_crossref"; if (!$isEndTag) {$attribs = "id=\"".++$CrossRefID."\"";}}
	elsif($element eq "FOOTNOTE_MARKER") {$tagname = "OC_footnoteMarker"; if (!$isEndTag) {$attribs = "id=\"".++$FootnoteMarkerID."\"";}}
	elsif($element eq "FOOTNOTE") {$tagname = "OC_footnote"; if (!$isEndTag) {$attribs = "id=\"".++$FootnoteID."\"";}}
	elsif($element eq "IGNORE") {return "";}
	elsif($element eq "INTRO_PARAGRAPH") {$tagname = "p"; $attribs = "type=\"x-indented\" subType=\"x-introduction\"";}
	elsif($element eq "INTRO_TITLE_1") {$tagname = "title"; $attribs = "level=\"1\" subType=\"x-introduction\"";}
	elsif($element eq "LIST_TITLE") {$tagname = "list"; $attribs = "type=\"x-list-1\"";}
	elsif($element eq "LIST_ENTRY") {$tagname = "item";}
	elsif($element eq "TITLE_1") {$tagname = "title"; $attribs = "level=\"1\"";}
	elsif($element eq "TITLE_2") {$tagname = "title"; $attribs = "level=\"2\"";}
	elsif($element eq "CANONICAL_TITLE_1") {$tagname = "title"; $attribs = "level=\"1\" canonical=\"true\"";}
	elsif($element eq "CANONICAL_TITLE_2") {$tagname = "title"; $attribs = "level=\"2\" canonical=\"true\"";}
	elsif($element eq "BLANK_LINE") {$isMilestone = 1; $tagname = ($isEndTag ? "lb/><lb":"skip");}
	elsif($element eq "PARAGRAPH") {$tagname = "p"; $attribs = "type=\"x-indented\"";}
	elsif($element =~ /^PARAGRAPH\-(.*?)$/) {$tagname = "p"; $attribs = "type=\"x-$1\"";}
	elsif($element eq "POETRY_LINE_GROUP") {$tagname = "lg";}
	elsif($element eq "POETRY_LINE") {$tagname = "l"; $attribs = "type=\"x-indent\"";}
	elsif($element =~ /^SEG\-(.*?)$/) {$tagname = "seg"; $attribs="type=\"x-$1\"";}
	elsif($element eq "TABLE") {$tagname = "table";}
	elsif($element eq "TABLE_ROW") {$tagname = "row";}
	elsif($element eq "TABLE_CELL") {$tagname = "cell";}
	
	if ($tagname eq "") {&Log("ERROR: No entry for OSIS element \"$element\"\n");}
	
	# all these will always end up on a single line
	my $oneLine = "GENBOOK_CHAPTER_LEVEL_\\d+|FOOTNOTE|CROSSREF|VERSE_NUMBER|CHAPTER_NUMBER|REMOVE|INTRO_TITLE_1|LIST_TITLE|LIST_ENTRY|TITLE_1|TITLE_2|CANONICAL_TITLE_1|CANONICAL_TITLE_2|BLANK_LINE|POETRY_LINE_GROUP|POETRY_LINE";
	if (!$isMilestone && !$isEndTag && ($element =~ /^($oneLine)$/)) {$R++;}
	if (!$isMilestone && $isEndTag  && ($element =~ /^($oneLine)$/)) {$R--;}

	if ($tagname eq "skip") {return "";}
	
	my $ret = "<";
	if (!$isMilestone && $isEndTag) {$ret .= "/";}
	$ret .= $tagname;
	if (!$isEndTag && $attribs) {$ret .= " ".$attribs;}
	if ($isMilestone) {$ret .= "/";}
	$ret .= ">";
	
	return $ret;
}

sub handleNotes($\$) {
	my $type = shift;
	my $tP = shift;
#<OC_footnoteMarker id="237">[95]</OC_footnoteMarker>	
	# find and convert each note body
	while ($$tP =~ s/(<OC_$type id="([^"]*)">(.*?)<\/OC_$type>)//) {
		my $bodyIndex = $-[1];
		my $id = $2;
		my $body = $3;
		
		# fix any verse numbers in note body
		$body =~ s/\s*<verse[^>]*>(.*?)<\/verse>\s*/ ($1) /g;
		
		# remove note marker if it exists in body (in addition to the text)
		my $typeMarker = $type."Marker";
		$body =~ s/<OC_$typeMarker[^>]*>.*?<\/OC_$typeMarker>//;
		
		my $note = "<note".($type eq "crossref" ? " type=\"crossReference\"":" type=\"study\"");
		$note .= " osisRef=\"$Book.xCHx.xVSx\"";
		$note .= " osisID=\"$Book.xCHx.xVSSx!".($type eq "crossref" ? "crossReference.n":"")."$id\"";
		$note .= " n=\"$id\"";
		$note .=">$body</note>";
		
		# place the note now
		if (exists($ClassInstruction{($type eq "crossref" ? "CROSSREF_MARKER":"FOOTNOTE_MARKER")})) {
			if ($$tP !~ s/(<OC_$typeMarker id="$id">.*?<\/OC_$typeMarker>)/$note/) {
				&Log("ERROR: Could not find marker for $type \"$id\".\n");
			}
		}
		else {substr($$tP, $bodyIndex, 0) = $note;}
	}
	
	if ($$tP =~ /<OC_$type/) {&Log("ERROR: Unhandled note type $type \"$id\".\n");}
}

# Converts the formatted output of HTMLtoOSIStags() into a form of OSIS 
# which can be read directly by SWORD's osis2mod program.
sub osis2SWORD(\$) {
	my $textP = shift;
	
	# read the entire book into an array so current, previous and next 
	# lines can all be known simultaneously.
	my @lines = split(/^/, $$textP);

	my $chapter = 0;
	my $verseF = 0;
	my $verseL = 0;

	my $verseEnd = "";
	my $sectionEnd = "";
	my $chapterEnd = "";
	
	my $lastGenBookChapterType = "";
	my %chapGenBookSiblings;

	for (my $l = 0; $l < @lines; $l++) {
		print "osis2SWORD line:$l\n";	
		
		local $_ = $lines[$l];
		$_ =~ s/[\n\l\r]+$//;
		
		# remove white-space from the beginning of all paragraphs to normalize how paragraphs begin
		if ($_ =~ /^(<p>|<p [^>]*>)$/) { # all <p> tags are alone on a line
			my $fl = ($l+1);
			while ($fl < @lines) {
				$lines[$fl] =~ s/^(<hi[^>]*>)(&nbsp;| )*+([^<]*<\/hi>)/$1$3/; # strip leading space from any leading <hi> tag
				if ($lines[$fl] !~ s/^(<hi[^>]*>(&nbsp;| )*<\/hi>|&nbsp;| )+//) {last;} # strip leading white space and empty start tags
				if ($lines[$fl] !~ /^\s*$/) {last;} # if line still has non-white space we know we're done
				$fl++;
			}
		}

		# handle all GenBook chapters
		if ($_ =~ /^(.*?)(<div type=\"([^"]+)\" osisID="xGENBOOKCHAPTERx">)(.*?)<\/div>(.*?)$/) {
			my $cp = $1;
			my $ctag = $2;
			my $ctyp = $3;
			my $ch = $4;
			my $cx = $5;
			
			# get our genbook chapter title
			$ch =~ s/<[^>]*>/ /g; # remove tags
			$ch =~ s/&nbsp;/ /g; # entities will become literals!
			$ch =~ s/\s+/ /g;
			$ch =~ s/(^\s+|\s+$)//g; # trim start & end
			if ($TrueFalseInstruction{"UPPERCASE_CHAPTER_TITLES"}) {$ch = &uc2($ch);}
			my $chReadable = $ch;
			$ch =~ s/_+/_/g;
			$ch =~ s/\s+/ /g;
			$ch =~ s/(^\s+|\s+$)//g; # trim start & end
			if ($ch =~ /^\s*$/) {&Log("WARN: Skipping GenBook chapter with empty key name.\n"); $_ = "";} # ignore GenBook chapters with blank key value
			if ($_) {
				if ($ctyp eq $lastGenBookChapterType) {
					if ($chapGenBookSiblings{$ch}) {
						$ch .= "_32__40_".$chapGenBookSiblings{$chReadable}."_41_";
						&Log("WARN: Modified repeated key of the following sibling chapter:\n");
					}
				}
				else {undef(%chapGenBookSiblings);}
				$chapGenBookSiblings{$chReadable}++;
				$lastGenBookChapterType = $ctyp;
				
				$ctag =~ s/xGENBOOKCHAPTERx/$ch/;
				&Log("INFO: type $ctyp \"$ctag\"\n");
				
				if ($cp ne "" || $cx ne "") {$AllDroppedTags{"chapter:$cp$cx"}++;}
				
				# keep hierarchy of divs clean and close all previous containers
				$_ = $verseEnd.$sectionEnd.$chapterEnd;
				if (%genBookChapterEnd) {
					for (my $h=@GenBookHierarchy; $h>=0; $h--) {
						$_ .= $genBookChapterEnd{@GenBookHierarchy[$h]};
						$genBookChapterEnd{@GenBookHierarchy[$h]} = "";
						if (@GenBookHierarchy[$h] eq $ctyp) {last;}
					}
				}
				
				$_ .= $ctag."\n";
				
				if ($TrueFalseInstruction{"DUPLICATE_CHAPTER_TITLES"}) {
					$_ .= "<title level=\"2\">$chReadable</title>\n";
				}
				
				$verseEnd = "";
				$sectionEnd = "";
				$chapterEnd = "";
				$genBookChapterEnd{$ctyp} = "</div>\n";
			}
		}
		
		# handle all Bible chapters
		elsif ($_ =~ /^(.*?)<chapter>(.*?)<\/chapter>(.*?)$/) {
			my $cp = $1;
			my $ch = $2;
			my $cx = $3;
			
			$verseF = 0;
			$verseL = 0;
			
			$chapter++;
			
			if ($ch =~ /^\s*(\d+)\s*$/) {
				if ($1 != $chapter) {
					&Log("ERROR: Chapter is not sequential (was $1, should be $chapter).\n");
					$chapter = $1;
				}
			}
			else {&Log("ERROR: Could not parse chapter \"$ch\".\n");}
			
			if ($cp ne "" || $cx ne "") {$AllDroppedTags{"chapter:$cp$cx"}++;}
			
			$_ = $verseEnd.$sectionEnd.$chapterEnd;
			$_ .= "<chapter osisID=\"$Book.$chapter\" n=\"$chapter\">\n";
			
			$verseEnd = "";
			$sectionEnd = "";
			$chapterEnd = "</chapter>\n";
		}
		
		# handle all titles
		elsif ($_ =~ /^(.*?)(<title [^>]*>)(.*)(<\/title>)(.*?)$/) {
			my $tp = $1; my $ts = $2; my $t = $3; my $te = $4; my $tx = $5;
			my $drop = "$tp$tx";
			if ($t !~ /<note /) {while ($t =~ s/(<[^>]*>)//) {$drop .= $1;}}
			if ($drop ne "") {$AllDroppedTags{"title:$drop"}++;}
			
			$_ = $sectionEnd;
			if ($chapter) {$_ .= "<div type=\"section\">\n";}
			$_ .= $ts.$t.$te."\n"; # leaving off $tp and $tx strips off illegal inline hi elements etc from titles.

			$sectionEnd = ($chapter ? "</div>\n":"");
		}
		
		# handle all verses
		elsif ($_ =~ /^(.*?)<verse>(.*?)<\/verse>(.*?)$/) {
			my $vp = $1;
			my $vs = $2;
			my $vx = $3;
			
			my @myv = &readVerseNumbers($_);
			
			$verseF = (++$verseL);
			$verseL = $myv[2];
			if ($verseL < $verseF) {$verseL = $verseF;}

			if ($verseF != $myv[1]) {
				&Log("WARN: Corrected starting verse: $chapter:".$myv[1]." became $chapter:$verseF\n");
			}
			if ($verseL != $myv[2]) {
				&Log("WARN: Corrected ending   verse: $chapter:$verseF".($myv[2] ne $verseF ? "-".$myv[2]:"")." became $chapter:$verseF-$verseL\n");
			}
			
			my $nl = $l;
			my @nextv = &readVerseNumbers($lines[++$nl]);
			while ($nextv[3] == 0 && $nl < @lines) {@nextv = &readVerseNumbers($lines[++$nl]);}
			if ($nextv[3] == 1 && ($nextv[1]-1) > $verseL) {
				&Log("WARN: Corrected ending   verse, $chapter:$verseF".($verseL ne $verseF ? "-".$verseL:"")." became $verseF-".($nextv[1]-1)."\n");
				$verseL = ($nextv[1]-1);
			}
			# if this is the last verse in the chapter, check against verse system for correctness
			elsif ($nextv[3] == -1 || $nl == @lines) {
				my $trueVerseL = $mycanon{$Book}[($chapter-1)];
				if ($verseL > $trueVerseL && $verseF <= $trueVerseL) {
					&Log("WARN: Corrected    final verse (too many), $chapter:$verseF".($verseL ne $verseF ? "-".$verseL:"")." became $verseF".($trueVerseL ne $verseF ? "-".$trueVerseL:"")."\n");
					$verseL = $trueVerseL;
				}
				elsif ($verseL < $trueVerseL) {
					&Log("WARN: Corrected    final verse (too few), $chapter:$verseF".($verseL ne $verseF ? "-".$verseL:"")." became $verseF".($trueVerseL ne $verseF ? "-".$trueVerseL:"")."\n");
					$verseL = $trueVerseL;
				}
			}
			
			my $osisID = &getOsisID($Book, $chapter, $verseF, $verseL);
			my $verseTextL = ($verseL > $verseF ? "-".$verseL:"");
			
			if ($vp ne "" || $vx ne "") {$AllDroppedTags{"verse:$vp$vx"}++;}
			
			$_ = $verseEnd;
			$_ .= "<verse sID=\"$Book.$chapter.$verseF$verseTextL\" osisID=\"$osisID\" n=\"$verseF$verseTextL\" />";
			
			$verseEnd = "<verse eID=\"$Book.$chapter.$verseF$verseTextL\" />\n";
		}
		
		# correct some places where a verse tag is required but instead we've got some other tag (AZE rtf)
		elsif ($ISVERSEKEY && $_ !~ /^<(p|div)[ >]/ && $_ !~ /^\s*$/ && $chapter && !$verseEnd) {
			if ($verseF == 0) {
				$verseF = (++$verseL);
				my $nl = $l;
				my @nextv = &readVerseNumbers($lines[++$nl]);
				while ($nextv[3] == 0 && $nl < @lines) {@nextv = &readVerseNumbers($lines[++$nl]);}
				if ($nextv[3] == 1 && ($nextv[1]-1) > $verseL) {$verseL = ($nextv[1]-1);}
				
				my $osisID = &getOsisID($Book, $chapter, $verseF, $verseL);
				my $verseTextL = ($verseL > $verseF ? "-".$verseL:"");
				
				&Log("WARN: Corrected missing  verse: $chapter:$verseF".($verseL ne $verseF ? "-".$verseL:"")."\n");
				
				$_ = $verseEnd."<verse sID=\"$Book.$chapter.$verseF$verseTextL\" osisID=\"$osisID\" n=\"$verseF$verseTextL\" />".$_;
				$verseEnd = "<verse eID=\"$Book.$chapter.$verseF$verseTextL\" />\n";
			}
			else {&Log("WARN: Cannot handle this outside a verse: \"$_\"\n");}
		}
		
		while ($_ =~ s/<remove>(.*?)<\/remove>/$1/) {$AllRemoves{$1}++;}
		
		# insure lists work right
		if    ($_ =~ /<list[\s>]/) {$InList = 1;}
		elsif ($_ =~ /<\/list[\s>]/) {$InList = 0;}
		elsif ($_ =~ /<item[\s>]/ && !$InList) {$_ =~ s/(<item[\s>])/<list>$1/; $InList = 1;}
		elsif ($_ !~ /<item[\s>]/ && $InList) {$_ = "</list>".$_; $InList = 0;}
		
		# replace place holders with correct values
		$_ =~ s/xCHx/$chapter/g;
		$_ =~ s/xVSSx/$verseF/g;
		$_ =~ s/xVSx/$verseF$verseTextL/g;
		
		# final output checking
		my $check = $_;
		while ($check =~ s/<([^\s>]+)[^>]*?type="(x\-[^"]*)"//) {
			$XTypesInText{$1."(".$2.")"}++;
			if (!exists($ReportXType{$1."(".$2.")"})) {
				&Log("INFO: First $1($2) found in $Book.$Chapter.$Verse\n");
			}
			$ReportXType{$1."(".$2.")"}++;
		}
		
		# format the OSIS for easier readability
		$_ =~ s/(<\/p>)/$1\n/g;
		
		$lines[$l] = $_;
	}
	
	my $t = join("", @lines);
	$t =~ s/[ \t]+/ /g;
	
	my $wosisID = $Book;
	$$textP = "<div type=\"book\" osisID=\"$wosisID\"";
	if ($ISVERSEKEY) {$$textP .= " canonical=\"true\"";}
	$$textP .= ">\n";
	$$textP .= $t; 
	$$textP .= $verseEnd.$sectionEnd.$chapterEnd;
	if (%genBookChapterEnd) {
		for (my $h=@GenBookHierarchy; $h>=0; $h--) {
			$$textP .= $genBookChapterEnd{@GenBookHierarchy[$h]};
		}
	}
	$$textP .= "</div>\n";
}

sub getOsisID() {
	my $osisID = $_[0].".".$_[1].".".$_[2];
	for (my $i=$_[2]+1; $i<=$_[3]; $i++) {
		$osisID .= " ".$_[0].".".$_[1].".".$i;
	}
	
	return $osisID;
}

sub readVerseNumbers($) {
	my $l = shift;
	
	my @v = ("", 0, 0, 0);
	if ($l =~ /<verse>(.*?)<\/verse>/) {
		$v[0] = $1;
		
		$v[3] = 1;
		
		$v[0] =~ s/&nbsp;/ /g;
		if ($v[0] =~ /^\s*(\d+)([\-\s]+(\d+))?\s*$/) {$v[1] = $1; $v[2] = ($2 ? $3:$v[1]);}
		elsif ($v[0] =~ /^\s*(\d+).*?(\d+)\s*$/) {$v[1] = $1; $v[2] = $2;}
		else {&Log("ERROR: Could not parse verse \"".$v[0]."\".\n");}
	}
	elsif ($l =~ /<chapter[ >]/) {$v[3] = -1;} # allows any external loop to stop at next chapter (</chapter> does not work because it is not yet in the text)
	
	return @v;
}

sub getTagsOfClass($) {
	my $class = shift;
	foreach my $classTag (keys %SpanClassName) {if ($SpanClassName{$classTag} eq $class) {return $classTag;}}
	foreach my $classTag (keys %DivClassName) {if ($DivClassName{$classTag} eq $class) {return $classTag;}}
	&Log("ERROR: Unknown class tags for \"$class\".\n");
	return "";
}
	
sub Write($) {
	my $print = shift;
	print OUTF $print;
}

1;
