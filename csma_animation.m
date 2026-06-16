function csma_animation()
% =========================================================================
% FILE: csma_animation.m
% Mo phong TRUC QUAN (animation) giao thuc CSMA/CD cho ca 2 kich ban.
%
% Triet ly thiet ke:
%   1) TAI SU DUNG ENGINE GOC: file goi config() va dung lai nguyen ven cac
%      ham create_packet.m, execute_backoff.m, dijkstra.m. Vong lap su kien
%      duoc sao lai dung logic cua csma_cd_single.m / csma_cd_multi.m nhung
%      co ghi lai "nhat ky su kien" (event trace) de phat lai dang animation.
%      => Doi tham so trong config.m (lambda, td, pd, maxbackoff...) thi
%         animation va so lieu deu thay doi theo, khop voi ban goc.
%
%   2) PHAT LAI (replay): GUI ve Bus + cac nut + Router, hien thi:
%        - Goi tin di chuyen tren Bus + va cham (collision)
%        - Qua trinh Back-off (dem va cham k, thoi gian cho)
%        - Dinh tuyen qua Router (kich ban 4 nut)
%        - So lieu real-time (so goi thanh cong, va cham, throughput, tre)
%      Co nut Tam dung/Tiep tuc, Reset va thanh truot dieu chinh toc do.
%
% CACH DUNG: dat file canh main.m roi go:  csma_animation
% =========================================================================

    % ---- Lua chon kich ban (giong main.m) ----
    % kich_ban = 1 : Mang don doan (2 nut A, B chung Bus)
    % kich_ban = 2 : Mang da doan (4 nut, 2 Bus, dinh tuyen qua Router)
    kich_ban = 2;

    % ---- (Tuy chon) tai lap ngau nhien de chup hinh cho bao cao ----
    % De rong [] -> moi lan chay khac nhau (rng shuffle).
    % Vi du dat SEED = 42; de tai lap dung 1 ket qua.
    SEED = [];

    % ---- Gioi han so su kien dem animation (de xem cho de) ----
    % Engine van chay TOAN BO; chi phan PHAT LAI bi gioi han o so nay.
    % So lieu tong ket cuoi cung van tinh tren toan bo lan chay.
    ANIM_MAX_EVENTS = 500;

    % =====================================================================
    % 0. CHUAN BI MOI TRUONG
    % =====================================================================
    addpath('src', 'utils');   % dung lai cac ham trong project
    if ~isempty(SEED), rng(SEED); else, rng('shuffle'); end
    cfg = config();

    fprintf('==================================================\n');
    fprintf('   ANIMATION MO PHONG CSMA/CD\n');
    fprintf('   Kich ban %d | lambda=%.2f | td=%d pd=%d | maxbackoff=%d\n', ...
            kich_ban, cfg.lambda, cfg.td, cfg.pd, cfg.maxbackoff);
    fprintf('   Dang chay engine de tao nhat ky su kien...\n');
    fprintf('==================================================\n');

    % =====================================================================
    % 1. CHAY ENGINE -> TAO NHAT KY SU KIEN (trace) + SIMRESULT
    % =====================================================================
    if kich_ban == 1
        [trace, SIMRESULT] = build_trace_single(cfg);
        numNodes = 2;
    elseif kich_ban == 2
        [trace, SIMRESULT] = build_trace_multi(cfg);
        numNodes = 4;
    else
        error('kich_ban chi nhan gia tri 1 hoac 2.');
    end

    nEventsAll = numel(trace);
    if nEventsAll == 0
        error('Khong sinh duoc su kien nao. Kiem tra config.m.');
    end
    nAnim = min(nEventsAll, ANIM_MAX_EVENTS);
    fprintf('Tong su kien: %d | Se phat lai: %d su kien dau.\n', nEventsAll, nAnim);

    % =====================================================================
    % 2. CAU HINH HINH HOC (toa do tren truc 0..100)
    % =====================================================================
    if numNodes == 2
        nodeX  = [15, 85];
        nodeY  = [50, 50];
        nodeNm = {'A (1)', 'B (2)'};
        busY   = 50;
    else
        nodeX  = [22, 78, 22, 78];
        nodeY  = [72, 72, 28, 28];
        nodeNm = {'Nut 1', 'Nut 2', 'Nut 3', 'Nut 4'};
        busY1  = 72; busY2 = 28; routerXY = [50, 50];
    end

    % ---- Trang thai dung chung (chia se voi cac ham long ben trong) ----
    isPlaying   = true;
    speedFactor = 4;        % 1..10 (slider)
    requestReset= false;
    curIdx      = 1;

    % ---- Bo dem so lieu live ----
    nodeColl    = zeros(1, numNodes);     % so su kien va cham theo tung nut
    okCount     = 0;                      % tong goi thanh cong
    collCount   = 0;                      % tong su kien va cham
    sumDelayDir = zeros(1, numNodes);     % tong (RX-GEN) theo nut nguon (cho throughput live)
    okPerNode   = zeros(1, numNodes);     % so goi thanh cong theo nut nguon

    % =====================================================================
    % 3. DUNG GIAO DIEN (GUI)
    % =====================================================================
    fig = figure('Name', sprintf('CSMA/CD Animation - Kich ban %d', kich_ban), ...
                 'Color', 'w', 'Units', 'normalized', ...
                 'Position', [0.08 0.1 0.84 0.8], 'NumberTitle', 'off');

    ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.05 0.20 0.66 0.74]);
    axis(ax, [0 100 0 100]); axis(ax, 'off'); hold(ax, 'on');
    set(ax, 'XLim', [0 100], 'YLim', [0 100]);

    % Panel so lieu (ben phai)
    statsText = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.73 0.20 0.25 0.74], 'BackgroundColor', [0.96 0.97 1], ...
        'HorizontalAlignment', 'left', 'FontName', 'Consolas', 'FontSize', 10, ...
        'String', '');

    % Dong trang thai (tren cung) -> dung title cua axes
    title(ax, '', 'Interpreter', 'none', 'FontSize', 11);

    % --- Thanh dieu khien (duoi cung) ---
    uicontrol('Parent', fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.05 0.08 0.10 0.06], 'String', 'Reset', ...
        'FontSize', 10, 'Callback', @onReset);

    btnPlay = uicontrol('Parent', fig, 'Style', 'pushbutton', 'Units', 'normalized', ...
        'Position', [0.16 0.08 0.14 0.06], 'String', '|| Tam dung', ...
        'FontSize', 10, 'FontWeight', 'bold', 'Callback', @togglePlay);

    uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.33 0.085 0.10 0.05], 'String', 'Toc do:', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'right', 'FontSize', 10);

    slider = uicontrol('Parent', fig, 'Style', 'slider', 'Units', 'normalized', ...
        'Position', [0.44 0.09 0.28 0.04], 'Min', 1, 'Max', 10, ...
        'Value', speedFactor, 'SliderStep', [1/9 1/9], 'Callback', @onSpeed);

    speedLabel = uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
        'Position', [0.73 0.085 0.22 0.05], 'String', '', ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left', 'FontSize', 10);

    drawTopology();
    updateStatsPanel();
    updateSpeedLabel();

    % =====================================================================
    % 4. VONG LAP PHAT LAI (replay)
    % =====================================================================
    runLoop();

    % ---------------------------------------------------------------------
    % CAC HAM LONG (NESTED) - chia se bien voi than ham chinh
    % ---------------------------------------------------------------------

    function runLoop()
        while ishandle(fig)
            % --- Bat dau / khoi dong lai 1 luot phat ---
            curIdx = 1;
            resetLiveCounters();
            clearDynamic();
            updateStatsPanel();

            doneAll = false;
            while curIdx <= nAnim && ishandle(fig)
                if requestReset, requestReset = false; break; end   % thoat -> luot moi
                if ~isPlaying
                    pause(0.04); drawnow; continue;
                end
                animateEvent(curIdx);                 % co the dat requestReset
                if requestReset, requestReset = false; break; end
                applyEventStats(curIdx);
                updateStatsPanel();
                curIdx = curIdx + 1;
                if curIdx > nAnim, doneAll = true; end
            end

            if ~ishandle(fig), break; end

            % --- Da phat het: hien thong bao, in tong ket, cho Reset ---
            if doneAll
                finalize();
                while ishandle(fig) && ~requestReset
                    pause(0.05); drawnow;
                end
                requestReset = false;
            end
        end
    end

    % --- Phat lai 1 su kien ---
    function animateEvent(idx)
        ev = trace(idx);
        setStatus(ev);
        if strcmp(ev.type, 'tx')
            pth = buildPath(ev);
            movePacket(pth, [0.10 0.65 0.20], 14);     % cham xanh la = thanh cong
        else
            animateCollision(ev);
        end
    end

    % --- Di chuyen 1 cham doc theo duong gap khuc path (Nx2) ---
    function movePacket(path, col, sz)
        hDot = plot(ax, path(1,1), path(1,2), 'o', 'MarkerSize', sz, ...
                    'MarkerFaceColor', col, 'MarkerEdgeColor', 'k', 'Tag', 'dyn');
        for s = 1:size(path,1)-1
            p0 = path(s,:); p1 = path(s+1,:);
            ns = nsubCount();
            for t = linspace(0, 1, ns)
                if ~waitFrame(), safeDelete(hDot); return; end
                pt = p0 + (p1 - p0) * t;
                if ishandle(hDot), set(hDot, 'XData', pt(1), 'YData', pt(2)); end
                drawnow; pause(frameDelay());
            end
        end
        safeDelete(hDot);
    end

    % --- Mo phong va cham giua 2 nut tren mot Bus ---
    function animateCollision(ev)
        b = ev.bus;
        if numNodes == 2
            yb = busY; xA = nodeX(1); xB = nodeX(2);
        else
            if b == 1, yb = busY1; xA = nodeX(1); xB = nodeX(2);
            else,      yb = busY2; xA = nodeX(3); xB = nodeX(4); end
        end
        mid = (xA + xB) / 2;
        hA = plot(ax, xA, yb, 'o', 'MarkerSize', 13, 'MarkerFaceColor', [0.1 0.35 0.9], ...
                  'MarkerEdgeColor', 'k', 'Tag', 'dyn');
        hB = plot(ax, xB, yb, 'o', 'MarkerSize', 13, 'MarkerFaceColor', [0.85 0.55 0.0], ...
                  'MarkerEdgeColor', 'k', 'Tag', 'dyn');
        ns = nsubCount();
        for t = linspace(0, 1, ns)
            if ~waitFrame(), safeDelete([hA hB]); return; end
            if ishandle(hA), set(hA, 'XData', xA + (mid - xA) * t); end
            if ishandle(hB), set(hB, 'XData', xB + (mid - xB) * t); end
            drawnow; pause(frameDelay());
        end
        safeDelete([hA hB]);

        % Bung va cham + nhan k
        hBurst = plot(ax, mid, yb, 'p', 'MarkerSize', 30, ...
                      'MarkerFaceColor', [1 0.25 0.1], 'MarkerEdgeColor', 'r', 'Tag', 'dyn');
        hTxt = text(ax, mid, yb + 7, ...
            sprintf('VA CHAM!  Bus %d   (nut %d:k=%d, nut %d:k=%d)', ...
                    b, ev.nA, ev.kA, ev.nB, ev.kB), ...
            'HorizontalAlignment', 'center', 'Color', 'r', 'FontWeight', 'bold', ...
            'FontSize', 10, 'Interpreter', 'none', 'Tag', 'dyn');
        % Nhay vai lan
        for f = 1:6
            if ~waitFrame(), safeDelete([hBurst hTxt]); return; end
            vis = mod(f,2);
            if ishandle(hBurst), set(hBurst, 'Visible', tf2onoff(vis)); end
            drawnow; pause(max(0.04, frameDelay()*2));
        end
        safeDelete([hBurst hTxt]);
    end

    % --- Tao duong di cho su kien truyen thanh cong ---
    function path = buildPath(ev)
        if numNodes == 2
            x0 = nodeX(ev.src); x1 = nodeX(ev.dst);
            path = [x0 busY; x1 busY];
        else
            s = ev.src; d = ev.dst;
            ps = [nodeX(s) nodeY(s)];
            pd = [nodeX(d) nodeY(d)];
            if ev.is_routing
                % di toi giua Bus nguon -> Router -> giua Bus dich -> nut dich
                ys = nodeY(s); yd = nodeY(d);
                path = [ps; 50 ys; routerXY; 50 yd; pd];
            else
                path = [ps; pd];     % noi mang: di thang tren cung Bus
            end
        end
    end

    % --- Cap nhat bo dem so lieu sau khi phat xong 1 su kien ---
    function applyEventStats(idx)
        ev = trace(idx);
        if strcmp(ev.type, 'tx')
            okCount = okCount + 1;
            okPerNode(ev.src)   = okPerNode(ev.src) + 1;
            sumDelayDir(ev.src) = sumDelayDir(ev.src) + (ev.rxtime - ev.gentime);
        else
            collCount = collCount + 1;
            nodeColl(ev.nA) = nodeColl(ev.nA) + 1;
            nodeColl(ev.nB) = nodeColl(ev.nB) + 1;
        end
    end

    % =====================================================================
    %  CAC TIEN ICH HIEN THI
    % =====================================================================
    function drawTopology()
        if numNodes == 2
            % Bus + terminator
            plot(ax, [12 88], [busY busY], 'k-', 'LineWidth', 4);
            plot(ax, [12 88], [busY busY], 'sk', 'MarkerSize', 8, 'MarkerFaceColor', 'k');
            text(ax, 50, busY + 16, 'BUS (mien xung dot chung)', ...
                'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', [0.3 0.3 0.3], ...
                'Interpreter', 'none');
        else
            plot(ax, [10 90], [busY1 busY1], 'k-', 'LineWidth', 4);
            plot(ax, [10 90], [busY2 busY2], 'k-', 'LineWidth', 4);
            % Day noi 2 Bus qua Router
            plot(ax, [50 50], [busY1 busY2], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 2);
            % Hop Router
            rectangle('Parent', ax, 'Position', [44 45 12 10], 'Curvature', 0.2, ...
                'FaceColor', [0.85 0.85 0.9], 'EdgeColor', 'k', 'LineWidth', 1.5);
            text(ax, 50, 50, 'ROUTER', 'HorizontalAlignment', 'center', ...
                'FontSize', 9, 'FontWeight', 'bold', 'Interpreter', 'none');
            text(ax, 50, busY1 + 12, 'LAN 1 / Bus 1', 'HorizontalAlignment', 'center', ...
                'FontSize', 10, 'Color', [0.3 0.3 0.3], 'Interpreter', 'none');
            text(ax, 50, busY2 - 12, 'LAN 2 / Bus 2', 'HorizontalAlignment', 'center', ...
                'FontSize', 10, 'Color', [0.3 0.3 0.3], 'Interpreter', 'none');
        end

        % Cac nut + nhan + bo dem va cham
        hNodeColl = gobjects(1, numNodes); %#ok<NASGU>
        for i = 1:numNodes
            plot(ax, nodeX(i), nodeY(i), 's', 'MarkerSize', 26, ...
                'MarkerFaceColor', [0.20 0.45 0.85], 'MarkerEdgeColor', 'k', 'LineWidth', 1.2);
            text(ax, nodeX(i), nodeY(i), nodeNm{i}, 'HorizontalAlignment', 'center', ...
                'Color', 'w', 'FontWeight', 'bold', 'FontSize', 9, 'Interpreter', 'none');
            yoff = -7; if nodeY(i) < 50, yoff = -7; end
            txt = text(ax, nodeX(i), nodeY(i) + yoff, 'va cham: 0', ...
                'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.7 0 0], ...
                'Interpreter', 'none', 'Tag', sprintf('coll%d', i));
            hNodeCollList(i) = txt; %#ok<AGROW>
        end
        hNodeColl = hNodeCollList;
        setappdata(fig, 'hNodeColl', hNodeColl);
    end

    function setStatus(ev)
        if strcmp(ev.type, 'tx')
            if numNodes == 2
                s = sprintf('t = %d us  |  Su kien %d/%d  |  Nut %d -> %d: TRUYEN THANH CONG', ...
                            ev.clock, curIdx, nAnim, ev.src, ev.dst);
            else
                tag = ''; if ev.is_routing, tag = ' (lien mang qua Router)'; end
                s = sprintf('t = %d us  |  Su kien %d/%d  |  Nut %d -> %d: THANH CONG%s', ...
                            ev.clock, curIdx, nAnim, ev.src, ev.dst, tag);
            end
        else
            s = sprintf('t = %d us  |  Su kien %d/%d  |  VA CHAM Bus %d giua nut %d & %d -> Back-off', ...
                        ev.clock, curIdx, nAnim, ev.bus, ev.nA, ev.nB);
        end
        title(ax, s, 'Interpreter', 'none', 'FontSize', 11);
    end

    function updateStatsPanel()
        hNodeColl = getappdata(fig, 'hNodeColl');
        for i = 1:numNodes
            if ~isempty(hNodeColl) && ishandle(hNodeColl(i))
                set(hNodeColl(i), 'String', sprintf('va cham: %d', nodeColl(i)));
            end
        end
        ratio = 0; if okCount > 0, ratio = 100 * collCount / okCount; end
        lines = {};
        lines{end+1} = '===== SO LIEU REAL-TIME =====';
        lines{end+1} = sprintf(' Kich ban   : %d nut', numNodes);
        lines{end+1} = sprintf(' lambda     : %.2f', cfg.lambda);
        lines{end+1} = sprintf(' td / pd    : %d / %d us', cfg.td, cfg.pd);
        lines{end+1} = '';
        lines{end+1} = sprintf(' Goi thanh cong : %d', okCount);
        lines{end+1} = sprintf(' Su kien va cham: %d', collCount);
        lines{end+1} = sprintf(' Va cham / goi  : %.0f %%', ratio);
        lines{end+1} = '';
        lines{end+1} = ' Throughput (live):';
        for i = 1:numNodes
            if okPerNode(i) > 0
                thr = (1000*8) / (sumDelayDir(i)/okPerNode(i)) * 1e6;
                lines{end+1} = sprintf('  Nut %d nguon: %s', i, fmtBps(thr)); %#ok<AGROW>
            else
                lines{end+1} = sprintf('  Nut %d nguon: --', i); %#ok<AGROW>
            end
        end
        set(statsText, 'String', lines);
    end

    function clearDynamic()
        delete(findobj(ax, 'Tag', 'dyn'));
    end

    function resetLiveCounters()
        nodeColl    = zeros(1, numNodes);
        okCount     = 0;
        collCount   = 0;
        sumDelayDir = zeros(1, numNodes);
        okPerNode   = zeros(1, numNodes);
    end

    function finalize()
        clearDynamic();
        title(ax, 'HOAN THANH - nhan "Reset" de xem lai', 'Interpreter', 'none', ...
              'FontSize', 12, 'Color', [0 0.4 0]);
        print_summary(SIMRESULT, numNodes, cfg.tdelay, nEventsAll, nAnim);
    end

    % --- Cho khung hinh: tra ve false neu can dung/reset/dong cua so ---
    function ok = waitFrame()
        ok = true;
        while ~isPlaying && ishandle(fig) && ~requestReset
            pause(0.04); drawnow;
        end
        if ~ishandle(fig) || requestReset, ok = false; end
    end

    function d = frameDelay()
        d = max(0.004, 0.16 / speedFactor);
    end

    function n = nsubCount()
        n = max(2, round(20 / speedFactor));
    end

    function updateSpeedLabel()
        set(speedLabel, 'String', sprintf('x%d', speedFactor));
    end

    % --- Callback ---
    function togglePlay(~, ~)
        isPlaying = ~isPlaying;
        if isPlaying
            set(btnPlay, 'String', '|| Tam dung');
        else
            set(btnPlay, 'String', '> Tiep tuc');
        end
    end

    function onSpeed(~, ~)
        speedFactor = round(get(slider, 'Value'));
        set(slider, 'Value', speedFactor);
        updateSpeedLabel();
    end

    function onReset(~, ~)
        requestReset = true;
        isPlaying = true;
        set(btnPlay, 'String', '|| Tam dung');
    end

end  % ====================== het ham chinh ===============================


% =========================================================================
%  ENGINE + GHI NHAT KY: KICH BAN 2 NUT (sao logic tu csma_cd_single.m)
% =========================================================================
function [trace, SIMRESULT] = build_trace_single(cfg)
    A = 1; B = 2;
    elist = [];
    SIMRESULT = [];
    CLOCK = 0;
    GENTIMECURSOR = [0 0];
    SRC = 1; GENTIME = 2; TXTIME = 3; RXTIME = 4; CURTIME = 5; COLLISIONS = 6;

    trace = struct('type', {}, 'clock', {}, 'src', {}, 'dst', {}, 'bus', {}, ...
                   'is_routing', {}, 'gentime', {}, 'txtime', {}, 'rxtime', {}, ...
                   'nA', {}, 'nB', {}, 'kA', {}, 'kB', {});

    [elist, GENTIMECURSOR] = create_packet(A, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);
    [elist, GENTIMECURSOR] = create_packet(B, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);
    if isempty(elist), return; end

    while true
        elist = sortrows(elist, CURTIME);
        CLOCK = elist(1, CURTIME);
        src   = elist(1, SRC);

        if size(elist, 1) > 1
            timediff = elist(2, CURTIME) - elist(1, CURTIME);
        else
            timediff = inf;
        end

        if timediff > cfg.pd
            % --- THANH CONG ---
            if elist(1, TXTIME) == 0, elist(1, TXTIME) = elist(1, CURTIME); end
            elist(1, RXTIME) = elist(1, CURTIME) + cfg.tdelay;
            pkt = elist(1, :);
            SIMRESULT = [SIMRESULT; pkt];
            elist(1, :) = [];

            dst = B; if src == B, dst = A; end
            trace(end+1) = mk_event('tx', CLOCK, src, dst, 1, false, ...
                pkt(GENTIME), pkt(TXTIME), pkt(RXTIME), 0, 0, 0, 0); %#ok<AGROW>

            [elist, GENTIMECURSOR] = create_packet(src, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);
            CLOCK = CLOCK + cfg.tdelay;
            idx = find((elist(:, CURTIME) - CLOCK) < 0);
            elist(idx, CURTIME) = CLOCK;
        else
            % --- VA CHAM ---
            nA = elist(1, SRC); nB = elist(2, SRC);
            elist = execute_backoff(elist, timediff, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
            kA = elist(1, COLLISIONS); kB = elist(2, COLLISIONS);
            trace(end+1) = mk_event('cx', CLOCK, 0, 0, 1, false, ...
                0, 0, 0, nA, nB, kA, kB); %#ok<AGROW>
        end

        if min(GENTIMECURSOR) > cfg.TOTALSIM, break; end
    end
end


% =========================================================================
%  ENGINE + GHI NHAT KY: KICH BAN 4 NUT (sao logic tu csma_cd_multi.m)
% =========================================================================
function [trace, SIMRESULT] = build_trace_multi(cfg)
    nodes = [1, 2, 3, 4];
    elist1 = []; elist2 = [];
    SIMRESULT = [];
    CLOCK = 0;
    GENTIMECURSOR = [0 0 0 0];
    SRC = 1; DEST = 2; GENTIME = 3; TXTIME = 4; RXTIME = 5; CURTIME = 6; COLLISIONS = 7;

    trace = struct('type', {}, 'clock', {}, 'src', {}, 'dst', {}, 'bus', {}, ...
                   'is_routing', {}, 'gentime', {}, 'txtime', {}, 'rxtime', {}, ...
                   'nA', {}, 'nB', {}, 'kA', {}, 'kB', {});

    for n = 1:4
        if n <= 2
            [elist1, GENTIMECURSOR] = create_packet(n, elist1, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
        else
            [elist2, GENTIMECURSOR] = create_packet(n, elist2, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
        end
    end
    if isempty(elist1) && isempty(elist2), return; end

    while true
        elist1 = sortrows(elist1, CURTIME);
        elist2 = sortrows(elist2, CURTIME);
        CLOCK  = min(elist1(1, CURTIME), elist2(1, CURTIME));

        l_src = [elist1(1, SRC), elist2(1, SRC)];
        src   = l_src(randi(length(l_src)));
        destnodes = nodes(nodes ~= src);
        dst   = destnodes(randi(length(destnodes)));

        if src == 1 || src == 2
            bus1_active = true;  bus2_active = false; elist1(1, DEST) = dst;
        else
            bus1_active = false; bus2_active = true;  elist2(1, DEST) = dst;
        end

        is_routing = ((src <= 2 && dst >= 3) || (src >= 3 && dst <= 2));
        if is_routing
            tdelay_current = cfg.tdelay + calculate_routing_delay(src, dst, cfg.td, cfg.pd);
        else
            tdelay_current = 90;
        end

        timediff1 = inf; timediff2 = inf;
        if size(elist1, 1) > 1, timediff1 = elist1(2, CURTIME) - elist1(1, CURTIME); end
        if size(elist2, 1) > 1, timediff2 = elist2(2, CURTIME) - elist2(1, CURTIME); end

        if timediff1 > cfg.pd && timediff2 > cfg.pd
            % --- THANH CONG ---
            if bus1_active
                if elist1(1, TXTIME) == 0, elist1(1, TXTIME) = elist1(1, CURTIME); end
                elist1(1, RXTIME) = elist1(1, CURTIME) + tdelay_current;
                pkt = elist1(1, :);
                SIMRESULT = [SIMRESULT; pkt];
                elist1(1, :) = [];
                trace(end+1) = mk_event('tx', CLOCK, pkt(SRC), pkt(DEST), 1, is_routing, ...
                    pkt(GENTIME), pkt(TXTIME), pkt(RXTIME), 0, 0, 0, 0); %#ok<AGROW>
            end
            if bus2_active
                if elist2(1, TXTIME) == 0, elist2(1, TXTIME) = elist2(1, CURTIME); end
                elist2(1, RXTIME) = elist2(1, CURTIME) + tdelay_current;
                pkt = elist2(1, :);
                SIMRESULT = [SIMRESULT; pkt];
                elist2(1, :) = [];
                trace(end+1) = mk_event('tx', CLOCK, pkt(SRC), pkt(DEST), 2, is_routing, ...
                    pkt(GENTIME), pkt(TXTIME), pkt(RXTIME), 0, 0, 0, 0); %#ok<AGROW>
            end

            if src <= 2
                [elist1, GENTIMECURSOR] = create_packet(src, elist1, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
            else
                [elist2, GENTIMECURSOR] = create_packet(src, elist2, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
            end

            CLOCK = CLOCK + tdelay_current;
            d1 = find((elist1(:, CURTIME) - CLOCK) < 0); elist1(d1, CURTIME) = CLOCK;
            d2 = find((elist2(:, CURTIME) - CLOCK) < 0); elist2(d2, CURTIME) = CLOCK;
        else
            % --- VA CHAM (co the xay ra tren ca 2 Bus) ---
            if timediff1 <= cfg.pd
                nA = elist1(1, SRC); nB = elist1(2, SRC);
                elist1 = execute_backoff(elist1, timediff1, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
                kA = elist1(1, COLLISIONS); kB = elist1(2, COLLISIONS);
                trace(end+1) = mk_event('cx', CLOCK, 0, 0, 1, false, 0, 0, 0, nA, nB, kA, kB); %#ok<AGROW>
            end
            if timediff2 <= cfg.pd
                nA = elist2(1, SRC); nB = elist2(2, SRC);
                elist2 = execute_backoff(elist2, timediff2, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
                kA = elist2(1, COLLISIONS); kB = elist2(2, COLLISIONS);
                trace(end+1) = mk_event('cx', CLOCK, 0, 0, 2, false, 0, 0, 0, nA, nB, kA, kB); %#ok<AGROW>
            end
        end

        if min(GENTIMECURSOR) > cfg.TOTALSIM, break; end
    end
end


% --- Tao 1 ban ghi su kien (giu thu tu truong on dinh) ---
function ev = mk_event(type, clock, src, dst, bus, is_routing, ...
                       gentime, txtime, rxtime, nA, nB, kA, kB)
    ev = struct('type', type, 'clock', clock, 'src', src, 'dst', dst, 'bus', bus, ...
                'is_routing', is_routing, 'gentime', gentime, 'txtime', txtime, ...
                'rxtime', rxtime, 'nA', nA, 'nB', nB, 'kA', kA, 'kB', kB);
end


% --- Tre dinh tuyen (sao tu local function trong csma_cd_multi.m) ---
function total_router_delay = calculate_routing_delay(src, dst, td, pd)
    adj = [0 0 1 1; 0 0 1 1; 1 1 0 0; 1 1 0 0];
    c = randi([1, 10], 1, 4);
    edgeweights = [0 0 c(1) c(2); 0 0 c(3) c(4); c(1) c(2) 0 0; c(3) c(4) 0 0];
    [costs, paths] = dijkstra(adj, edgeweights);
    pathlength = cellfun('length', paths);
    rtdelay = 8;
    if src <= 2 && dst >= 3
        rcosts = costs(1:2, 3:4);
        [~, index] = min(rcosts(:));
        [srouter, drouter] = ind2sub(size(rcosts), index);
        drouter = drouter + 2;
        total_router_delay = ((pathlength(srouter, drouter) - 1) * (rtdelay + pd));
    else
        rcosts = costs(3:4, 1:2);
        [~, index] = min(rcosts(:));
        [srouter, drouter] = ind2sub(size(rcosts), index);
        srouter = srouter + 2;
        total_router_delay = (pathlength(srouter, drouter) * (td + pd));
    end
end


% --- In tong ket toan bo lan chay (so lieu khop voi ban goc) ---
function print_summary(SIMRESULT, numNodes, tdelay, nAll, nAnim)
    fprintf('\n================ TONG KET (TOAN BO LAN CHAY) ================\n');
    fprintf('Tong su kien: %d | Da phat lai animation: %d\n', nAll, nAnim);
    if isempty(SIMRESULT)
        fprintf('Khong co goi nao truyen thanh cong.\n'); return;
    end
    nc = size(SIMRESULT, 2);
    if numNodes == 2
        SRC = 1; GENTIME = 2; RXTIME = 4;
        AtoB = SIMRESULT(SIMRESULT(:,SRC) == 1, :);
        BtoA = SIMRESULT(SIMRESULT(:,SRC) == 2, :);
        fprintf('Goi A->B: %d | Goi B->A: %d\n', size(AtoB,1), size(BtoA,1));
        if ~isempty(AtoB)
            fprintf('Throughput A->B: %s\n', fmtBps((1000*8)/mean(AtoB(:,RXTIME)-AtoB(:,GENTIME))*1e6));
        end
        if ~isempty(BtoA)
            fprintf('Throughput B->A: %s\n', fmtBps((1000*8)/mean(BtoA(:,RXTIME)-BtoA(:,GENTIME))*1e6));
        end
    else
        SRC = 1; DEST = 2; GENTIME = 3; RXTIME = 5; COLLISIONS = 7; %#ok<NASGU>
        fprintf('%-6s %-6s %-12s %-10s %-10s\n', 'Nguon', 'Dich', 'Throughput', 'So goi', 'Va cham');
        fprintf('--------------------------------------------------------\n');
        for i = 1:4
            for j = 1:4
                if i ~= j
                    pd = SIMRESULT(SIMRESULT(:,SRC)==i & SIMRESULT(:,DEST)==j, :);
                    if ~isempty(pd)
                        thr = (1000*8)/mean(pd(:,RXTIME)-pd(:,GENTIME))*1e6;
                        fprintf('%-6d %-6d %-12s %-10d %-10d\n', i, j, fmtBps(thr), ...
                                size(pd,1), sum(pd(:,COLLISIONS)));
                    end
                end
            end
        end
    end
    fprintf('============================================================\n');
end


% --- Dinh dang throughput cho de doc ---
function s = fmtBps(bps)
    if bps >= 1e6
        s = sprintf('%.2f Mbps', bps/1e6);
    elseif bps >= 1e3
        s = sprintf('%.1f Kbps', bps/1e3);
    else
        s = sprintf('%.0f bps', bps);
    end
end


% --- 0/1 -> 'off'/'on' ---
function s = tf2onoff(v)
    if v, s = 'on'; else, s = 'off'; end
end


% --- Xoa an toan cac handle hop le ---
function safeDelete(h)
    h = h(ishandle(h));
    if ~isempty(h), delete(h); end
end