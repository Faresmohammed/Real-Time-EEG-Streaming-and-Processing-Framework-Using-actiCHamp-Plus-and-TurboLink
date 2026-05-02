
function rawBytes = receivePacket(u)
% RECEIVEPACKET  Read one UDP datagram; return uint8 payload or [] on timeout.
%
%   FIX: previous version had dead code after an early return and assigned
%   rawBytes twice.  Simplified to a single read path.

    rawBytes = [];

    try
        if u.NumDatagramsAvailable == 0
            return;                          % nothing waiting — caller will retry
        end

        pkt = read(u, 1, 'uint8');           % read exactly one datagram

        if ~isempty(pkt)
            rawBytes = uint8(pkt(1).Data(:)');
        end

    catch ME
        if ~contains(lower(ME.message), 'timeout')
            fprintf('[WARN] receivePacket: %s\n', ME.message);
        end
    end
end

