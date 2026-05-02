function u = openUdpSocket(port, timeoutSec)
% OPENUDPSOCKET  Create UDP socket (udpport compatible version-safe)

    fprintf('[INFO] Opening UDP socket on port %d ...\n', port);

    u = udpport('datagram', 'IPV4', ...
                'LocalPort', port, ...
                'Timeout', timeoutSec);

    fprintf('[INFO] Socket open.\n');
end