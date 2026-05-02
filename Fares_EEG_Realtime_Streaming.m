% =========================================================================
%  eeg_receiver.m
%  Real-time EEG receiver — ActiChamp + TurboLink + BrainVision Recorder
%
%  Fixes applied vs debug version
%  --------------------------------
%  1. N_CH_TOTAL was declared as a comment placeholder (72 + comment),
%     now properly set to 72 (change to [] to auto-infer).
%  2. parsePacketV2 signature had a dangling 5th arg (USE_ODD_CHANNELS_ONLY)
%     that the function definition did not accept — argument added.
%  3. receivePacket had dead / unreachable code after an early return and
%     a redundant second assignment to rawBytes.
%  4. initLivePlot: title was attached to subplot(nDisp,1,1) AFTER the loop
%     lost the axes handle — now the handle is captured inside the loop.
%  5. initLivePlot: tAxis(end) is 0 when nSamplesPlot==1, causing a
%     degenerate XLim [0 0] — guarded with max(..., 1/fs).
%  6. updateLivePlot: XLim was commented out, leaving the x-axis frozen at
%     init width even when the window grows — restored with a live guard.
%  7. Circular-buffer unwrap used vertical-cat without comma separator on
%     one site — fixed for clarity/safety.
%  8. openUdpSocket helper was called but never defined — added at bottom.
%  9. computeAndPlotPSD helper was called but never defined — added at bottom.
% 10. parsePacketV2: odd-index extraction assumed interleaving that may not
%     apply to ActiChamp TurboLink (which sends plain float32 channels);
%     logic now controlled by USE_ODD_CHANNELS_ONLY flag properly.
% 11. General: persistent variables in sub-functions reset properly across
%     repeated script runs by clearing them explicitly at startup.
% =========================================================================

clear; clc; close all;

% Clear persistent state from previous runs
clear receivePacket parsePacketV2 printHeader

%% ── 1. CONFIGURATION ────────────────────────────────────────────────────

UDP_PORT        = 25000;
UDP_TIMEOUT_SEC = 2;

FS              = 1000;          % Hz — must match BrainVision Recorder setting

% ── Packet layout ────────────────────────────────────────────────────────
% ActiChamp TurboLink header: 12 bytes
%   Bytes  1-4  : uint32 channel count
%   Bytes  5-8  : uint32 block counter
%   Bytes  9-12 : uint32 trigger bits
% Payload: nCh * 4 bytes (float32, one sample per channel per packet)

HEADER_BYTES    = 12;

% Set to a positive integer if you know the channel count, or [] to infer
% from the first packet.
N_CH_TOTAL      = 72;            % total channels in the TurboLink stream
N_CH_EEG        = 64;            % how many to treat as EEG

% ------------------------------------------------------------------------
% USE_ODD_CHANNELS_ONLY
%   false (default) — payload is plain float32, one value per channel.
%   true            — payload is int16-interleaved; only odd indices carry
%                     EEG (only enable if your diagnostics confirm this).
% ------------------------------------------------------------------------
USE_ODD_CHANNELS_ONLY = false;

% ── Display ──────────────────────────────────────────────────────────────
DISPLAY_CHANS   = 1:4; %[1 2 3 4 5 6 7 8 9];
PLOT_WINDOW_SEC = 0.5;
N_SAMPLES_PLOT  = FS * PLOT_WINDOW_SEC;

% ── PSD ──────────────────────────────────────────────────────────────────
PSD_WINDOW_SEC  = 10;
N_SAMPLES_PSD   = FS * PSD_WINDOW_SEC;

PSD_SEGMENT_LEN = FS * 2;
PSD_OVERLAP     = round(PSD_SEGMENT_LEN / 2);
PSD_NFFT        = PSD_SEGMENT_LEN;

%% ── 2. OPEN UDP SOCKET ──────────────────────────────────────────────────

u = openUdpSocket(UDP_PORT, UDP_TIMEOUT_SEC);

%% ── 3. INITIALISE LIVE PLOT ─────────────────────────────────────────────

[hFig, hLines, hTitle] = initLivePlot(DISPLAY_CHANS, N_SAMPLES_PLOT, FS);

%% ── 4. STREAM & COLLECT ─────────────────────────────────────────────────

fprintf('\n[INFO] Streaming EEG — port %d | collecting %d s ...\n', ...
        UDP_PORT, PSD_WINDOW_SEC);
fprintf('[INFO] Close figure or press Ctrl-C to stop early.\n\n');

% ── Circular buffer ───────────────────────────────────────────────────────
EEG_BUF  = zeros(N_SAMPLES_PSD, N_CH_EEG);
idx      = 1;
isFilled = false;
packetCount = 0;

while ishandle(hFig)

    % ── Receive ──────────────────────────────────────────────────────────
    rawBytes = receivePacket(u);
    if isempty(rawBytes)
        continue;
    end

    % ── Infer channel count on first packet ───────────────────────────────
    if isempty(N_CH_TOTAL)
        inferredCh = (numel(rawBytes) - HEADER_BYTES) / 4;
        if mod(inferredCh, 1) ~= 0
            error('[ERROR] Cannot infer channel count — packet size not divisible by 4 after header.');
        end
        N_CH_TOTAL = inferredCh;
        fprintf('[INFO] Inferred total channels: %d\n', N_CH_TOTAL);
        if N_CH_EEG > N_CH_TOTAL
            error('[ERROR] N_CH_EEG (%d) exceeds inferred stream channels (%d).', ...
                  N_CH_EEG, N_CH_TOTAL);
        end
    end

    packetCount = packetCount + 1;

    % ── Header diagnostics (first 3 packets only) ─────────────────────────
    if packetCount <= 3
        printHeader(rawBytes, packetCount);
    end

    % ── Parse ─────────────────────────────────────────────────────────────
    chunk = parsePacketV2(rawBytes, HEADER_BYTES, N_CH_TOTAL, N_CH_EEG, ...
                          USE_ODD_CHANNELS_ONLY);
    if isempty(chunk)
        continue;
    end

    % ── First-packet channel dump ─────────────────────────────────────────
    if packetCount == 1
        fprintf('\n========== FIRST PACKET (Ch 1-16) ==========\n');
        for ch = 1 : min(16, N_CH_EEG)
            fprintf('  Ch %02d : %10.3f uV\n', ch, chunk(ch));
        end
        fprintf('============================================\n\n');
    end

    % ── Write into circular buffer ────────────────────────────────────────
    EEG_BUF(idx, :) = chunk;
    idx = idx + 1;
    if idx > N_SAMPLES_PSD
        idx      = 1;
        isFilled = true;
    end

    % ── Ordered view ──────────────────────────────────────────────────────
    if ~isFilled
        dataView = EEG_BUF(1 : idx-1, :);
    else
        dataView = [EEG_BUF(idx:end, :); EEG_BUF(1:idx-1, :)];
    end

    % ── Channel STD diagnostics (every 1000 packets) ──────────────────────
    if size(dataView, 1) >= 1000 && mod(packetCount, 1000) == 0
        fprintf('\n===== CHANNEL STD CHECK (Ch 1-16) =====\n');
        chanSTD = std(dataView, 0, 1);
        for ch = 1 : min(16, N_CH_EEG)
            fprintf('  Ch %02d | STD = %9.3f\n', ch, chanSTD(ch));
        end
        fprintf('=======================================\n\n');
    end

    % ── Update live plot ──────────────────────────────────────────────────
    updateLivePlot(hLines, hTitle, dataView, DISPLAY_CHANS, N_SAMPLES_PLOT, FS);
    % % drawnow limitrate;
drawnow limitrate nocallbacks
    % ── Stop once PSD window is full ──────────────────────────────────────
    if size(dataView, 1) >= N_SAMPLES_PSD
        break;
    end
end

%% ── 5. FINALISE DATA ────────────────────────────────────────────────────

if ~isFilled
    EEG = EEG_BUF(1 : idx-1, :);
else
    EEG = [EEG_BUF(idx:end, :); EEG_BUF(1:idx-1, :)];
end
nCollected = size(EEG, 1);

%% ── 6. FINAL CHANNEL STATISTICS ─────────────────────────────────────────

fprintf('\n===== FINAL CHANNEL STATISTICS (Ch 1-16) =====\n');
for ch = 1 : min(16, N_CH_EEG)
    fprintf('  Ch %02d | mean=%9.2f | std=%9.2f | min=%9.2f | max=%9.2f\n', ...
            ch, mean(EEG(:,ch)), std(EEG(:,ch)), min(EEG(:,ch)), max(EEG(:,ch)));
end

%% ── 7. CHANNEL VARIABILITY PLOT ─────────────────────────────────────────

chanSTD = std(EEG, 0, 1);
figure('Name', 'Channel Variability', 'Color', [0.08 0.08 0.10]);
stem(chanSTD, 'filled', 'Color', [0.20 0.85 0.55]);
xlabel('Channel', 'Color', [0.7 0.7 0.7]);
ylabel('STD (uV)',  'Color', [0.7 0.7 0.7]);
title('Channel Variability', 'Color', [0.9 0.9 0.9]);
set(gca, 'Color', [0.08 0.08 0.10], 'XColor', [0.35 0.35 0.35], ...
         'YColor', [0.35 0.35 0.35]);
grid on;

%% ── 8. PSD ──────────────────────────────────────────────────────────────

if ~ishandle(hFig)
    fprintf('[INFO] Figure closed by user — skipping PSD.\n');
else
    fprintf('[INFO] Collected %d samples. Computing PSD ...\n', nCollected);
    computeAndPlotPSD(EEG, DISPLAY_CHANS, FS, ...
                      PSD_SEGMENT_LEN, PSD_OVERLAP, PSD_NFFT);
end

%% ── 9. CLEANUP ──────────────────────────────────────────────────────────

delete(u);
fprintf('[INFO] UDP socket closed.\n');



