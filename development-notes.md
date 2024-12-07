# Development Notes

To overcome Perl and Irssi scripting related facts slipping from memory as years pass[^1], this document aims to collect some helpful tips for the *Future Self*. So, hello from 2024!

[^1]: <http://deltafunktio.animeunioni.org/dft_perl_jaakoon_sikseen.gif>

## Irssi

Irssi website: <https://irssi.org/>

General scripting instructions: <https://github.com/irssi/irssi/blob/master/docs/perl.txt>

Colors:

- <https://github.com/irssi/irssi/blob/master/docs/formats.txt>
- `%XAB` is a foreground color from the 256 color palette; *A ∈ [1, 7]*, *B ∈ [0, Z]*.

Irssi's signals:

- <https://github.com/irssi/irssi/blob/master/docs/signals.txt>
  - The signal `"message public"` is listed here. This is what we hook into for adding the coloring to it.
  - The C source code for the `sig_message_public` is in [`src/fe-common/core/fe-messages.c`](https://github.com/irssi/irssi/blob/master/src/fe-common/core/fe-messages.c#L169).
- <https://github.com/irssi/irssi/blob/master/docs/design.txt>
  - Description of the signal propagation system.
- <https://github.com/irssi/irssi/blob/master/src/core/signals.h>
  - `signal_emit`, `signal_stop`, `signal_continue` etc.

Irssi repositories:

- <https://codeberg.org/irssi/irssi>
- <https://github.com/irssi/irssi>

What's that caret (^):

- <https://irssi.org/documentation/manual/commands/>
  - "If ^ is present, command output is disabled."

## Perl

Perl website: <https://www.perl.org/>

Surprising fact: Function parameters work differently.

- Functions in Perl are subroutines.
- Any arguments passed to a subroutine call can be accessed from `@_` within the subroutine body.
- <https://stackoverflow.com/questions/19234209/perl-subroutine-arguments>

## Terminal

FUTURE: True Color support:

- <https://gist.github.com/XVilka/8346728>
- <https://github.com/termstandard/colors>
