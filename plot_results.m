function plot_results(SIMRESULT, num_nodes, tdelay)
% PLOT_RESULTS - Hàm chuyên trách xử lý số liệu thống kê và xuất đồ thị
%
% CÁC THAM SỐ ĐẦU VÀO:
%   SIMRESULT : Ma trận chứa dữ liệu mô phỏng đã thu thập được
%   num_nodes : Số lượng trạm (2 hoặc 4) để tự động quyết định kịch bản vẽ
%   tdelay    : Tổng trễ truyền dẫn cơ sở (dùng để tính toán trễ hàng đợi)

    % 1. Tự động nhận diện cấu trúc cột dữ liệu dựa vào số cột của SIMRESULT
    num_cols = size(SIMRESULT, 2);
    if num_cols == 7 % Kịch bản mạng 4 nút (Có thêm cột Đích đến)
        SRC = 1; DEST = 2; GENTIME = 3; TXTIME = 4; RXTIME = 5; COLLISIONS = 7;
    else             % Kịch bản mạng 2 nút
        SRC = 1; GENTIME = 2; TXTIME = 3; RXTIME = 4; COLLISIONS = 6;
    end

    fprintf('\n================ KẾT QUẢ MÔ PHỎNG ================\n');

    % =====================================================================
    % 2. XỬ LÝ VÀ VẼ ĐỒ THỊ CHO KỊCH BẢN 2 NÚT (MẠNG TUYẾN TÍNH)
    % =====================================================================
    % =====================================================================
    % 2. XỬ LÝ VÀ VẼ ĐỒ THỊ CHO KỊCH BẢN 2 NÚT (MẠNG TUYẾN TÍNH)
    % =====================================================================
    if num_nodes == 2
        AtoB = SIMRESULT(SIMRESULT(:,SRC)==1, :);
        BtoA = SIMRESULT(SIMRESULT(:,SRC)==2, :);
        
        % Tính toán Trễ hàng đợi (Queue Delay) và Trễ truy nhập (Access Delay)
        q_delay_A = AtoB(:,RXTIME) - AtoB(:,GENTIME) - tdelay;
        q_delay_B = BtoA(:,RXTIME) - BtoA(:,GENTIME) - tdelay;
        
        acc_delay_A = AtoB(:,RXTIME) - AtoB(:,TXTIME);
        acc_delay_B = BtoA(:,RXTIME) - BtoA(:,TXTIME);
        
        % TÍNH TOÁN KHOẢNG THỜI GIAN SINH GÓI (FRAME INTERVALS)
        % Lấy hiệu số giữa các mốc GENTIME liên tiếp
        intervals_A = diff(AtoB(:, GENTIME));
        intervals_B = diff(BtoA(:, GENTIME));
        
        % Bật cửa sổ và vẽ ĐÚNG 6 ĐỒ THỊ CON (Lưới 3 hàng x 2 cột giống báo cáo)
        figure('Name', 'Thong ke Tre & Khoang sinh goi - Mang 2 Nut');
        
        % HÀNG 1: Trễ hàng đợi
        subplot(3,2,1); plot(q_delay_A); title('Queue delay at node A'); xlabel('Packet sequence #'); ylabel('Delay in \mus');
        subplot(3,2,2); plot(q_delay_B); title('Queue delay at node B'); xlabel('Packet sequence #'); ylabel('Delay in \mus');
        
        % HÀNG 2: Trễ truy nhập
        subplot(3,2,3); plot(acc_delay_A); title('Access delay at node A'); xlabel('Packet sequence #'); ylabel('Delay in \mus');
        subplot(3,2,4); plot(acc_delay_B); title('Access delay at node B'); xlabel('Packet sequence #'); ylabel('Delay in \mus');
        
        % HÀNG 3: Khoảng thời gian giữa các gói (Sửa lỗi thiếu đồ thị)
        subplot(3,2,5); plot(intervals_B); title('Frame intervals at node B'); xlabel('Packet sequence #'); ylabel('Frame interval in msec');
        subplot(3,2,6); plot(intervals_A); title('Frame intervals at node A'); xlabel('Packet sequence #'); ylabel('Frame interval in msec');
        
        % VẼ THÊM HÌNH 2.4 (BIỂU ĐỒ HISTOGRAM TỐC ĐỘ TẠO FRAME)
        figure('Name', 'Toc do tao frame (Histogram) - Mang 2 Nut');
        subplot(2,1,1); hist(intervals_A, 50); title('# of frames - Node A'); xlabel('frame intervals in \mu sec'); ylabel('# of frames');
        subplot(2,1,2); hist(intervals_B, 50); title('# of frames - Node B'); xlabel('frame intervals in \mu sec'); ylabel('# of frames');
        
        % In thông số thống kê ra màn hình Console
        fprintf('Tong so goi tin gui thanh cong tu A -> B: %d\n', length(AtoB));
        fprintf('Tong so goi tin gui thanh cong tu B -> A: %d\n', length(BtoA));
        fprintf('Thong luong trung binh A -> B: %.2f bps\n', ((1000*8)/mean(AtoB(:,RXTIME)-AtoB(:,GENTIME)))*10^6);
        fprintf('Thong luong trung binh B -> A: %.2f bps\n', ((1000*8)/mean(BtoA(:,RXTIME)-BtoA(:,GENTIME)))*10^6);

    % =====================================================================
    % 3. XỬ LÝ VÀ VẼ ĐỒ THỊ CHO KỊCH BẢN 4 NÚT (MẠNG QUA ROUTER)
    % =====================================================================
    elseif num_nodes == 4
        figure_q = figure('Name', 'Queue Delay - Mang 4 Nut');
        figure_acc = figure('Name', 'Access Delay - Mang 4 Nut');
        
        plotcount = 1;
        stats_table = []; % Ma trận tạm để lưu bảng số liệu
        
        % Vòng lặp duyệt qua tất cả các cặp Nguồn (i) và Đích (j)
        for i = 1:4
            for j = 1:4
                if i ~= j
                    % Lọc ra dữ liệu của riêng cặp truyền i -> j
                    pair_data = SIMRESULT(SIMRESULT(:,SRC) == i & SIMRESULT(:,DEST) == j, :);
                    num_packets = size(pair_data, 1);
                    
                    if num_packets > 0
                        % Tính toán số liệu
                        q_delay = pair_data(:, RXTIME) - pair_data(:, GENTIME) - tdelay;
                        acc_delay = pair_data(:, RXTIME) - pair_data(:, TXTIME);
                        collisions = sum(pair_data(:, COLLISIONS));
                        throughput = ((1000*8) / mean(pair_data(:, RXTIME) - pair_data(:, GENTIME))) * 10^6;
                        
                        % Lưu một dòng vào bảng thống kê
                        stats_table = [stats_table; i, j, throughput, num_packets, collisions];
                        
                        % Vẽ đồ thị Trễ hàng đợi
                        figure(figure_q);
                        subplot(4, 3, plotcount);
                        plot(q_delay);
                        title(sprintf('Queue delay Node %d -> %d', i, j));
                        
                        % Vẽ đồ thị Trễ truy nhập
                        figure(figure_acc);
                        subplot(4, 3, plotcount);
                        plot(acc_delay);
                        title(sprintf('Access delay Node %d -> %d', i, j));
                    end
                    plotcount = plotcount + 1; % Chuyển sang ô đồ thị tiếp theo
                end
            end
        end
        
        % In bảng kết quả chuẩn hóa đẹp mắt ra màn hình Console
        fprintf('%-10s %-10s %-20s %-15s %-15s\n', 'Nguon', 'Dich', 'Thong luong (bps)', 'So packet', 'So va cham');
        fprintf('--------------------------------------------------------------------------------\n');
        for r = 1:size(stats_table, 1)
            fprintf('%-10d %-10d %-20.2f %-15d %-15d\n', ...
                stats_table(r,1), stats_table(r,2), stats_table(r,3), stats_table(r,4), stats_table(r,5));
        end
    end
    fprintf('==================================================\n');
end