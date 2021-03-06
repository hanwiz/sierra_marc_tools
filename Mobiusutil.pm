#!/usr/bin/perl
#
# Mobiusutil.pm
# 
# Requires:
#
# recordItem.pm
# sierraScraper.pm
# DBhandler.pm
# Loghandler.pm
# Mobiusutil.pm
# MARC::Record (from CPAN)
# Net::FTP
# 
# This is a simple utility class that provides some common functions
#
# Usage: 
# my $mobUtil = new Mobiusutil(); #No constructor
# my $conf = $mobUtil->readConfFile($configFile);
#
# Other Functions available:
#	makeEvenWidth
#	sendftp
#	getMarcFromZ3950
#	chooseNewFileName
#	trim
#	findSummonIDs
#	makeCommaFromArray
#
# Blake Graham-Henderson 
# MOBIUS
# blake@mobiusconsortium.org
# 2013-1-24


package Mobiusutil;
 use MARC::Record;
 use MARC::File;
 use ZOOM; 
 use Net::FTP;
 use Loghandler;
 use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}


sub readConfFile
 {
	my %ret = ();
	my $ret = \%ret;
	my $file = @_[1];
	
	my $confFile = new Loghandler($file);
	if(!$confFile->fileExists())
	{
		print "Config File does not exist\n";
		undef $confFile;
		return false;
	}

	my @lines = @{ $confFile->readFile() };
	undef $confFile;
	
	foreach my $line (@lines)
	{
		$line =~ s/\n//;  #remove newline characters
		my $cur = trim('',$line);
		my $len = length($cur);
		if($len>0)
		{
			if(substr($cur,0,1)ne"#")
			{
		
				my $Name, $Value;
				($Name, $Value) = split (/=/, $cur);
				$$ret{trim('',$Name)} = trim('',$Value);
			}
		}
	}
	
	return \%ret;
 }
 
sub makeEvenWidth  #line, width
{
	my $ret;
	
	if($#_+1 !=3)
	{
		return;
	}
	$line = @_[1];	
	$width = @_[2];
	#print "I got \"$line\" and width $width\n";
	$ret=$line;
	if(length($line)>=$width)
	{
		$ret=substr($ret,0,$width);
	} 
	else
	{
		while(length($ret)<$width)
		{
			$ret=$ret." ";
		}
	}
	#print "Returning \"$ret\"\nWidth: ".length($ret)."\n";
	return $ret;
	
}
 
 sub sendftp    #server,login,password,remote directory, array of local files to transfer, Loghandler object
 {
		
	if($#_+1 !=7)
	{
		return;
	}
	
	my $hostname = @_[1];
	my $login = @_[2];
	my $pass = @_[3];
	my $remotedir = @_[4];
    my @files = @{@_[5]};
	my $log = @_[6];
	
	$log->addLogLine("**********FTP starting -> $hostname with $login and $pass -> $remotedir");
    my $ftp = Net::FTP->new($hostname, Debug => 0)
    or die $log->addLogLine("Cannot connect to ".$hostname);
    $ftp->login($login,$pass)
    or die $log->addLogLine("Cannot login ", $ftp->message);
    $ftp->cwd($remotedir)
    or die $log->addLogLine("Cannot change working directory ", $ftp->message);
	foreach my $file (@files)
	{
		$log->addLogLine("Sending file $file");
		$ftp->put($file)
		or die $log->addLogLine("Sending file $file failed");
	}
    $ftp->quit
	or die $log->addLogLine("Unable to close FTP connection");
	$log->addLogLine("**********FTP session closed ***************");
 }
 
 sub getMarcFromZ3950  #Pass values (server,query, Loghander Object)  returns array reference to MARC::Record array
 {
	my @ret;
	
	if($#_+1 !=4)
	{
		return;
	}
		
		
	 my $DATABASE = @_[1];
	 my $query = @_[2];
	 my $log = @_[3];
	 
	 
	 if ( ! $query ) 
	 {	 
		 $log->addLogLine("Z39.50 Error - Query Required");
		 return;
	 }
	 
	 $log->addLogLine("************Starting Z39.50 Connection -> $DATABASE $query");
	 my $connection = new ZOOM::Connection( $DATABASE, 0, count=>1, preferredRecordSyntax => "USMARC" );
	 my $results = $connection->search_pqf( qq[$query] );
	 
	 my $size = $results->size();
	 $log->addLogLine("Received $size records");
	 my $index = 0;
	 for my $i ( 0 .. $results->size()-1 ) 
	 {
		 #print $results->record( $i )->render();
		 my $record = $results->record( $i )->raw;
		 my $marc = MARC::Record->new_from_usmarc( $record );
		 push(@ret,$marc);
	 }
	 
	 $log->addLogLine("************Ending Z39.50 Connection************");
	 undef $conection, $results;
	 return \@ret;
 }
 
 sub chooseNewFileName   #path to output folder,file prefix, file extention    returns full path to new file name
{
	if($#_+1 !=4)
	{
		return 0;
	}
	my $path = @_[1];
# Add trailing slash if there isn't one	
	if(substr($path,length($path)-1,1) ne '/')
	{
		$path = $path.'/';
	}
	
	my $seed = @_[2];
	my $ext = @_[3];
	my $ret="";
	if( -d $path)
	{
		my $num=0;
		$ret = $path . $seed . $num . '.' . $ext;
		while(-e $ret)
		{
			$num = $num+1;
			$ret = $path . $seed . $num . '.' . $ext;
		}
	}
	else
	{
		$ret = 0;
	}
	
	return $ret;
}
 
 sub trim
{
	my $self = shift;
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub findSummonIDs		#DBhandler, #loghandler
{
	if($#_+1 !=3)
	{
		return 0;
	}
	my $dbHandler = @_[1];
	my $log = @_[2];
	
	
	my $query = "SELECT RECORD_ID FROM SIERRA_VIEW.BIB_RECORD WHERE RECORD_ID=420907796199";
	
	my @ret;
	my @results = @{$dbHandler->query($query)};
				 
	 my $size = length(@results);
	 #print @results;
	 #print "recieved $size results\n";
	 
	foreach(@results)
	{
		my $row = $_;
		my @row = @{$row};
		print "::newrow::";
		foreach my $val(@row)
		{
			push(@ret, $val);
			print"$val\t";
		}
		print "\n";
		
	}
	
	return @ret;
	
}

sub makeCommaFromArray
 {
	my @array = @{@_[1]};	
	my $ret = "";
	for my $i (0..$#array)
	{
		$ret.=@array[$i].",";
	}
	$ret= substr($ret,0,length($ret)-1);
	return $ret;
 }
 
 sub insertDataIntoColumn  #1 based column position
 {
	my $ret = @_[1];
	my $data = @_[2];
	my $column = @_[3];
	my $len = length($ret);
	if(length($ret)<($column-1))
	{
		while(length($ret)<($column-1))
		{
			$ret.=" ";
		}
		$ret.=$data;
	}
	else
	{
		my @ogchars = split("",$ret);
		my @insertChars = split("",$data);
		my $len = $#insertChars;
		for my $i (0..$#insertChars-1)
		{
			@ogchars[$i+$column-1] = @insertChars[$i];
		}
		$ret="";
		foreach(@ogchars)
		{
			$ret.=$_;
		}
	}
	return $ret;
	
 }
 
 sub compare2MARCFiles
 {
	my $firstFile = @_[1];
	my $secondFile = @_[2];
	my $log = @_[3];
	my $fileCheck1 = new Loghandler($firstFile);
	my $fileCheck2 = new Loghandler($secondFile);
	my %file1, %file2;
	my @matchedFile1, @matchedFile2;
	my @errors;
	if($fileCheck1->fileExists() && $fileCheck2->fileExists())
	{
		my $file = MARC::File::USMARC->in( $firstFile );
		my $r =0;
		while ( my $marc = $file->next() ) 
		{
			print "Record $r\n";
			$r++;
			
			my $recID = $marc->field('907')->subfield('a');
			
			if(exists($file1{$recID}))
			{
				#print "There were more than 1 of the same records containing same Record Num $recID in file $firstFile\n";
			}
			else
			{
				$file1{$recID} = $marc;
				push(@matchedFile1,$recID);
			}
		}
		$file = MARC::File::USMARC->in( $secondFile );
		while ( my $marc = $file->next() ) 
		{
			
			my $recID = $marc->field('907')->subfield('a');
			if(exists($file2{$recID}))
			{
				#print "There were more than 1 of the same records containing same Record Num $recID in file $secondFile\n";
			}
			else
			{
				$file2{$recID} = $marc;
				push(@matchedFile2,$recID);
			}
		}
		
		
		my @matched;
		
		for my $onePos (0..$#matchedFile1)
		{
			$thisOCLCNum = @matchedFile1[$onePos];
			#print "$thisOCLCNum\n";
			for my $twoPos(0.. $#matchedFile2)
			{
				if(@matchedFile1[$onePos] eq @matchedFile2[$twoPos])
				{
					my $leader1 = $file1{@matchedFile1[$onePos]}->leader();					
					my $leader2 = $file2{@matchedFile2[$twoPos]}->leader();
					my $leaderMatchErrorString="";
					if($leader1 ne $leader2)
					{
						$leaderMatchErrorString="Leader \"$leader1\" != \"$leader2\"";
					}
					
					my @theseErrors = @{compare2MARCObjects("",$file1{@matchedFile1[$onePos]},$file2{@matchedFile2[$twoPos]})};
					push(@matched,@matchedFile1[$onePos]);
					if(($#theseErrors>-1) || (length($leaderMatchErrorString)!=0))
					{
						push(@errors,"Errors for $thisOCLCNum:");
						push(@errors,"\t$leaderMatchErrorString");
						foreach(@theseErrors)
						{
							push(@errors,"\t$_");
						}
					}
					push(@errors,"\n");
				}
			}
			
		}
		
		my @notMatchedList;
		my $totalMatched=0;
		while ((my $internal, my $value ) = each(%file1))
		{
			if(!exists $matched[$internal])
			{
				push(@notMatcheList,$internal);
			}
			else
			{
				$totalMatched++;
			}
		}
		if($#notMatchedList>-1)
		{
			my $list;
			foreach(@notMatchedList)
			{
				$list.="$_,";
			}
			push(@errors,"File 1 didn't have a sister for these records:\n$list");
		}		
		my $recordCount1=keys( %file1 ), $recordCount2=keys( %file2 );		
		push(@errors,"$recordCount1 Record(s) in file 1 and $recordCount2 Record(s) in file 2");
		push(@errors,"Matched $totalMatched Record(s) from file 1");
				
	}
	else
	{
		print "One or both of those files do not exist\n";
	}
	
	return \@errors;
 }
 
 sub compare2MARCObjects
 {
	my $marc1 = @_[1];
	my $marc2 = @_[2];
	my @errors;
	my @remainingFields1,@remainingFields2;
	my @marcFields1 = $marc1->fields();
	my @marcFields2 = $marc2->fields();
	
	foreach(@marcFields1)
	{
		push(@remainingFields1,"".$_->tag());
	}
	foreach(@marcFields2)
	{
		push(@remainingFields2,"".$_->tag());
	}
	
	for my $fieldPos1(0..$#marcFields1)
	{
		my @matchPos2;
		my $thisField1 = @marcFields1[$fieldPos1];		
		#if($thisField1->tag() ne'998')
		#{
		for my $fieldPos2(0..$#marcFields2)
		{
			my $thisField2 = @marcFields2[$fieldPos2];
			if($thisField2->tag() eq $thisField1->tag())
			{
				push(@matchPos2,$fieldPos2);
			}
		}
		
		if($#matchPos2==0)  #only 1 field
		{
			my @thisErrorList = @{compare2MARCFields("",$thisField1,@marcFields2[@matchPos2[0]])};
			if($#thisErrorList>-1)
			{
				push(@errors,"Errors for ".$thisField1->tag());
				foreach(@thisErrorList)
				{
					push(@errors,"\t$_");
				}
			}
			
		}
		elsif($#matchPos2>0)
		{
			#print "There were more than 1 matching field tags for ".$thisField1->tag()."\n";
			my $errorCheck=-1;
			my @check;
			for my $pos(0..$#matchPos2)
			{
				push(@check,[@{compare2MARCFields("",$thisField1,@marcFields2[@matchPos2[$pos]])}]);				
				if($#{@check[$#check]}==-1)
				{
					$errorCheck = $pos;
				}
				
			}
			if($errorCheck==-1)
			{
				push(@errors,"None of the sister tags(".$thisField1->tag().") matched and here are the errors:");
				foreach(@check)
				{
					my @subError = @{$_};
					foreach(@subError)
					{
						push(@errors,"\t".$_);
					}
				}
			}
		}
		else
		{
			push(@errors,"Tag: ".$thisField1->tag()." did not match any tags on the sister MARC Record");
		}
		@matchPos2 = ();
		#}
	}
	return \@errors;
 }
 
 sub compare2MARCFields
 {
 
	my $field1 = @_[1];
	my $field2 = @_[2];
	my $tag = $field1->tag();
	
	my @errors;
	if($field1->tag() ne $field2->tag())
	{
		push(@errors,"Tags do not match");
	}
	else
	{
		if(!($field1->is_control_field()))
		{
			@subFields1 = $field1->subfields();
			@subFields2 = $field2->subfields();
			my $indicators1 = $field1->indicator(1).$field1->indicator(2);
			my $indicators2 = $field2->indicator(1).$field2->indicator(2);
			if($indicators1 ne $indicators2)
			{
				push(@errors,"Tag: $tag Indicators mismatch \"$indicators1\" != \"$indicators2\"");
			}
			for my $fieldPos1(0..$#subFields1)
			{
				my @matchPos2;
				my $thisField1 = @{@subFields1[$fieldPos1]}[0];
				
				for my $fieldPos2(0..$#subFields2)
				{
					my $thisField2 = @{@subFields2[$fieldPos2]}[0];
					if($thisField1 eq $thisField2 )
					{
						push(@matchPos2, $fieldPos2);
					}
				}
				
				if($#matchPos2==0)  #only 1 field
				{
					my $comp1 = @{@subFields1[$fieldPos1]}[1];
					my $comp2 = @{@subFields2[@matchPos2[0]]}[1];
					if($comp1 ne $comp2)
					{
						push(@errors,"Tag: $tag Subfield $thisField1 $comp1 != $comp2");
					}
					
				}
				elsif($#matchPos2>0)
				{
					#print "There were more than 1 matching subfield tags for tag: $tag Subfield: $thisField1\n";
					my $noErrors=-1;
					my $comp1 = @{@subFields1[$fieldPos1]}[1];
					my $errorListString="";
					for my $pos(0..$#matchPos2)
					{
						my $comp2 = @{@subFields2[@matchPos2[$pos]]}[1];
						if($comp1 eq $comp2)
						{
							$noErrors = $pos;
						}
						else
						{
							$errorListString.="  $comp1 != $comp2";
						}
					}
					if($noErrors==-1)
					{
						push(@errors,"Tag: $tag Subfield $thisField1 $errorListString");
					}
				}
				else
				{
					push(@errors,"Tag: $tag Subfield $thisField1 Could not find a matching subfield on the sister tag");
				}
				@matchPos2 = ();
			}
		}
		else
		{
			if($field1->data() ne $field2->data())
			{
				push(@errors,"$tag do not match");
			}
		}
	}
	
	return \@errors;
	
 }
 
 sub compareStrings
 {
	my $string1 = @_[1];
	my $string2 = @_[2];
	if(length($string1)!=length($string2))
	{
	#print "\"$string1\" \"$string2\"\nDiffering Lengths\n";
		return 0;
	}
	my @chars1 = split("",$string1);
	my @chars2 = split("",$string2);
	for my $i (0..$#chars1)
	{
		my $tem1 = @chars1[$i];
		my $tem2 = @chars2[$i];
		my $t1 = ord($tem1);
		my $t2 = ord($tem2);
		
		if(0)
		{
		if(ord($tem1)!=ord($tem2))
		{
			return 0;
		}
		}
		if(@chars1[$i] ne @chars2[$i])
		{
			#print "! $string1 != $string2 - \"".@chars1[$i]."\"($t1) to \"".@chars2[$i]."\"($t2)\n";
			return 0;
		}
	}
	
	return 1;
	
 }

1;

