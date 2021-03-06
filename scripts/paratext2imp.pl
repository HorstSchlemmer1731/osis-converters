# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.
#
########################################################################

# IMPORTANT NOTES ABOUT SFM & COMMAND FILES:
#  -SFM files must be UTF-8 encoded.
#
#  -The CF_paratext2imp.txt command file is executed from top to
#   bottom. All settings remain in effect until/unless changed (so
#   settings may be set more than once). All SFM files are processed 
#   and added to the IMP file in the order in which they appear in 
#   the command file. Books are processed using all settings previously 
#   set in the command file.
#

# TERMINOLOGY:
#   A "tag-list" is a Perl regular expression consisting of SFM tag 
#   names separated by the perl OR ("|") term. Order should be longest
#   tags to shortest. The "\" before the tag is implied. 
#   For example: (toc1|toc2|toc3|ide|rem|id|w\*|h|w)

# COMMAND FILE INSTRUCTIONS/SETTINGS:
#   RUN - Process the SFM file now and add it to the IMP file. 
#       Only one SFM file per RUN command is allowed.
#   SET_script - Include script during processing (true|false|<option>)
#   PUNC_AS_LETTER - List special characters which should be treated as 
#       letters for purposes of matching word boundaries. 
#       Example for : "PUNC_AS_LETTER:'`" 
#   SPECIAL_CAPITALS - Some languages (ie. Turkish) use non-standard 
#       capitalization. Example: SPECIAL_CAPITALS:i->İ ı->I

# COMMAND FILE FORMATTING RELATED SETTINGS:
#   START_WITH_NEWLINE - If true, entry text begins on new line.
#   IGNORE - A tag-list for lines which should be ignored.
#   PARAGRAPH - A tag-list for intented paragraphs.
#   PARAGRAPH2 - A tag-list for doubly indented paragraphs.
#   PARAGRAPH3 - A tag-list for triple indented paragraphs.
#   BLANK_LINE - A tag-list for blank lines (or non-indented paragraphs)
#   TABLE_ROW_START - A tag-list for table row's start
#   TABLE_COL1 - A tag-list for beginning of column 1
#   TABLE_COL2 - A tag-list for beginning of column 2
#   TABLE_COL3 - A tag-list for beginning of column 3
#   TABLE_COL4 - A tag-list for beginning of column 4
#   TABLE_ROW_END - A tag-list for table row's end
#   BREAK_BEFORE - A Perl regular expression before which line breaks
#       will always be inserted.

# COMMAND FILE TEXT PROCESSING SETTINGS:
#   BOLD - Perl regular expression to match any bold text.
#   ITALIC - Perl regular expression to match any italic text. 
#   REMOVE - Perl regular expression to match any SFM to be removed.
#   REPLACE - A Perl replacement regular expression to apply to text.    

# COMMAND FILE FOOTNOTE SETTINGS:
#   FOOTNOTE - A Perl regular expression to match all footnotes.
#   CROSSREF - A Perl regular expression to match all cross references.

# COMMAND FILE GLOSSARY/DICTIONARY RELATED SETTINGS:
#   GLOSSARY_ENTRY - A Perl regular expression to match 
#       glossary entry names in the SFM.
#   SEE_ALSO - A Perl regular expression to match "see-also" SFM tags.

sub paratext2imp($$) {
  my $cf = shift;
  my $outimp = shift;
  
  &Log("\n--- CONVERTING PARATEXT TO IMP\n-----------------------------------------------------\n\n");

  # Read the commandFile, converting each file as it is encountered
  my $commandFile = "$INPD/CF_paratext2imp.txt";
  &removeRevisionFromCF($commandFile);
  open(COMF, "<:encoding(UTF-8)", $commandFile) || die "Could not open paratext2imp command file $commandFile\n";

  $IgnoreTags = "";
  $ContinuationTerms = "";
  $GlossExp = "";
  $normpar = "";
  $doublepar = "";
  $triplepar = "";
  $blankline = "";
  $tablerstart = "nONe";
  $tablec1 = "nONe";
  $tablec2 = "nONe";
  $tablec3 = "nONe";
  $tablec4 = "nONe";
  $tablec5 = "nONe";
  $tablec6 = "nONe";
  $tablerend = "nONe";
  $bold = "";
  $italic = "";
  $remove = "";
  $txttags = "";
  $notes = "";
  $crossrefs = "";
  $seealsopat = "";
  $breakbefore = "";
  $replace1="";
  $replace2="";
  $newLine="";

  undef(%Glossary);
  $tagsintext="";  
  $line=0;
  while (<COMF>) {
    $line++;
    $_ =~ s/\s+$//;
    
    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^\#/) {next;}
    elsif ($_ =~ /^SET_(imageDir|addScripRefLinks|addSeeAlsoLinks):(\s*(\S+)\s*)?$/) {
      if ($2) {
        my $par = $1;
        my $val = $3;
        $$par = ($val && $val !~ /^(0|false)$/i ? $val:'0');
        &Log("INFO: Setting $par to $val\n");
      }
    }
    # VARIOUS SETTINGS...
    elsif ($_ =~ /^#/) {next;}
    elsif ($_ =~ /^VERSE_CONTINUE_TERMS:(\s*\((.*?)\)\s*)?$/) {if ($1) {$ContinuationTerms = $2; next;}}
    elsif ($_ =~ /^SPECIAL_CAPITALS:(\s*(.*?)\s*)?$/) {if ($1) {$SPECIAL_CAPITALS = $2; next;}}
    elsif ($_ =~ /^PUNC_AS_LETTER:(\s*(.*?)\s*)?$/) {if ($1) {$PUNC_AS_LETTER = $2; next;}}
    
    # FORMATTING TAGS...
    elsif ($_ =~ /^START_WITH_NEWLINE:\s*(.*?)\s*$/) {$newLine = $1; $newLine = ($newLine && $newLine !~ /^false$/i ? 1:0); next;}
    elsif ($_ =~ /^IGNORE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$IgnoreTags = $2; next;}}
    elsif ($_ =~ /^PARAGRAPH:(\s*\((.*?)\)\s*)?$/) {if ($1) {$normpar = $2; next;}}
    elsif ($_ =~ /^PARAGRAPH2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$doublepar = $2; next;}}
    elsif ($_ =~ /^PARAGRAPH3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$triplepar = $2; next;}}
    elsif ($_ =~ /^BLANK_LINE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$blankline = $2; next;}}
    elsif ($_ =~ /^TABLE_ROW_START:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablerstart = $2; next;}}
    elsif ($_ =~ /^TABLE_COL1:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec1= $2; next;}}
    elsif ($_ =~ /^TABLE_COL2:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec2= $2; next;}}
    elsif ($_ =~ /^TABLE_COL3:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec3= $2; next;}}
    elsif ($_ =~ /^TABLE_COL4:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec4= $2; next;}}
    elsif ($_ =~ /^TABLE_COL5:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec5= $2; next;}}
    elsif ($_ =~ /^TABLE_COL6:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablec6= $2; next;}}
    elsif ($_ =~ /^TABLE_ROW_END:(\s*\((.*?)\)\s*)?$/) {if ($1) {$tablerend= $2; next;}}
    elsif ($_ =~ /^BREAK_BEFORE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$breakbefore= $2; next;}}

    # TEXT PATTERNS... 
    elsif ($_ =~ /^GLOSSARY_ENTRY:(\s*\((.*?)\)\s*)?$/) {if ($1) {$GlossExp = $2; next;}} 
    elsif ($_ =~ /^REMOVE:(\s*\((.*?)\)\s*)?$/) {if ($1) {$remove = $2; next;}}
    elsif ($_ =~ /^BOLD:(\s*\((.*?)\)\s*)?$/) {if ($1) {$bold = $2; next;}}
    elsif ($_ =~ /^ITALIC:(\s*\((.*?)\)\s*)?$/) {if ($1) {$italic = $2; next;}}
    elsif ($_ =~ /^FOOTNOTE:(\s*(.*?)\s*)?$/) {if ($1) {$notes = $2; next;}}
    elsif ($_ =~ /^CROSSREF:(\s*\((.*?)\)\s*)?$/) {if ($1) {$crossrefs = $2; next;}}
    elsif ($_ =~ /^SEE_ALSO:(\s*\((.*?)\)\s*)?$/) {if ($1) {$seealsopat = $2; next;}}
    elsif ($_ =~ /^REPLACE:(\s*s\/(.*?)\/(.*?)\/\s*)?$/) {if ($1) {$replace1 = $2; $replace2 = $3; next;}}
    
    # SFM file name...
    elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {&glossSFMtoIMP($1);}
    elsif ($_ =~ /^APPEND:\s*(.*?)\s*$/) {&appendIMP($1);}
    else {&Log("ERROR: Unhandled command file entry \"$_\" in $commandFile\n");}
  }

  open(OUTF, ">:encoding(UTF-8)", $outimp) || die "Could not open paratext2imp output file $outimp\n";
  foreach $e (sort keys %Glossary) {
    my $txt = ${$Glossary{$e}}[0];
    
    # begin with newline if needed
    if ($newLine && $txt !~ /^\s*\Q$LB\E/) {$txt = $LB.$txt;}
    if ($newLine) {$txt =~ s/^(\s*\Q$LB\E)+/$LB/;}
    
    print OUTF "\$\$\$$e\n$txt\n";
  }
  close (OUTF);

  # Check and report...
  &Log("PROCESSING COMPLETE.\n");
  &Log("\nFollowing are unhandled tags which where removed from the text:\n$tagsintext");
  &Log("\nFollowing tags were removed from entry names:\n");
  foreach $k (keys %convertEntryRemoved) {&Log("$k ");}
  &Log("\nEnd of listing\n");
}


sub appendIMP($) {
  my $imp = shift;
  if ($imp =~ /^\./) {
    chdir($INPD);
    $imp = File::Spec->rel2abs($imp);
    chdir($SCRD);
  }
  
  &Log("Appending $imp\n");
  if (open(IMP, "<:encoding(UTF-8)", $imp)) {
    my $ent = "";
    my $txt = "";
    while(<IMP>) {
      if ($_ =~ /^\s*$/) {next;}
      if ($_ =~ /^\$\$\$\s*(.*?)\s*$/) {
        my $e = $1;
        if ($ent) {push(@{$Glossary{$ent}}, $txt);}
        $ent = $e;
        $txt = "";
      }
      else {$txt .= $_;}
    }
    if ($ent) {push(@{$Glossary{$ent}}, $txt);}
  }
  else {&Log("ERROR: Could not append \"$imp\". File not found.\n");}
}


sub glossSFMtoIMP($) {
  $SFMfile = shift;
  if ($SFMfile =~ /^\./) {
    chdir($INPD);
    $SFMfile = File::Spec->rel2abs($SFMfile);
    chdir($SCRD);
  }

  &Log("Processing $SFMfile\n");

  # Read the paratext file and convert it
  open(INF, "<:encoding(UTF-8)", $SFMfile) or print getcwd." ERROR: Could not open file $SFMfile.\n";

  # Read the paratext file line by line
  $SFMline=0;
  my $parsebuf = "";
  my $e;
  my $t;
  while (<INF>) {
    $SFMline++;

    if ($_ =~ /^\s*$/) {next;}
    elsif ($_ =~ /^\s*\\($IgnoreTags)(\s|$)/) {next;}
    elsif ($_ =~ s/^$GlossExp//) {
      my $e2 = $+;
      if ($e) {&Write($e, $t);}
      $e = $e2;
      if ($_ !~ /^\s*$/) {$t = $_;}
      else {$t = "";}
    }
    else {$t .= $_;}
  }
  
  if ($e) {&Write($e, $t);}
  else {&Log("ERROR: Failed to find any glossary entries matching pattern: \"^$GlossExp\".\n");}
  close (INF);
}


sub convertEntry($) {
  my $e = shift;
  $e =~ s/\\(\w+[\s\*])/$convertEntryRemoved{"\\$1"}++; my $t="";/eg;
  $e =~ s/\|([ibr])/$convertEntryRemoved{"|$1"}++; my $t="";/egi;
  $e =~ s/<[^>]*>/$convertEntryRemoved{"$1"}++; my $t="";/eg;
  $e =~ s/(^\s*|\s*$)//g;
  $e =~ s/\s+/ /g;
  return $e;
}


sub convertText($$) {
  my $l = shift;
  my $e = shift;
  
  if ($remove)    {
    if ($l =~ s/($remove)//g) {&Log("INFO: Removed /$remove/ in $e lines.\n");}
  }

  if ($replace1) {
    if ($replace2 =~ /\$/) {
      my $r;
      if ($l =~ s/$replace1/$r = eval($replace2);/eg) {&Log("INFO: Replaced /$replace1/ with /$r/ in $e\n");}
    }
    else {
      if ($l =~ s/$replace1/$replace2/g) {&Log("INFO: Replaced /$replace1/ with /$replace2/ in $e\n");}
    }
  }
   
  # text effect tags
  if ($bold)      {$l =~ s/($bold)/<hi type="bold">$+<\/hi>/g;}
  if ($italic)    {$l =~ s/($italic)/<hi type="italic">$+<\/hi>/g;}
  
  # handle table tags
  my $hastable = 0;
  if ($l =~ /($tablerstart)/) {&convertTable(\$l); $hastable = 1;}
 
  $l =~ s/\s*\/\/\s*/ /g; # Force carriage return SFM marker

  # paragraphs
  if ($blankline) {$l =~ s/^\\($blankline)(\s|$)/$LB$LB/gm;}
  if ($normpar)   {$l =~ s/^\\($normpar)(\s|$)/$LB$INDENT/gm;}
  if ($doublepar) {$l =~ s/^\\($doublepar)(\s|$)/$LB$INDENT$INDENT/gm;}
  if ($triplepar) {$l =~ s/^\\($triplepar)(\s|$)/$LB$INDENT$INDENT$INDENT/gm;}

  # footnotes, cross references, and glossary entries
  if ($seealsopat) {
    $l =~ s/($seealsopat)/my $a = $+; my $res = "<reference type=\"x-glosslink\" osisRef=\"$MOD:".&encodeOsisRef($a)."\">$a<\/reference>";/ge;
  }
  if ($crossrefs) {$l =~ s/($crossrefs)/<note type="crossReference">$+<\/note>/g;}
  if ($notes)     {$l =~ s/($notes)/<note>$+<\/note>/g;}
     
  if ($breakbefore && !$hastable) {
    $l =~ s/($breakbefore)/$LB$LB$1/g;
  }
  
  return $l;  
}


sub varEval($) {
  my $r = shift;
  
  if ($r =~ /\$/) {$r = eval($r);}
  return $r;
}


sub convertTable(\$) {
  my $tP = shift;

  if ($tablerstart && !$tablerend) {&Log("ERROR: TABLE_ROW_END must be specified if TABLE_ROW_START is specified.\n");}
  
  #my $w1 = "%-".&getWidestW($tP, "\\t[hc]1 ", "\\t[hc]2 ")."s | ";
  #my $w2 = "%-".&getWidestW($tP, "\\t[hc]2 ", "\\t[hc]3 ")."s | ";
  #my $w3 = "%-".&getWidestW($tP, "\\t[hc]3 ", quotemeta($LB))."s";

  if ($tablerstart) {
    if ($tablec1) {$$tP =~ s/($tablec1)(.*?)(($tablec2)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}
    if ($tablec2) {$$tP =~ s/($tablec2)(.*?)(($tablec3)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}
    if ($tablec3) {$$tP =~ s/($tablec3)(.*?)(($tablec4)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}
    if ($tablec4) {$$tP =~ s/($tablec4)(.*?)(($tablec5)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}
    if ($tablec5) {$$tP =~ s/($tablec5)(.*?)(($tablec6)|($tablerend))/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}
    if ($tablec6) {$$tP =~ s/($tablec6)(.*?)($tablerend)/my $a=$2; my $b=$3; my $f = &formatCell($a, $b).$b;/sge;}

    $$tP =~ s/($tablerstart)/$LB/g; # add one line-break before start of other rows 
    $$tP =~ s/\s*($tablerend)\s*/$LB$1/g; # add line-breaks after each table row
  }
}


sub formatCell($$) {
  my $t = shift;
  my $e = shift;
  my $cs = "%s | ";
  my $cl = "%s"; 
  $t =~ s/(^\s*|\s*$)//g;
  my $f = sprintf(($e =~ /^($tablerend)$/ ? $cl:$cs), $t);
  
  return $f;
}


sub getWidestW(\$$$) {
  my $tP = shift;
  my $ps = shift;
  my $pe = shift;
  
  my $w = 0;
  my $s = $$tP;
  $s =~ s/$ps(.*?)$pe/if (length($1) > $w) {$w = length($1);} my $r = "";/gem;
  
  return $w;
}


sub Write($$) {
  my $e = shift;
  my $t = shift;
  
  $e = &convertEntry($e);
  $t = &convertText($t, $e);
  
  # remove any trailing LBs
  $t =~ s/((\Q$LB\E)|(\s))+$//;
  
  my $save = $e;
  while ($e =~ s/((\\([\w]*)\*?)|(\|[ibr]))//i) {
    my $msg = "WARNING Before $SFMfile Line $SFMline: SFM Tag \"$+\" was REMOVED from entry name $e\n$save.\n";
    $tagsintext .= $msg;
  }
  
  my $save = $t;
  while ($t =~ s/((\\([\w]*)\*?)|(\|[ibr]))//i) {
    my $msg = "WARNING Before $SFMfile Line $SFMline: SFM Tag \"$+\" was REMOVED from entry text $t\n$save.\n";
    $tagsintext .= $msg;
  }
  
  push(@{$Glossary{$e}}, $t);
  &logProgress($e);
}

1;
