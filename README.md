# What is this

Rss-actor downloads an RSS channel and acts upon the new (unseen) entries. It can be used e.g. to download content.

# Usage

    rss-actor.pl [-d|-debug] [-is|-ignoreseen] [-ne|-noexec] channel.yml

## ARGUMENTS

* -d, -debug : print debugging information. Primarily for development.
* -is, -ignoreseen : Ignore that an item was already seen, run the actions as it it wasn't seen before.
* -ne, -noexec : Do not execute actions that would execute commands. For troubleshooting.

# Configuration file format

## Top level keys

* channel: The URL of the RSS channel
* id: identifier of the channel, used e.g. to generate the "seen" file
* vars: list of global variables (see "Variables" below)
* match: list of patterns to look for in the RSS data, and actions to be executed on the matches. (see "Matches" below).

## Matches 

A "match" is basically what to look for in an RSS item, and what to do if it is found.

Keys:
* dpath: the dpath of the field in the item to check.
* regexp: the regexp to match the field to consider it an item to act upon.
* noregexp: the regexp to match the field to ignore it from being acted upon.
* vars: variables local to the match. See "Variables" below.
* do: list of actions to perform on a match. See "Actions" below.

## Actions

What to do with a match.

### Print

Prints a string.

* action: print
* print: text to print

### Exec

Executes a command.

* action: exec
* cmd: command to execute.

### Dump

Dumps the actual item (using Perl Dumper module)

* action: dump

## Variables

Variables can be either contain literal values or values extracted from the RSS data.

Fields of a variable definition:

* name: the name of the variable
* value: the value of the variable
* dpath: the dpath where the value is to be extracted from. Dpath is very similar to xpath, handled by the Data::DPath Perl module.

Either the 'value' or the 'dpath' field has to be used.

*Variable substitition*

Variable values can be substituted as %name%.

# Example configuration
    # Where to download the rss from
    channel: http://showrss.info/rss.php?user_id=9876543210&hd=1&proper=1
    # The local id of this channel. It is used to generate the name of the "seen" file.
    id: showrss
    # variables that can be referred to later.
    vars:
        - name: cmd
          value: /usr/bin/transmission-remote
        - name: mailto
          value: my@mail.address
        - name: downloaddir
          value: /data/downloads
        - name: mailbody
          value: |
            From: RSS-Actor
            Subject: Queued "%title%" for download

            Queued "%title%".
    match:
    # The dpath of the variable we want to check
        - dpath: /title
    # What to look in the title. More filtering is possible here too.
          regexp: '.'
    # Other variables that can be used
          vars:
              - name: url
                dpath: /enclosure/url
              - name: title
                dpath: /title
    # What to do if we have an unseen item
          do:
    # We just print this to the terminal
             - action: print
               print: "Downloading %title% (%url%)\n"
    # Queue it for download
             - action: exec
               cmd: [ "%cmd%", "-w", "%downloaddir%", "-a",  "%url%" ]
    # Send a mail about it
             - action: exec
               cmd: "/bin/echo '%mailbody%' | /usr/sbin/dma %mailto%"
    # This is to help figuring out which value is where
    #    - var: /title
    #      regexp: '.'
    #      do:
    #        - action: dump



# Dependencies

The following perl libraries are needed:

* TODO

# Author

István Szekeres <szekeres@iii.hu>

