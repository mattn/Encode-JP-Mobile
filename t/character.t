use strict;
use warnings;
use utf8;
use Encode::JP::Mobile::Character;
use Test::More tests => 18;

# docomo
{
    my $char = Encode::JP::Mobile::Character->from_unicode(0xE63E);
    is $char->name, "晴れ";
    ok Encode::is_utf8($char->name), 'flagged';
    is $char->unicode_hex, "E63E";
    is $char->number, 1;
    is $char->fallback_name('I'), undef;
}

# docomo ext
{
    my $char = Encode::JP::Mobile::Character->from_unicode(0xE757);
    is $char->number, "拡76", 'docomo ext';
    ok Encode::is_utf8($char->number);
}

{
    is(Encode::JP::Mobile::Character->from_number(carrier => 'I', number => "拡76")->unicode_hex, 'E757');
}

# KDDI
{
    my $char = Encode::JP::Mobile::Character->from_unicode(0xECA2);
    is $char->fallback_name('I'), "(>３<)";
    is $char->fallback_name('H'), "(>３<)", "airhphone is same as docomo";
    ok Encode::is_utf8($char->fallback_name('I'));
    is $char->name, "チュー２", "What's name for 0xECA2";
    ok Encode::is_utf8($char->name);
    is $char->number, 455, 'number';
}

# KDDI from number.
{
    is(Encode::JP::Mobile::Character->from_number(carrier => 'E', number => 455)->unicode_hex, 'ECA2');
}

# carrier
my $map = +{
    0xE532 => 'V',
    0xECE7 => 'E',
    0xE6E5 => 'I',
};
while (my ($unicode, $carrier) = each %$map) {
    is(Encode::JP::Mobile::Character->from_unicode($unicode)->carrier, $carrier, "carrier $carrier");
}

