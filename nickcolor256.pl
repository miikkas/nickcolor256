use strict;
use warnings;
use Irssi;
use POSIX;

# FUTURE: True Color support
# - https://gist.github.com/XVilka/8346728

our $VERSION = "256";
our %IRSSI = (
    authors     => "Miikka Salminen",
    name        => "nickcolor256",
    description => "Assign a specific color for any nicks. Based on the public domain licensed nickcolor.pl by Timo Sirainen and Ian Peters, with some modifications by Tuukka Wahtera.",
    license     => "Public Domain",
    changed     => "2016-01-09T19:27+0300"
);

# hm.. i should make it possible to use the existing one..
Irssi::theme_register([
  'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
]);

my %saved_colors;
my %saved_bgcolors;
my %altnicks;
my %session_colors;
my %session_bgcolors;
my $color_filename = "$ENV{HOME}/.irssi/saved_colors";
my $modified = 0;
my %old_to_new = (
    1 => "00", 2 => "01", 3 => "02", 4 => "0C",
    5 => "04", 6 => "05", 7 => "06", 8 => "0E",
    9 => "0A", 10 => "03", 11 => "0B", 12 => "09",
    13 => "0D", 14 => "08", 15 => "07", 0 => "0F"
    );

sub validate_color {
    my ($color) = @_;
    $color = uc $color;
    return if (length($color) != 2);
    my $fst = ord(substr($color, 0, 1));
    return if (!(ord('0') <= $fst and $fst <= ord('7')));
    my $snd = ord(substr($color, 1, 1));
    return if ($fst == ord('0') and !((ord('0') <= $snd and $snd <= ord('9')) or (ord('A') <= $snd and $snd <= ord('F'))));
    return if ((ord('1') <= $fst and $fst <= ord('6')) and !((ord('0') <= $snd and $snd<= ord('9')) or (ord('A') <= $snd and $snd <= ord('Z'))));
    return if ($fst == ord('7') and !((ord('A') <= $snd and $snd <= ord('X'))));

    return $color;
}

sub get_color_str {
    my ($color, $bgcolor, $escape_percent) = @_;

    my $color_str = "";
    if ($color) {
        $color_str .= "%" if $escape_percent == 1;
        $color_str .= "%X$color";
    }
    if ($bgcolor) {
        $color_str .= "%" if $escape_percent == 1;
        $color_str .= "%x$bgcolor";
    }
    return $color_str;
}

sub get_color {
    my ($nick) = @_;
    my ($color, $bgcolor);

    # Someone could, in theory, change their nick to someone else's altnick.
    # Therefore, prioritize session_colors over altnicks.

    $color = $saved_colors{$nick};
    $bgcolor = $saved_bgcolors{$nick};
    if (!$color) {
        # If the color is for someone who changed their nick.
        $color = $session_colors{$nick};
        $bgcolor = $session_bgcolors{$nick};
    }
    if (!$color) {
        # If this nick is someone's alternative nick.
        foreach my $altnick_owner (keys %altnicks) {
            my @current_altnicks = @{$altnicks{$altnick_owner}};
            if ($nick ~~ @current_altnicks) {
                $color = $saved_colors{$altnick_owner};
                $bgcolor = $saved_bgcolors{$altnick_owner};
            }
        }
    }
    return ($color, $bgcolor);
}

sub load_colors {
    my $file_ver;
    open COLORS, $color_filename;

    Irssi::print("\nLoading saved colors from $color_filename ...", MSGLEVEL_CLIENTCRAP);
    
    while (<COLORS>) {
        my @lines = split "\n";
        my $continue_ = 0;
        foreach my $line (@lines) {
            $continue_ = 0;
            if ($line =~ /^\$VERSION=/ && !$file_ver) {
                (undef, $file_ver) = split "=", $line;
                $continue_ = 1;
            }

            # The file was created before the introduction of the version string
            if (!$file_ver and !$continue_) {
                my ($nick, $color) = split ":", $line;
                $saved_colors{$nick} = $old_to_new{$color};
            }

            # The file supports 256 colors
            if ($file_ver and $file_ver eq "256" and !$continue_) {
                my ($nick, $color, $bgcolor, $altnicks_str) = split ":", $line;
                my $v_color = validate_color $color;
                if (!$v_color) {
                    Irssi::print("Invalid color $color for $nick! Skipping.", MSGLEVEL_CLIENTCRAP);
                } else { 
                    $saved_colors{$nick} = $v_color;

                    if ($bgcolor) {
                        my $v_bgcolor = validate_color $bgcolor;
                        if (!$v_bgcolor) {
                            Irssi::print("Invalid background color $color for $nick! Skipping.", MSGLEVEL_CLIENTCRAP);
                        } else {
                            $saved_bgcolors{$nick} = $v_bgcolor;
                        }
                    }

                    if ($altnicks_str) {
                        my @current_altnicks = split ";", $altnicks_str;
                        @{$altnicks{$nick}} = @current_altnicks;
                    }
                }
            }
        }
    }
    
    close COLORS;

    if (!$file_ver) {
        my $cmd_prefix_char = substr(Irssi::settings_get_str('cmdchars'), 0, 1);
        Irssi::print("%X0E[Nick Color notice]%n Old saved_colors file format detected.", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n The saved colors were loaded, but please check them by issuing:", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n         ${cmd_prefix_char}COLOR LIST", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n The codes for different colors have changed (and the old colors", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n have been automatically converted). To see the new codes, enter:", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n         ${cmd_prefix_char}COLOR PREVIEW", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n Save the colors to suppress this notice. To save them, enter:", MSGLEVEL_CLIENTCRAP);
        Irssi::print("%X0E[Nick Color notice]%n         ${cmd_prefix_char}COLOR SAVE", MSGLEVEL_CLIENTCRAP);
        $modified = 1;
    }
    my $total_nicks = keys %saved_colors;
    Irssi::print("Loaded colors for $total_nicks nicks!\n", MSGLEVEL_CLIENTCRAP);
}

sub save_colors {
    open COLORS, ">" . $color_filename;
    # TODO: Switch to allow saving of session_colors as altnicks

    my $total_nicks = keys %saved_colors;
    Irssi::print("\nSaving $total_nicks colored nicks to $color_filename ...", MSGLEVEL_CLIENTCRAP);

    print COLORS "\$VERSION=256\n";
    
    foreach my $nick (keys %saved_colors) {
        my $color = $saved_colors{$nick};
        $color = "" if not $color;
        my $bgcolor = $saved_bgcolors{$nick};
        $bgcolor = "" if not $bgcolor;
        my $altnicks_save = $altnicks{$nick} ? join ";", @{$altnicks{$nick}} : "";
        print COLORS "$nick:$color:$bgcolor:$altnicks_save\n";
    }

    close COLORS;

    Irssi::print("Saved!", MSGLEVEL_CLIENTCRAP);
}

sub preview_colors {
    Irssi::print ("Available colors\n", MSGLEVEL_CLIENTCRAP);

    Irssi::print ("System (will work on all 16 color terminals):", MSGLEVEL_CLIENTCRAP);
    my $base_colors = "";
    foreach my $i (0..15) {
        $base_colors .= sprintf("%%X%02X%02X ", $i, $i);
    }
    Irssi::print(substr ($base_colors, 0, -1), MSGLEVEL_CLIENTCRAP);

    Irssi::print ("\nExtended (will only work on 256 color terminals):", MSGLEVEL_CLIENTCRAP);
    foreach my $r (0..5) {
        my $color_row = "";
        foreach my $i (1..3) {
            foreach my $j (0..5) {
                my $letter = ($r * 6 + $j) > 9 ? ord("A") + ($r * 6 + $j - 10) : ord("0") + ($r * 6 + $j);
                my $colval = $i . chr($letter);
                $color_row = $color_row . sprintf("%%X%s%s ", $colval, $colval);
            }
            $color_row .= "   ";
        }
        Irssi::print(substr ($color_row, 0, -4), MSGLEVEL_CLIENTCRAP);
    }
    Irssi::print("", MSGLEVEL_CLIENTCRAP);
    foreach my $r (0..5) {
        my $color_row = "";
        foreach my $i (4..6) {
            foreach my $j (0..5) {
                my $letter = ($r * 6 + $j) > 9 ? ord("A") + ($r * 6 + $j - 10) : ord("0") + ($r * 6 + $j);
                my $colval = $i . chr($letter);
                $color_row = $color_row . sprintf("%%X%s%s ", $colval, $colval);
            }
            $color_row .= "   ";
        }
        Irssi::print(substr ($color_row, 0, -4), MSGLEVEL_CLIENTCRAP);
    }
    my $gray_colors = "";
    foreach my $i ("A".."X") {
        $gray_colors .= sprintf("%%X7%s7%s ", $i, $i);
    }
    Irssi::print("\n" . substr ($gray_colors, 0, -1), MSGLEVEL_CLIENTCRAP);
}

sub display_help_color {
    my $cmd_prefix_char = substr(Irssi::settings_get_str('cmdchars'), 0, 1);
    my $color_help = <<"END_HELP";

%_Syntax:%_

COLOR SET [-bg] <nick> <color>
COLOR SHOW <nick>
COLOR CLEAR <nick>
COLOR ADDALT <nick> <altnick>
COLOR REMALT <nick> <altnick>
COLOR LIST
COLOR PREVIEW
COLOR SAVE

%_Parameters:%_

    SET:               Sets the selected color for the nick.
    SHOW:              Shows the currently assigned color for the nick.
    CLEAR:             Clears the nick of any set color(s).
    ADDALT:            Adds an alternative nick for the nick.
    REMALT:            Removes an alternative nick of the nick.
    LIST:              Lists currently assigned colors.
    PREVIEW:           Displays the possible colors and their codes.
    SAVE:              Saves the colors that have been set to nicks.

    -bg:               The color is the background color for the nick.

%_Description:%_

    Sets user-specified colors for nicks so, that when those nicks interact on
    channels (by, e.g., talking), they are colorized with the assigned color.
    Any alternative nicks set for a nick are also colorized with the color
    assigned for that nick.

    Colors use the format specified in irssi documentation. The COLOR PREVIEW
    command can be used to display the possible color codes that can be set for
    a nick. (Notice that the leading zeros are part of the code and therefore
    must be used. I.e. ${cmd_prefix_char}COLOR SET SomeNick 5 will not work - instead of 5 use
    05.)

%_Examples:%_

    ${cmd_prefix_char}COLOR
    ${cmd_prefix_char}COLOR PREVIEW
    ${cmd_prefix_char}COLOR SET MyBot 2W
    ${cmd_prefix_char}COLOR SHOW MyBot
    ${cmd_prefix_char}COLOR SET -bg MyBot 46
    ${cmd_prefix_char}COLOR ADDALT SomeFriend SomeFriend_
    ${cmd_prefix_char}COLOR REMALT SomeFriend SomeFriend2
    ${cmd_prefix_char}COLOR LIST
    ${cmd_prefix_char}COLOR CLEAR MyBot
    ${cmd_prefix_char}COLOR SAVE

%_See also:%_ CNICKS
END_HELP
    Irssi::print($color_help, MSGLEVEL_CLIENTCRAP);
}

sub display_help_cnicks {
    my $cmd_prefix_char = substr(Irssi::settings_get_str('cmdchars'), 0, 1);
    my $cnicks_help = <<"END_HELP";

%_Syntax:%_

CNICKS

%_Description:%_

    Like the internal NAMES command, but displays the nicks with the colors
    they have been assigned with the COLOR command in the Nick Color 256
    script.

    The default alias of N to NAMES can be overwritten to allow the user to
    easily use CNICKS instead. The Irssi configuration should be saved
    after settings the alias (default command ${cmd_prefix_char}SAVE). 

%_Examples:%_

    ${cmd_prefix_char}CNICKS
    ${cmd_prefix_char}ALIAS N CNICKS

%_See also:%_ COLOR
END_HELP
    Irssi::print($cnicks_help, MSGLEVEL_CLIENTCRAP);
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
    my ($server, $newnick, $nick, $address) = @_;
    my $color;

    $newnick = substr ($newnick, 1) if ($newnick =~ /^:/);

    # TODO: Take into account the case where someone changes their nick from/to
    # their altnick.

    if ($color = $saved_colors{$nick}) {
        $session_colors{$newnick} = $color;
    } elsif ($color = $session_colors{$nick}) {
        $session_colors{$newnick} = $color;
    }
}

# FIXME: breaks /HILIGHT etc.
sub sig_public {
    my ($server, $msg, $nick, $address, $target) = @_;
    my $chanrec = $server->channel_find($target);
    return if not $chanrec;
    my $nickrec = $chanrec->nick_find($nick);
    return if not $nickrec;
    my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

    # Does this nick have an assigned color?
    my ($color, $bgcolor) = get_color $nick;

    # Let's colorize this nick (or use the default color if no color found).
    # TODO: Get the definitions from theme and inject the color into the string. 
    if (!$color) {
        $server->command('/^format pubmsg {pubmsgnick $2 {pubnick $0}}$1');
    } else {
        my $color_str = get_color_str $color, $bgcolor, 0;
        $server->command('/^format pubmsg {pubmsgnick $2 {pubnick ' . $color_str . '$0}}$1');
    }
}

sub cmd_color {
    my ($data, $server, $witem) = @_;
    my ($op, $nick, $color, $fourth) = split " ", $data;
    my $altnick = $color;
    my $cmd_prefix_char = substr(Irssi::settings_get_str('cmdchars'), 0, 1);

    $op = lc $op;

    if (!$op) {
        display_help_color;
    } elsif ($op eq "save") {
        save_colors;
        $modified = 0;
    } elsif ($op eq "set") {
        if (!$nick) {
            Irssi::print ("Nick not given", MSGLEVEL_CLIENTCRAP);
        } elsif ($nick eq '-bg') {
            $nick = $color;
            $color = $fourth;

            if (!$nick) {
                Irssi::print ("Nick not given", MSGLEVEL_CLIENTCRAP);
            } elsif (!$color) {
                Irssi::print ("Color not given", MSGLEVEL_CLIENTCRAP);
            } else {
                # BACKGROUND
                my $v_bgcolor = validate_color $color;
                if (!$v_bgcolor) {
                    Irssi::print("\n$color is not a valid color code.", MSGLEVEL_CLIENTCRAP);
                    Irssi::print("To see the available color codes, enter ${cmd_prefix_char}COLOR PREVIEW", MSGLEVEL_CLIENTCRAP);
                } else {
                    $saved_bgcolors{$nick} = $v_bgcolor;
                    $modified = 1;
                    Irssi::print("\nNow set: %x$saved_bgcolors{$nick}$nick%n    ($saved_bgcolors{$nick})", MSGLEVEL_CLIENTCRAP);
                    Irssi::print("To save changed color assignments, enter ${cmd_prefix_char}COLOR SAVE", MSGLEVEL_CLIENTCRAP);
                }
            }
        } elsif (!$color) {
            Irssi::print ("Color not given", MSGLEVEL_CLIENTCRAP);
        } else {
            # FOREGROUND
            my $v_color = validate_color $color;
            if (!$v_color) {
                Irssi::print("\n$color is not a valid color code.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("To see the available color codes, enter ${cmd_prefix_char}COLOR PREVIEW", MSGLEVEL_CLIENTCRAP);
            } else {
                $saved_colors{$nick} = $v_color;
                $modified = 1;
                Irssi::print("\nNow set: %X$saved_colors{$nick}$nick%n    ($saved_colors{$nick})", MSGLEVEL_CLIENTCRAP);
                Irssi::print("To save changed color assignments, enter ${cmd_prefix_char}COLOR SAVE", MSGLEVEL_CLIENTCRAP);
            }
        }
    } elsif ($op eq "show") {
        if (!$nick) {
            Irssi::print ("Nick not given", MSGLEVEL_CLIENTCRAP);
        } else {
            my $this_color = $saved_colors{$nick};
            my $this_bg = $saved_bgcolors{$nick};
            my $color_str = get_color_str $this_color, $this_bg, 0;
            if (!$this_color) {
                Irssi::print("\n$nick has not been assigned any color.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("To assign a color for $nick, enter ${cmd_prefix_char}COLOR SET $nick <colorcode>", MSGLEVEL_CLIENTCRAP);
            } else {
                my $color_codes = $this_bg ? "$this_color, background: $this_bg" : "$this_color";
                Irssi::print("\nCurrent: $color_str$nick%n    ($color_codes)", MSGLEVEL_CLIENTCRAP);
                my $example = Irssi::current_theme()->format_expand("{pubmsg {pubmsgnick @ {pubnick $color_str$nick}}Some filler text here. Come up with something better later. :)}");
                Irssi::print("Example: $example%n", MSGLEVEL_CLIENTCRAP);
            }
        }
    } elsif ($op eq "addalt") {
        if (!$nick) {
            Irssi::print("Nick not given", MSGLEVEL_CLIENTCRAP);
        } elsif (!$altnick) {
            Irssi::print("Alternative nick not given", MSGLEVEL_CLIENTCRAP);
        } else {
            my $this_color = $saved_colors{$nick};
            if (!$this_color) {
                Irssi::print("\n$nick has not been assigned any color.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("Assign a color for $nick first: enter ${cmd_prefix_char}COLOR SET $nick <colorcode>", MSGLEVEL_CLIENTCRAP);
            } else {
                if ($altnick ~~ @{$altnicks{$nick}}) {
                    Irssi::print("\n$nick already has the alternative nick $altnick!", MSGLEVEL_CLIENTCRAP);
                } else {
                    push @{$altnicks{$nick}}, $altnick;
                    Irssi::print("\n$altnick has been added as an alternative nick for $nick.", MSGLEVEL_CLIENTCRAP);
                }
            }
        }
    } elsif ($op eq "remalt") {
        if (!$nick) {
            Irssi::print("Nick not given", MSGLEVEL_CLIENTCRAP);
        } elsif (!$altnick) {
            Irssi::print("Alternative nick not given", MSGLEVEL_CLIENTCRAP);
        } else {
            my $this_color = $saved_colors{$nick};
            if (!$this_color) {
                Irssi::print("\n$nick has not been assigned any color.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("Assign a color for $nick first: enter ${cmd_prefix_char}COLOR SET $nick <colorcode>", MSGLEVEL_CLIENTCRAP);
            } else {
                if ($altnick ~~ @{$altnicks{$nick}}) {
                    my $index = 0;
                    $index++ until @{$altnicks{$nick}}[$index] eq $altnick;
                    splice(@{$altnicks{$nick}}, $index, 1);
                    if (!@{$altnicks{$nick}}) {
                        delete ($altnicks{$nick});
                    }
                    Irssi::print("\n$altnick removed from alternative nicks of $nick.", MSGLEVEL_CLIENTCRAP);
                } else {
                    Irssi::print("\n$nick doesn't have an alternative nick $altnick!", MSGLEVEL_CLIENTCRAP);
                }
            }
        }
    } elsif ($op eq "clear") {
        if (!$nick) {
            Irssi::print ("Nick not given", MSGLEVEL_CLIENTCRAP);
        } else {
            my $this_color = $saved_colors{$nick};
            my $this_bg = $saved_bgcolors{$nick};
            my $color_str = get_color_str $this_color, $this_bg, 0;
            if (!$this_color) {
                Irssi::print("\n$nick has not been assigned any color.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("No color assignment cleared.", MSGLEVEL_CLIENTCRAP);
            } else {
                delete ($saved_colors{$nick});
                delete ($saved_bgcolors{$nick});
                $modified = 1;
                my $color_codes = $this_bg ? "$this_color, background: $this_bg" : "$this_color";
                Irssi::print("\nColor assignment $color_str($color_codes)%n for $nick cleared.", MSGLEVEL_CLIENTCRAP);
                Irssi::print("To save changed color assignments, enter ${cmd_prefix_char}COLOR SAVE", MSGLEVEL_CLIENTCRAP);
            }
        }
    } elsif ($op eq "list") {
        Irssi::print("\nNick to color mappings\n", MSGLEVEL_CLIENTCRAP);
        if ($modified) {
            Irssi::print("Colors have been modified since last save!\n" .
                         "To save the current colors, enter ${cmd_prefix_char}COLOR SAVE\n", MSGLEVEL_CLIENTCRAP);
        }
        Irssi::print(sprintf("%-20s%-6s%-11s%s", "Nick", "Color", "Background", "Alternative nicks"), MSGLEVEL_CLIENTCRAP);
        foreach my $nick (sort {lc $a cmp lc $b} keys %saved_colors) {
            my $this_color = $saved_colors{$nick};
            my $this_bg = $saved_bgcolors{$nick};
            my $color_str = get_color_str $this_color, $this_bg, 1;
            $this_bg = "-" if not $this_bg;
            my $this_altnicks;
            if ($altnicks{$nick}) {
                my @temp_altnicks;
                foreach my $anick (@{$altnicks{$nick}}) {
                    push @temp_altnicks, sprintf("$color_str$anick%%n");
                }
                $this_altnicks = join(", ", @temp_altnicks);
            } else {
                $this_altnicks = "-";
            }
            Irssi::print(sprintf("$color_str%-22s%-6s%-11s%s", $nick . "%n",
                         $this_color, $this_bg, $this_altnicks), MSGLEVEL_CLIENTCRAP);
        }
    } elsif ($op eq "preview") {
        preview_colors;
    }
}

sub cmd_cnicks {
    my ($data, $server, $witem) = @_;

    if (!$witem || ($witem->{type} ne "CHANNEL")) {
        Irssi::print("The active window is not a channel.");
        return;
    }

    my @prefixes = split "", $server->get_nick_flags();
    my ($prefix_op, $prefix_voice, $prefix_halfop) = @prefixes;

    my $chanops = 0;
    my $chanvoices = 0;
    my $chanhalfops = 0;
    my $channormals = 0;

    my $own_nick = $server->{nick};

    my $channel = $witem;

    my @nicks = $channel->nicks();
    my $nick_count = scalar(@nicks);
    my $column_count = $nick_count >= 6 ? 6 : $nick_count;
    my %column = ();
    my %column_width = ();
    my $max_per_column = ceil($nick_count / $column_count);
    my $i = 0;
    my $col = 0;
    my $this_column;
    my $width = 0;

    # FIXME: Users with BOTH ops and voices currently go in front...
    $channel->print("Users of $channel->{name}:", MSGLEVEL_CLIENTCRAP);
    foreach my $nick_data (sort { $b->{op} <=> $a->{op}           or
                                  $b->{halfop} <=> $a->{halfop}   or
                                  $b->{voice} <=> $a->{voice}     or
                                  lc $a->{nick} cmp lc $b->{nick}
                           } $channel->nicks()) {
        if ($i == 0) {
            $this_column = [];
        }
        my $nickmode;
        if ($nick_data->{op}) {
            $nickmode = $prefix_op;
            $chanops += 1;
        } elsif ($nick_data->{halfop}) {
            $nickmode = $prefix_halfop;
            $chanhalfops += 1;
        } elsif ($nick_data->{voice}) {
            $nickmode = $prefix_voice;
            $chanvoices += 1;
        } else {
            $nickmode = " ";
            $channormals += 1;
        }
        
        my $nick = $nickmode . $nick_data->{nick};

        push(@$this_column, $nick);

        $width = length($nick) > $width ? length($nick) : $width;

        $i += 1;
        if ($i == $max_per_column) {
            $i = 0;
            @{$column{"col$col"}} = @$this_column;
            $column_width{"col$col"} = $width;
            $col += 1;
            $width = 0;
            $this_column = [];
        }
    }

    if (scalar(@$this_column)) {
        @{$column{"col$col"}} = @$this_column;
        $column_width{"col$col"} = $width;
    }

    my $realcolcount = scalar(keys %column);
    for my $j (0..$max_per_column - 1) {
        my $line = "";
        
        for my $current_column (0..$realcolcount - 1) {
            my $c_col = $column{"col$current_column"};
            my $c_width = $column_width{"col$current_column"};
            
            if ($j < scalar(@$c_col)) {
                my $c_nick = @$c_col[$j];
                my $nickmode = substr $c_nick, 0, 1;
                my $nick = substr $c_nick, 1;
                my ($color, $bgcolor) = get_color $nick;
                my $formatted_nick;

                my $new_entry;
                if (!$color) {
                    if ($nick eq $own_nick) {
                        # https://github.com/shabble/irssi-docs/wiki/Irssi#Themes
                        $formatted_nick = Irssi::current_theme()->format_expand("{ownnick}$nickmode$nick") . "%n";
                        $c_width = $c_width + ((length $formatted_nick) - (length $c_nick));
                    } else {
                        $formatted_nick = $c_nick;
                    }
                    $new_entry = sprintf "[%-${c_width}s] ", $formatted_nick;
                } else {
                    my $ncolor = get_color_str $color, $bgcolor, 0;
                    $formatted_nick = $nickmode . $ncolor . $nick . "%n";
                    my $adj_width = $c_width + ((length $formatted_nick) - (length $c_nick));
                    $new_entry = sprintf "[%-${adj_width}s] ", $formatted_nick;
                }
                $line .= $new_entry;
            }
        }
        $channel->print(substr($line, 0, -1), MSGLEVEL_CLIENTCRAP);
    }
    
    $channel->print($channel->{name} . ": Total of $nick_count nicks [$chanops ops, $chanhalfops halfops, $chanvoices voices, $channormals normal]", MSGLEVEL_CLIENTCRAP);
}

load_colors;

my $BASE_CMD = 'color';
Irssi::command_bind("$BASE_CMD set", \&cmd_color);
Irssi::command_bind("$BASE_CMD show", \&cmd_color);
Irssi::command_bind("$BASE_CMD clear", \&cmd_color);
Irssi::command_bind("$BASE_CMD addalt", \&cmd_color);
Irssi::command_bind("$BASE_CMD remalt", \&cmd_color);
Irssi::command_bind("$BASE_CMD list", \&cmd_color);
Irssi::command_bind("$BASE_CMD preview", \&cmd_color);
Irssi::command_bind("$BASE_CMD save", \&cmd_color);
Irssi::command_bind($BASE_CMD, \&cmd_color);
Irssi::command_bind('cnicks', \&cmd_cnicks);

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('event nick', 'sig_nick');

Irssi::command_bind('help', sub {
    my $cmd = lc $_[0];
    $cmd =~ s/^\s+|\s+$//g; # Strip whitespace
    if ($cmd eq 'color') {
        display_help_color;
        Irssi::signal_stop;
    } elsif ($cmd eq 'cnicks') {
        display_help_cnicks;
        Irssi::signal_stop;
    }
});

Irssi::signal_add_first('complete word', sub {
    # Add autocomplete for nicks when using the COLOR command
    
    my ($strings, $window, $word, $linestart, $want_space) = @_;
    return if ($linestart eq '');
    my $cmd_prefix_chars = Irssi::settings_get_str('cmdchars');
    return if (index($cmd_prefix_chars, substr($linestart, 0, 1)) == -1);

    # Ensure we are dealing with the COLOR command
    # and the SET, SHOW or CLEAR subcommand
    
    my ($color_cmd, $color_subcmd, $bgswitch) = split " ", $linestart;
    return if (!$color_cmd or !$color_subcmd);
    $color_cmd = lc $color_cmd;
    $color_subcmd = lc $color_subcmd;
    return unless (substr($color_cmd, 1) eq 'color' and
                   ($color_subcmd eq 'set' or
                    $color_subcmd eq 'show' or
                    $color_subcmd eq 'clear' or
                    $color_subcmd eq 'addalt' or
                    $color_subcmd eq 'remalt'));

    # Add those nicks that start with what the user has already written

    if ($color_subcmd eq 'remalt' and !$bgswitch) {
        push @$strings, (grep(/^$word/i, keys %altnicks));
    } elsif ($color_subcmd eq 'remalt' and $bgswitch) {
        push @$strings, (grep(/^$word/i, @{$altnicks{$bgswitch}}));
    } else {
        push @$strings, (grep(/^$word/i, keys %saved_colors));
    }

    if ($color_subcmd eq 'set') {
        # Add the optional background switch
        push(@$strings, '-bg') if (!$bgswitch and '-bg' =~ /^$word/i);
        
        if ($window->{active} && ($window->{active}->{type} eq "CHANNEL")) {
            # Add the nicks from the currently open channel, if the window is a
            # channel and if the user is assigning a new nick a color
            my $channel = $window->{active};
            foreach my $nick_data ($channel->nicks()) {
                my $nick = $nick_data->{nick};

                if ($nick =~ /^$word/i and !(grep {$_ eq $nick} @$strings)) { 
                    push(@$strings, $nick);
                }
            }
        } elsif ($window->{active} && ($window->{active}->{type} eq "QUERY")) {
            # Add the nick from the currently open query, if the window is a
            # query and if the user is assigning a new nick a color
            my $query = $window->{active};
            my $nick = $query->{name};
            if ($nick =~ /^$word/i and !(grep {$_ eq $nick} @$strings)) { 
                push(@$strings, $nick);
            }
        }
    }

    @$strings = sort {lc $a cmp lc $b} @$strings;

    Irssi::signal_stop;
});
