#!/usr/bin/perl

use warnings;
use strict;

use Test::More no_plan =>;

use Qt;

sub N ($) {bless(\(shift), 'Qt::enum::_overload')};

sub check ($$;$) {
  my ($got, $expect, $message) = @_;
  $message ||= '';
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  unless(ref $got) {
    ok(0);
    diag("not a reference - $message");
    return;
  }
  is($$got, $expect, ($message ? $message : ()));
}
{
  my $x = N 8;
  my $y = N 9;
  check $x & 9, 8, '&';
  check $x & $y, 8, '&';
  check $x, 8;
  check 9 & $x, 8, '&';
  check $y & $x, 8, '&';
  check $y & 1, 1, '&';
  is !$x, '', '!';
}
{
  my $x = N 6;
  my $y = N 2;
  check $x & ~$y, 4, '& ~';
  check $x & ~2, 4, '& ~';
}
{
  my $x = N 6;
  my $y = N 2;
  check $x ^ 2, 4, '^';
  check 2 ^ $x, 4, '^ reversed';
  check $x ^ $y, 4, '^ ref';
}
{
  my $x = N 8;
  my $y = N 2;
  check $x | 2, 10, '|';
  check $x | $y, 10, '|';
  check $x, 8;
  check 2 | $x, 10, '|';
  check $y | $x, 10, '|';
  check $y | 1, 3, '|';
}
{
  my $x = N 2;
  my $y = N 4;
  check $x << 4, 32, '<<';
  check $x << $y, 32, '<<';
  check 4 << $x, 16, '<< reversed';
}
{
  my $x = N 32;
  my $y = N 2;
  check $x >> 4, 2, '>>';
  check $x >> $y, 8, '>>';
  check 32 >> $y, 8, '>> reversed';
}
{
  my $x = N 8;
  check $x + 2, 10, 'add';
  check 2 + $x, 10, 'add reversed';
  my $n = $x;
  $x++;
  check $x, 9, 'postincrement';
  ++$x;
  check $x, 10, 'preincrement';
  check ++$x, 11, 'preincrement';
  check $n, 8, 'deref';
  $x += 5;
  check $x, 16, '+=';
  is $x == 16, 1, 'equal';
  is $x == 15, '', 'equal';
  is 16 == $x, 1, 'equal';
  is 12 == $x, '', 'equal';
  is $x != 11, 1, 'non-equal';
  is $x != 16, '', 'non-equal';
  is 11 != $x, 1, 'non-equal';
  is 16 != $x, '', 'non-equal';
}
{
  my $x = N 8;
  check $x - 2, 6, 'subtract';
  check 12 - $x, 4, 'subtract reversed';
  my $n = $x;
  $x--;
  check $x, 7, 'postdecrement';
  --$x;
  check $x, 6, 'predecrement';
  check --$x, 5, 'predecrement';
  check $n, 8, 'deref';
  $x -= 3;
  check $x, 2, '-=';
  check $n - $x, 6, 'subtract ref';
}
{
  my $x = N 32;
  my $y = N 2;
  is $x > $y, 1, '>';
  is $x > 31, 1, '>';
  is 33 > $x, 1, '> reversed';
  is 32 > $x, '', 'non > reversed';
  is 31 < $x, 1, '< reversed';
  is 32 < $x, '', 'non < reversed';
  is $x > 32, '', 'non >';
  is $x < 32, '', 'non <';
  is $x <= 32, 1, '<=';
  is $x >= 32, 1, '>=';
  is $x >= 33, '', 'non >=';
  is 31 <= $x, 1, '<= reversed';
  is 32 <= $x, 1, '<= reversed';
  is 33 <= $x, '', '<= reversed';
  is 31 >= $x, '', '>= reversed';
  is 32 >= $x, 1, '>= reversed';
  is 33 >= $x, 1, '>= reversed';
  check -$x, -32, 'negate';
  check +$x, 32, '+';
}
{
  my $x = N 8;
  check $x * 2, 16, '*';
  check 2 * $x, 16, '* reversed';
}
{
  my $x = N 8;
  check $x / 2, 4, 'divide';
  check 32 / $x, 4, 'divide reversed';
}
{
  my $x = N 8;
  my $n = $x;
  $x /= 2;
  check $x, 4, 'div_equal';
  check $n, 8, 'deref';
}

# vim:ts=2:sw=2:et:sta
