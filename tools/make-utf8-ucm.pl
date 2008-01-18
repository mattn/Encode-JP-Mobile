use strict;
use warnings;
use YAML;
use Encode;
use Encode::JP::Mobile ':props';
use autobox;
use autobox::Core;
use autobox::Encode;
use FindBin;
use File::Spec;
use Path::Class;

my $map = YAML::LoadFile file($FindBin::Bin, '..', 'dat', 'convert-map-utf8.yaml');
my $cp932_ucm = file($FindBin::Bin, '..', 'ucm', 'cp932.ucm');

my $uni_range_for = {
    docomo   => InDoCoMoPictograms(),
    kddi     => InKDDIPictograms(),
    softbank => InSoftBankPictograms(),
    airh     => InDoCoMoPictograms(),
};

sub SCALAR::to_hex($) { sprintf '%X', $_[0] }
sub SCALAR::omote2ura($) { $_[0]->encode('x-sjis-kddi')->decode('x-sjis-kddi-auto') }
sub SCALAR::uni2int($) { unpack 'U*', $_[0] }

&main;exit;

sub main {
    for my $to (qw( docomo kddi softbank )) {
        generate_ucm($to, sub {
            my $fh = shift;

            # convert map
            for my $from (qw( docomo kddi softbank )) {
                next if $from eq $to;

                print {$fh} "\n\n# pictogram convert map ($from => $to)\n";

                for my $srcuni (sort keys %{$map->{$from}}) {
                    my $dstuni = $map->{$from}{$srcuni}{$to} or next;
                    printf {$fh} "<U%s> %s |1 # %s\n", $srcuni, unihex2utf8hex($dstuni), comment_for($from);
                }
            }

            # original
            if ($to eq 'kddi') {
                # ura-kddi
                range_each($to, sub {
                    my $unicode = shift;
                    my $unihex = $unicode->chr->omote2ura->uni2int->to_hex;
                    print {$fh} sprintf "<U%s> %s |0 # %s\n", $unihex, unihex2utf8hex($unihex), "UraKDDI pictogram";
                });
            } else {
                range_each($to, sub {
                    my $unicode = shift;
                    my $unihex = $unicode->to_hex;
                    print {$fh} sprintf "<U%s> %s |0 # %s\n", $unihex, unihex2utf8hex($unihex), "$to pictogram";
                });
            }
        });
    }

    # airh
    generate_ucm('airh', sub {
        my $fh = shift;

        # convert map
        # XXX willcom phones can display docomo pictograms
        for my $from (qw( kddi softbank )) {
            print {$fh} "\n\n# pictogram convert map ($from => docomo)\n";

            for my $srcuni (sort keys %{$map->{$from}}) {
                my $dstuni = $map->{$from}->{$srcuni}->{'docomo'} or next;
                printf {$fh} "<U%s> %s |1 # %s\n", $srcuni, unihex2utf8hex($dstuni), comment_for($from);
            }
        }

        # original
        print $fh "\n\n# airh pictograms\n";
        range_each('airh', sub {
            my $unicode = shift;
            my $unihex = $unicode->to_hex;
            print {$fh} sprintf "<U%s> %s |0 # %s\n", $unihex, unihex2utf8hex($unihex), "airh pictogram";
        });
    });
}

sub generate_ucm {
    my ($to, $generate_pictogram_ucm) = @_;
    my $fh = file('ucm', "x-utf8-$to.ucm")->openw or die $!;
    print {$fh} header($to);
    print {$fh} unicode_ucm($cp932_ucm);
    $generate_pictogram_ucm->($fh);
    print {$fh} "END CHARMAP\n";
    $fh->close;
}

sub comment_for {
    my $from = shift;
    return $from eq 'docomo'   ? 'DoCoMo Pictogram'
      : $from    eq 'kddi'     ? 'KDDI/AU Pictogram'
      : $from    eq 'softbank' ? 'SoftBank Pictogram'
      :                          "";
}

sub header {
    my $to = shift;

    my %alias = qw(
        docomo imode
        kddi ezweb
        softbank vodafone
        airh airedge
    );

    <<"HEAD";
<code_set_name> "x-utf8-$to"
<code_set_alias> "x-utf8-$alias{$to}"
<mb_cur_min> 1
<mb_cur_max> 2
<subchar> \\x3F
CHARMAP
HEAD
}

sub unihex2utf8hex {
    my $uni = shift;
    $uni = 'H*'->unpack($uni->hex->chr->encode('utf-8'));
    $uni =~ s/(..)/\\x$1/g;
    $uni;
}

sub unicode_ucm {
    my $cp932_ucm = shift;
    my $res = '';
    my $fh = $cp932_ucm->openr or die $!;
    while (my $line = <$fh>) {
        if ($line =~ /^<U(.{4})> \S+ \|0 # (.+)$/) {
            my ($unihex, $comment) = ($1, $2);

            # for FallBack.
            next if $comment eq 'PRIVATE USE AREA';

            $res .= sprintf "<U%s> %s |0 # %s\n", $unihex, unihex2utf8hex($unihex), $comment;
        }
    }
    $fh->close;
    $res;
}

sub range_each {
    my ($carrier, $code) = @_;

    my $map = $uni_range_for->{$carrier};
    for my $range (split /\n/, $map) {
        my ($min, $max) = map { hex $_ } split /\t/, $range;
        my $i = $min;
        if ($max) {
            while ($i <= $max) {
                $code->( $i );
                $i++;
            }
        } else {
            $code->($min);
        }
    }
}

