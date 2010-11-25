#######################################################################
# $Id: Duplicates.pm,v 1.11 2010-11-25 20:17:04 dpchrist Exp $
#######################################################################
# package:
#----------------------------------------------------------------------

package Dpchrist::File::Find::Duplicates;

use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
    file_find_duplicate
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw();

our $VERSION = sprintf("%d.%03d", q$Revision: 1.11 $ =~ /(\d+)/g);

#######################################################################
# uses:
#----------------------------------------------------------------------

use constant			DEBUG => 0;

use Carp;
#use Digest::MD5;
use Dpchrist::Debug		qw( :all );
use File::Compare		qw( compare_text );
use File::Find;
#use Getopt::Long;
#use Pod::Usage;

#######################################################################
# globals:
#----------------------------------------------------------------------

$\ = 1 if DEBUG;

my $dotflag = 0;

my $dottime = 0;

our %opt = (
);

my $sizes_paths;

my %used_only_once = (
    -File__Find__name		=> $File::Find::name,
);

#######################################################################

sub dot
{
    print STDERR '.';
    $dotflag = 1;
    $dottime = time;
}

#----------------------------------------------------------------------

sub dotnl
{
    print STDERR "\n" if $dotflag;
    $dotflag = 0;
    $dottime = 0;
}

#----------------------------------------------------------------------

sub status
{
    dotnl;
    print STDERR @_;
    dot;
}

#----------------------------------------------------------------------

sub wanted
{
    ddump 'entry', [\@_, $_], [qw(*_ _)] if DEBUG;
    return if -d $_;
    return if -z;
    my $size = (stat)[7];
    dot() if $opt{-verbose} && $dottime != time;
    my $path = $File::Find::name;
    ddump [$size, $path], [qw(size path)] if DEBUG;
    push @{$sizes_paths->{$size}}, $path;
}

#######################################################################

=head1 NAME

Dpchrist::File::Find::Duplicates - find duplicate files

=head1 DESCRIPTION

This documentation describes module revision $Revision: 1.11 $.


This is alpha test level software
and may change or disappear at any time.



=head2 SUBROUTINES

=cut

#######################################################################

=head3 file_find_duplicate LIST

Recursively search all paths and directories in LIST
and print any duplicates found.

Options may be set via %Dpchrist::File::Find::Duplicates::opt:

=over

=item -delete => BOOL

    Delete duplicate files

=item -show_keeper => BOOL

    Print keeper files preceded by hash (#)

=item -verbose => INT

    Printer extra information during operation.
    Larger numbers print more information.

=back

Returns true (1).

Calls Carp::confess() on fatal errors.

=cut

#----------------------------------------------------------------------

sub insert_dups
{
    ddump 'entry', [\@_], [qw(*_)] if DEBUG;

    my ($p, $a, $b) = @_;
    
    my $rl;
    foreach my $q (@$p) {
	foreach my $e (@$q) {
	    $rl = $q if $e eq $a || $e eq $b;
	}
    }
#    ddump ([$rl], [qw(rl)]) if DEBUG;

    if ($rl) {
	push(@$rl, $a) unless grep {$_ eq $a} @$rl;
	push(@$rl, $b) unless grep {$_ eq $b} @$rl;
    }
    else {
	push @$p, [$a, $b];
    }

    ddump ([$p], [qw(p)]) if DEBUG;
    return $p;
}

#----------------------------------------------------------------------

sub file_find_duplicate
{
    ddump 'entry', [\@_], [qw(*_)] if DEBUG;

    my $retval = [];

    $| = 1 if $opt{-delete};

#    status "Reading file system"
#	if $opt{-verbose};

    if (@_) {
	find(\&wanted, @_);
    }
    else {
	my @stdin;
	while (<>) {
	    chomp;
	    push @stdin, $_;
	}
	ddump [\@stdin], [qw(*stdin)] if DEBUG;
	find(\&wanted, @stdin);
    }


    ddump [$sizes_paths], [qw(sizes_paths)] if DEBUG;

#    status "Found ",
#	scalar keys %$sizes_paths,
#	" different file sizes"
#	if $opt{-verbose};

    dot() if $opt{-verbose} && $dottime != time;
    foreach my $size (sort { $a <=> $b } keys %$sizes_paths) {
	my $hashes_paths;
	my @paths_with_same_size = sort @{$sizes_paths->{$size}};
	ddump [$size, \@paths_with_same_size],
	    [qw(size   *paths_with_same_size)]
	    if DEBUG;

	next unless 1 < @paths_with_same_size;
	dot() if $opt{-verbose} && $dottime != time;

	status "Found ",
	    scalar @paths_with_same_size,
	    " files with size $size",
	    if $opt{-verbose} && $opt{-verbose} > 1;

	my %dups;

	while (my $path1 = shift @paths_with_same_size) {
	    last unless @paths_with_same_size;
	    next if $dups{$path1};
	    dot() if $opt{-verbose} && $dottime != time;

	    confess "undefined path found"
		unless defined $path1;
	
	    status "Comparing file '$path1' against ",
		scalar @paths_with_same_size,
		" file(s)"
		if $opt{-verbose} && $opt{-verbose} > 3;
	    foreach my $path2 (@paths_with_same_size) {
		next if $dups{$path2};
		dot() if $opt{-verbose} && $dottime != time;

		if ($path1 eq $path2) {
		    warn "path '$path1' found more than once";
		    next;
		}
		status "Comparing file '$path1' against '$path2'"
		    if $opt{-verbose} && $opt{-verbose} > 4;
		if (compare_text($path1, $path2) == 0) {
		    insert_dups($retval, $path1, $path2);
		    dot() if $opt{-verbose} && $dottime != time;
		    $dups{$path2}++;
		}
	    }
	}
    }
    dotnl;

    foreach my $rl (@$retval) {
	@$rl = sort @$rl;
	shift @$rl;
	foreach my $f (sort @$rl) {
	    if ($opt{-delete}) {
		print STDERR "unlinking ";
		unlink $f;
	    }
	    print $f, "\n";
	}
    }

    return $retval;
}

#######################################################################
# end of code:
#----------------------------------------------------------------------

1;

__END__

#######################################################################

=head2 EXPORT

None by default.

All of the subroutines may be imported by using the ':all' tag:

	use Dpchrist:File::Find::Duplicates qw( :all );

See 'perldoc Export' for everything in between.

=head1 INSTALLATION

    perl Makefile.PL
    make    
    make test
    make install 


=head1 DEPENDENCIES

    Dpchirst::Debug
    Dpchrist::Module
			 

=head1 AUTHOR

David Paul Christensen dpchrist@holgerdanske.com


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by David Paul Chirstensen dpchrist@holgerdanske.com

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307,
USA.

=cut

#######################################################################
