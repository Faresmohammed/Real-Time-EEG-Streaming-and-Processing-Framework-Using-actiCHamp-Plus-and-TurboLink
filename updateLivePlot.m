
function updateLivePlot(hLines, hTitle, EEG, displayChans, nSamplesPlot, fs)

    nTotal   = size(EEG, 1);
    startIdx = max(1, nTotal - nSamplesPlot + 1);
    window   = EEG(startIdx:end, :);

    nWin  = size(window, 1);
    tAxis = (0 : nWin-1) / fs;
    tMax  = max(tAxis(end), 1/fs);

    for k = 1 : numel(displayChans)

        ch = displayChans(k);
        trace = window(:, ch)';

        % ===== SAFE DC REMOVAL =====
        if numel(trace) > 20
            trace = trace - mean(trace);
        end

        ax = ancestor(hLines(k), 'axes');

        set(hLines(k), 'XData', tAxis, 'YData', trace);

        % ===== FAST ARTIFACT-RESPONSIVE SCALING =====
        yRange = prctile(abs(trace), 99);
        yRange = max(yRange, 10);
        yRange = min(yRange, 150);

        set(ax, 'XLim', [0, tMax], ...
                'YLim', [-yRange yRange]);
    end

    set(hTitle, 'String', sprintf('Live EEG | %.1f s | %d samples', ...
        nTotal/fs, nTotal));
end
% % % function updateLivePlot(hLines, hTitle, EEG, displayChans, nSamplesPlot, fs)
% % % % UPDATELIVEPLOT - REAL-TIME EEG WITH ARTIFACT VISIBILITY (OSCILLOSCOPE MODE)
% % % 
% % %     nTotal   = size(EEG, 1);
% % %     startIdx = max(1, nTotal - nSamplesPlot + 1);
% % %     window   = EEG(startIdx:end, :);
% % % 
% % %     nWin  = size(window, 1);
% % %     tAxis = (0:nWin-1) / fs;
% % %     tMax  = max(tAxis(end), 1/fs);
% % % 
% % %     for k = 1 : numel(displayChans)
% % % 
% % %         ch = displayChans(k);
% % % 
% % %         % ============================================================
% % %         % RAW SIGNAL (DO NOT FILTER IF YOU WANT ARTIFACTS)
% % %         % ============================================================
% % %          % % trace = window(:, ch)';
% % % 
% % %          % trace = detrend(window(:, ch)');
% % % 
% % % 
% % % 
% % % 
% % % 
% % %          trace = window(:, ch)';
% % % 
% % % if numel(trace) > 20
% % %     trace = trace - mean(trace);
% % % end
% % % 
% % %         % OPTIONAL: uncomment this ONLY if you want DC removed
% % %         % trace = trace - mean(trace);
% % % % % if max(abs(trace)) > 200
% % % % %     disp('ARTIFACT SPIKE DETECTED');
% % % % % else 
% % % % %     disp('NO ARTIFACT SPIKE DETECTED');
% % % % % end
% % %         ax = ancestor(hLines(k), 'axes');
% % % 
% % %         set(hLines(k), 'XData', tAxis, 'YData', trace);
% % % 
% % %         % ============================================================
% % %         % AGGRESSIVE VISIBILITY SCALING (KEY FIX)
% % %         % ============================================================
% % %         % % sigma = std(trace);
% % %         % % 
% % %         % % if ~isfinite(sigma) || sigma < 1e-6
% % %         % %     yRange = 50;
% % %         % % else
% % %         % %     yRange = max(80, 8 * sigma);   % <<< more sensitive than before
% % %         % % end
% % % 
% % %         % allow big jumps to actually appear
% % %         % yRange = min(yRange, 2000);
% % % % % yRange = 150;
% % % 
% % % 
% % % yRange = 3 * prctile(abs(trace), 99);
% % % yRange = max(yRange, 20);
% % % yRange = min(yRange, 150);
% % % 
% % %         % ============================================================
% % %         % IMPORTANT: ENABLE AXIS UPDATE (WAS DISABLED BEFORE)
% % %         % ============================================================
% % %         set(ax, 'XLim', [0, tMax], ...
% % %                 'YLim', [-yRange, yRange]);
% % % 
% % %     end
% % % 
% % %     elapsed = nTotal / fs;
% % % 
% % %     set(hTitle, 'String', sprintf( ...
% % %         'Live EEG | %.1f s | samples: %d | RAW MODE (artifact visible)', ...
% % %         elapsed, nTotal));
% % % end
% % % 

% % % 
% % % function updateLivePlot(hLines, hTitle, EEG, displayChans, nSamplesPlot, fs)
% % % % UPDATELIVEPLOT  Refresh the rolling EEG traces with the most recent samples.
% % % %
% % % %   FIX: XLim update was commented out, leaving the x-axis at its initial
% % % %        width even as the window grew.  Restored with a proper live guard.
% % % 
% % %     nTotal   = size(EEG, 1);
% % %     startIdx = max(1, nTotal - nSamplesPlot + 1);
% % %     window   = EEG(startIdx:end, :);
% % % 
% % %     nWin  = size(window, 1);
% % %     tAxis = (0 : nWin-1) / fs;
% % %     tMax  = max(tAxis(end), 1/fs);
% % % 
% % %     for k = 1 : numel(displayChans)
% % %         ch    = displayChans(k);
% % %           trace = window(:, ch)';
% % %          % trace = window(:, ch)' - mean(window(:, ch));
% % % 
% % % % % % trace = trace - mean(window, 2)'; common average
% % %         ax = ancestor(hLines(k), 'axes');
% % % 
% % %         set(hLines(k), 'XData', tAxis, 'YData', trace);
% % % 
% % %         % Adaptive Y-limits: ±3σ, clamped to sensible EEG bounds
% % %         sigma = std(trace);
% % % 
% % % if ~isfinite(sigma) || sigma < 1e-6
% % %     yRange = 20;
% % % else
% % %     yRange = 5 * sigma;   % stronger scaling for visibility
% % % end
% % % 
% % % yRange = min(max(5*std(trace), 20), 200);
% % % 
% % % % yRange = min(max(yRange, 20), 200);  % clamp for EEG realism
% % % 
% % %         % % sigma = std(trace);
% % %         % % if ~isfinite(sigma) || sigma < 1e-6
% % %         % %     yRange = 50;
% % %         % % else
% % %         % %     yRange = min(max(3 * sigma, 50), 3000);
% % %         % % end
% % %         % % 
% % %         % % set(ax, 'XLim', [0, tMax], ...
% % %         % %         'YLim', [-yRange, yRange]);
% % %     end
% % % 
% % %     elapsed = nTotal / fs;
% % %     set(hTitle, 'String', sprintf('Live EEG  |  %.1f s collected  |  %d samples', ...
% % %                                    elapsed, nTotal));
% % % end
% % % 
