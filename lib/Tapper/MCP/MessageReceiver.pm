package Tapper::MCP::MessageReceiver;

use AnyEvent::Socket;
use EV;
use IO::Handle;
use Moose;
use YAML::Syck;


extends 'Tapper::Base';
use Tapper::Config;
use Tapper::Model 'model';

with qw(MooseX::Daemonize);

use warnings;
use strict;

=head1 NAME

Tapper::MCP::MessageReceiver - Message receiver for Tapper MCP.

=cut

our $VERSION = '1.000.001';

=head1 SYNOPSIS


    use Tapper::MCP::MessageReceiver;

    my $daemon = Tapper::MCP::MessageReceiver->new_with_options(pidfile=>'/tmp/pid');
    $daemon->run;

=cut

=head1 METHODS

=head2 

=cut

use 5.010;

after start => sub {
        my ($self) = @_;

        return unless $self->is_daemon;
        my $port = Tapper::Config::subconfig->{mcp_port} || 1337;
        tcp_server undef, $port, sub {
                my ($fh, $host, $port) = @_;
                return unless $fh;
                my $condvar = AnyEvent->condvar;

                my $message;
                my $read_watcher; 
                $read_watcher = AnyEvent->io
                  (
                   fh   => $fh,
                   poll => 'r',
                   cb   => sub{
                           my $received_bytes = sysread $fh, $message, 1024, length $message;
                           if ($received_bytes <= 0) {
                                   undef $read_watcher;
                                   $condvar->send($message);
                           }
                   }
                  );
                my $data = $condvar->recv;
                my $yaml = YAML::Syck::Load($data);
                if ($yaml->{testrun} or $yaml->{testrun_id}) {
                        my $tr_id = $yaml->{testrun} // $yaml->{testrun_id};
                        my $db = model('TestrunDB')->resultset('Message')->new({testrun_id => $tr_id,
                                                                                message => $yaml});
                        $db->insert;
                } else {
                        $self->log->error("Received message '$data' from '$host' without testrun ID. ".
                                          "Calculating testrun IDs from host names is not yet supported.");
                }
        };
        EV::loop;

};

=head2 run

Handle daemon operations.

@return undef

=cut

sub run
{
        my ($self) = @_;
        my ($command) = @{$self->extra_argv};
        defined $command || die "No command specified";

        $self->start   if $command eq 'start';
        $self->status  if $command eq 'status';
        $self->restart if $command eq 'restart';
        $self->stop    if $command eq 'stop';

        return;
}


=head1 AUTHOR

OSRC SysInt Team, C<< <osrc-sysint at elbe.amd.com> >>



=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tapper::MCP::MessageReceiver



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 OSRC SysInt Team.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Tapper::MCP::MessageReceiver
