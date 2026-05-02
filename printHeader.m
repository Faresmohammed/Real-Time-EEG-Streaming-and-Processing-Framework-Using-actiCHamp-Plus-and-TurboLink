
function printHeader(rawBytes, packetNum)
% PRINTHEADER  Decode and validate the 12-byte TurboLink packet header.

    persistent prevBlock warnedMismatch

    if numel(rawBytes) < 12
        fprintf('[WARN] Packet #%d too short for 12-byte header (%d bytes)\n', ...
                packetNum, numel(rawBytes));
        return;
    end

    nCh      = double(typecast(rawBytes(1:4),  'uint32'));
    blockNum = double(typecast(rawBytes(5:8),  'uint32'));
    trigger  = typecast(rawBytes(9:12), 'uint32');

    % Continuity check
    if ~isempty(prevBlock) && blockNum ~= prevBlock + 1
        fprintf('[WARN] Block discontinuity: expected %d, got %d (dropped %d)\n', ...
                prevBlock+1, blockNum, blockNum - prevBlock - 1);
    end
    prevBlock = blockNum;

    % Size check
    actualBytes   = numel(rawBytes);
    expectedBytes = 12 + nCh * 4;

    fprintf('[HDR] Pkt #%d  |  nCh=%d  block=%d  trigger=0x%08X  |  %d bytes\n', ...
            packetNum, nCh, blockNum, trigger, actualBytes);

    if isempty(warnedMismatch)
        if actualBytes ~= expectedBytes
            inferredCh = (actualBytes - 12) / 4;
            fprintf(['[WARN] Size mismatch:\n' ...
                     '       Header says %d ch  -> expects %d bytes\n' ...
                     '       Actual packet = %d bytes  -> implies %.1f float32 ch\n' ...
                     '       Update N_CH_TOTAL if %.0f is correct.\n'], ...
                     nCh, expectedBytes, actualBytes, inferredCh, inferredCh);
        else
            fprintf('[INFO] Packet size consistent with header.\n');
        end
        warnedMismatch = true;
    end
end


function probePackets(u, nPackets, nChannels)
% PROBEPACKETS  Capture packets and print a full diagnostic byte/float map.
%   Useful for identifying HEADER_BYTES when the format is unknown.
%   Run this INSTEAD of the main loop by calling it just after openUdpSocket.

    for p = 1 : nPackets
        fprintf('--- Packet %d ---\n', p);
        rawBytes = [];
        while isempty(rawBytes)
            rawBytes = receivePacket(u);
        end

        nBytes = numel(rawBytes);
        fprintf('Total bytes: %d\n\n', nBytes);

        % Hex dump of first 64 bytes
        nHex = min(64, nBytes);
        fprintf('Hex dump (first %d bytes):\n', nHex);
        for i = 1 : nHex
            fprintf('%02X ', rawBytes(i));
            if mod(i, 16) == 0, fprintf('\n'); end
        end
        fprintf('\n\n');

        % Try every 4-byte-aligned offset as potential EEG data start
        fprintf('%-10s %-10s %-10s  %s\n', 'Offset','Floats','ChFit','First 4 float32 values');
        for offset = 0 : 4 : min(60, nBytes-16)
            remaining = nBytes - offset;
            nF = floor(remaining / 4);
            if nF < nChannels, continue; end

            vals  = double(typecast(rawBytes(offset+1 : offset+nF*4), 'single'));
            nValid = sum(abs(vals(1:nChannels)) < 2000 & isfinite(vals(1:nChannels)));
            chFit  = mod(nF, nChannels) == 0;

            marker = '';
            if nValid > nChannels*0.8 && chFit
                marker = '  <-- LIKELY EEG START';
            end

            fprintf('%-10d %-10d %-10s  [%8.2f  %8.2f  %8.2f  %8.2f]%s\n', ...
                    offset, nF, mat2str(chFit), ...
                    vals(1), vals(2), vals(3), vals(4), marker);
        end
        fprintf('\n');
    end

    fprintf('[PROBE] Set HEADER_BYTES to the offset marked "<-- LIKELY EEG START".\n\n');
end