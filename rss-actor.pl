#!/usr/bin/perl

use strict;
use warnings;

no if $] >= 5.018, warnings => "experimental::smartmatch";

use Switch;
use XML::RSS;
use LWP::Simple 'get';
use Data::Dumper;
use Data::DPath 'dpath';
use YAML 'LoadFile';
use Getopt::Long;

my $DEBUG = 0;
my $IGNORESEEN = 0;
my $NOEXEC = 0;

my $SEEN_DIR = "$ENV{HOME}/.rss-actor";

GetOptions(
    "d|debug!"       => \$DEBUG,
    "is|ignoreseen!" => \$IGNORESEEN,
    "ne|noexec"      => \$NOEXEC,
) || usage();

usage() if scalar @ARGV == 0;

process_config($_) foreach @ARGV;

sub usage {
    print STDERR "Usage: $0 [-d|-debug] [-is|-ignoreseen] [-ne|-noexec] conffile [conffile...]\n";
    exit 1;
}

sub DEBUG {
    print join " ", @_ if $DEBUG;
}

sub get_var {
    my ($vars, $name, $data) = @_;

    for my $var ( @$vars ) {
        if ($var->{name} eq $name) {
            if ($var->{value}) {
                return $var->{value};
            }
            if ($var->{dpath}) {
                my $vals = $data ~~ dpath $var->{dpath};
                return $vals->[0];
            }
            die "Invalid variable type for $var->{name}";
        }
    }
    die "Variable $name not found";
}

sub get_val {
    my ( $vars, $v, $data) = @_;

    my $nv;

    if (my ($a,$b,$c) = ($v =~ /(.*?)%([^%]+)%(.*)/)) {
        $nv .= $a;
        my $var = get_var($vars, $b, $data);
        $nv .= get_val($vars, $var, $data);
        $nv .= get_val($vars, $c, $data);
    } else {
        $nv = $v;
    }

    return $nv;
}


sub seen_filename {
    my $id = shift;
    return "$SEEN_DIR/$id.seen.txt";
}

sub read_seen {
    my $id = shift;

    open(my $F, seen_filename($id)) || return [];
    my @seen = ();
    while (<$F>) {
        chomp;
        push @seen, $_;
    }

    close $F;

    return \@seen;
}

sub write_seen {
    my ($id, $seen) = @_;
    my $fn = seen_filename($id);

    open(my $F, ">$fn") || do {
        print STDERR "Could not create file $fn";
        return;
    };

    print $F "$_\n" foreach ( @$seen );
    close $F;
}

sub process_config {
    my $fname = shift;
    DEBUG("Processing config $fname\n");

    my $config;

    eval {
        $config = LoadFile($fname);
    };

    if ($@) {
        print STDERR "Could not load config from $fname: $!\n";
        return;
    }

    my $vars = $config->{vars};

    my $xml;
    if ($config->{channel}) {
        my $channel = get_val($vars, $config->{channel});
        $xml = get($channel);
        die "Could not download channel $channel" unless $xml;
    } elsif ($config->{file}) {
        open (my $F, get_val($vars, $config->{file})) || die "Cannot open config $config->{file}";
        $xml = "";
        while (<$F>) { $xml .= $_ };
        close($F);
    } else {
        die "No channel or file defined in $fname";
    }

    my $rss = new XML::RSS (version => '1.0');

    $rss->parse($xml);

    my $seen = read_seen($config->{id});

    foreach my $item (@{$rss->{'items'}}) {
        my $title = $item->{title};
        $title =~ s/[^[:ascii:]]+/_/g;
        if (!$IGNORESEEN && grep { $_ eq $title} @$seen) {
            DEBUG("Already seen: $title\n");
            next;
        }

        push @$seen, $title;

        DEBUG("New in channel: $title\n");


        for my $match ( @{$config->{match}}) {
            my $vals = $item ~~ dpath $match->{dpath};
            my $val = $vals->[0];
            if ($match->{regexp} && $val !~ /$match->{regexp}/) {
                DEBUG("No match, ignoring: $val\n");
                next;
            }
            if ($match->{noregexp} && $val =~ /$match->{noregexp}/) {
                DEBUG("Ingnore match, ignoring: $val\n");
                next;
            }

            DEBUG("OK: $val\n");

            my $mvars = $match->{vars}||[];

            my @lvars=(@$vars, @$mvars);
            for my $do ( @{$match->{do}} ) {
                switch ($do->{action}) {
                    case "print" {
                        my $str = get_val(\@lvars, $do->{print}, $item);
                        print "$str\n";
                    }
                    case "exec" {
                        my $cmd = $do->{cmd};
                        $cmd = [ $cmd ] if ref $cmd eq "";
                        my @ecmd = map { get_val(\@lvars, $_, $item) } @$cmd;
                        DEBUG($NOEXEC ? "NOT" : "", "Executing:", join (" ", @ecmd), "\n");
                        system(@ecmd) unless $NOEXEC;
                    }
                    case "dump" {
                        print Dumper($item);
                    }
                    else {
                        die "Uknown action: '$do->{action}'\n";
                    }
                }
            }
        }
    }

    mkdir $SEEN_DIR || die "Could not create directory $SEEN_DIR: $?";
    write_seen($config->{id}, $seen);
}

