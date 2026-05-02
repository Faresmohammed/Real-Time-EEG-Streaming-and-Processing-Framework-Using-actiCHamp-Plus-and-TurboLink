
function computeAndPlotPSD(EEG, displayChans, fs, segLen, overlap, nfft)
% COMPUTEANDPLOTPSD  Welch PSD for selected channels in a dark-themed figure.

    nCh  = numel(displayChans);
    freqs = (0 : nfft/2) * (fs / nfft);

    figure('Name', 'Power Spectral Density', ...
           'Color', [0.08 0.08 0.10], ...
           'Units', 'normalized', 'OuterPosition', [0 0 1 1]);

    colors = lines(nCh);

    for k = 1 : nCh
        ch   = displayChans(k);
        sig  = EEG(:, ch);

        % Welch estimate
        [pxx, ~] = pwelch(sig, hann(segLen), overlap, nfft, fs);

        ax = subplot(nCh, 1, k);
        plot(ax, freqs, 10*log10(pxx), 'Color', colors(k,:), 'LineWidth', 0.9);

        ylabel(ax, sprintf('Ch %d\n(dB/Hz)', ch), ...
               'Color', [0.65 0.65 0.65], 'FontSize', 7);

        set(ax, 'XLim',      [0, 100], ...  % 0-100 Hz display range
                'Color',     [0.08 0.08 0.10], ...
                'XColor',    [0.35 0.35 0.35], ...
                'YColor',    [0.35 0.35 0.35], ...
                'GridColor', [0.20 0.20 0.20], ...
                'YGrid', 'on', 'XGrid', 'on', 'FontSize', 7);

        if k < nCh
            set(ax, 'XTickLabel', []);
        else
            xlabel(ax, 'Frequency (Hz)', 'Color', [0.7 0.7 0.7]);
        end
    end

    subplot(nCh, 1, 1);
    title('Welch PSD', 'Color', [0.9 0.9 0.9], 'FontSize', 10);
end

