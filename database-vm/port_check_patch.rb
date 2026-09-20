# port_check_patch.rb
# Workaround for a host-OS socket behaviour change, not a Vagrant or vagrant-parallels bug.
#
# macOS 26.7+ reports a refused non-blocking connect by making the socket writable and recording the
# error in SO_ERROR, rather than raising an error. Ruby's Socket.tcp treats writability as
# success and returns a dead socket, so Vagrant's is_port_open? reports every port as in use. 
#
# TCPSocket.new still reports refusals correctly, so use it instead, bounded by an explicit timeout.
# This only patches hosts that actually exhibit the bug: it is a no-op elsewhere and stops applying
# once macOS or Ruby fixes this. Delete this file and its require when that happens.
require 'socket'
require 'timeout'
require 'vagrant/util/is_port_open'

# True if Socket.tcp fails to raise on a port nothing is listening on.
def connect_timeout_reports_false_positive?
  probe = TCPServer.new('127.0.0.1', 0)
  free_port = probe.addr[1]
  probe.close
  Socket.tcp('127.0.0.1', free_port, connect_timeout: 0.1).close
  true
rescue StandardError
  false
end

if connect_timeout_reports_false_positive?
  module Vagrant
    module Util
      module IsPortOpen
        def is_port_open?(host, port)
          Timeout.timeout(1) { TCPSocket.new(host, port).close }
          true
        rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH,
               Errno::EACCES, Errno::ENOTCONN, Errno::EALREADY, Timeout::Error
          false
        end
        extend self
      end
    end
  end
end