function chunk = parsePacketV2(rawBytes, headerBytes, nChTotal, nChEEG, useOddOnly)
% PARSEPACKETV2  Decode one UDP EEG packet into a [1 x nChEEG] sample.
%
%   ActiChamp TurboLink default format
%   -----------------------------------
%   Header  (12 bytes) : uint32 nCh | uint32 block | uint32 trigger
%   Payload (nCh*4 B)  : float32 values, one per channel, in channel order
%
%   If useOddOnly is true the payload is instead treated as int16-interleaved
%   and only odd-indexed int16 values are used (legacy / debug mode).

    chunk = [];

    if numel(rawBytes) <= headerBytes
        fprintf('[WARN] Packet too short (%d bytes).\n', numel(rawBytes));
        return;
    end

    payload = uint8(rawBytes(headerBytes+1 : end));

    % ── Debug print on very first call ────────────────────────────────────
    persistent printedDebug
    if isempty(printedDebug)
        fprintf('\n===== FIRST PACKET PARSE =====\n');
        fprintf('  Payload bytes : %d\n', numel(payload));

        if ~useOddOnly
            nF = floor(numel(payload) / 4);
            fprintf('  Float32 values: %d  (channels expected: %d)\n', nF, nChTotal);
        else
            if mod(numel(payload), 2) ~= 0
                fprintf('  [WARN] Payload not divisible by 2 for int16 decode.\n');
            else
                nI = numel(payload) / 2;
                fprintf('  Int16 values  : %d  (odd-only: %d)\n', nI, ceil(nI/2));
            end
        end
        printedDebug = true;
    end

    % ── Decode ────────────────────────────────────────────────────────────
    if ~useOddOnly
        % ── Standard path: plain float32 ──────────────────────────────────
        if mod(numel(payload), 4) ~= 0
            fprintf('[WARN] Payload size (%d) not divisible by 4.\n', numel(payload));
            return;
        end

        vals = double(typecast(payload, 'single'));   % float32 → double

        if length(vals) < nChEEG
            fprintf('[WARN] Only %d float32 values; need %d channels.\n', ...
                    length(vals), nChEEG);
            return;
        end

        % BrainVision Recorder streams in µV — no scaling needed
        chunk = vals(1 : nChEEG)';

    else
        % ── Legacy path: int16 interleaved ────────────────────────────────
        if mod(numel(payload), 2) ~= 0
            fprintf('[WARN] Payload size (%d) not divisible by 2 for int16.\n', numel(payload));
            return;
        end

        rawInt16 = double(typecast(payload, 'int16'));
        vals     = rawInt16(1:2:end) * 0.1;          % odd indices, scale to µV

        if length(vals) < nChEEG
            fprintf('[WARN] Only %d int16(odd) values; need %d channels.\n', ...
                    length(vals), nChEEG);
            return;
        end

        chunk = vals(1 : nChEEG)';
    end

    % ── Sanity check ──────────────────────────────────────────────────────
    if any(~isfinite(chunk))
        fprintf('[WARN] Non-finite EEG values — packet discarded.\n');
        chunk = [];
        return;
    end

    % ── Periodic range report ─────────────────────────────────────────────
    persistent pktCtr
    if isempty(pktCtr), pktCtr = 0; end
    pktCtr = pktCtr + 1;
    if mod(pktCtr, 1000) == 0
        fprintf('[DEBUG] Pkt %d | EEG range: min=%.2f max=%.2f std=%.2f uV\n', ...
                pktCtr, min(chunk), max(chunk), std(chunk));
    end
end

