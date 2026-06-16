function csma_cd_busN(cfg)
% CSMA_CD_BUSN - Mô phỏng mạng CSMA/CD Bus chung nhiều nút (Kịch bản 3)
%
% Kịch bản này mô phỏng N nút (mặc định 6) cùng chia sẻ 1 Bus duy nhất
% (1 collision domain). Đây là mô hình Ethernet Hub cổ điển.
%
% ĐẦU VÀO:
%   cfg : Cấu trúc chứa toàn bộ các thông số môi trường từ file config.m

% =====================================================================
% 1. KHỞI TẠO BIẾN HỆ THỐNG
% =====================================================================
NUM_NODES = 6;              % Số nút trên Bus (có thể chỉnh thành 4, 6, 8...)

elist       = [];           % Hàng đợi sự kiện chung (1 collision domain)
SIMRESULT   = [];           % Lưu trữ các gói tin đã truyền thành công
CLOCK       = 0;            % Đồng hồ hệ thống
GENTIMECURSOR = zeros(1, NUM_NODES); % Mốc thời gian sinh gói của từng nút

% Đổi sang định dạng 7 cột giống Kịch bản 2 để quản lý nút Đích (DEST)
% [SRC, DEST, GENTIME, TXTIME, RXTIME, CURTIME, COLLISIONS]
SRC         = 1;
DEST        = 2;
GENTIME     = 3;
TXTIME      = 4;
RXTIME      = 5;
CURTIME     = 6;
COLLISIONS  = 7;

% =====================================================================
% 2. MỒI HỆ THỐNG (Tạo gói tin đầu tiên cho tất cả các nút)
% =====================================================================
for n = 1:NUM_NODES
    % Gọi hàm với tham số định dạng 7 cột
    [elist, GENTIMECURSOR] = create_packet(n, elist, GENTIMECURSOR, ...
                                           cfg.lambda, cfg.frameslot, 7);
end

if isempty(elist)
    disp('Lỗi hệ thống: Không có gói tin nào được khởi tạo!');
    return;
end

fprintf('>> KB3: Bus chung %d nút | lambda=%.2f\n', NUM_NODES, cfg.lambda);

% =====================================================================
% 3. VÒNG LẶP MÔ PHỎNG CHÍNH
% =====================================================================
while true

    % ------------------------------------------------------------------
    % Bước 3.1: Đồng bộ thời gian
    % Sắp xếp hàng đợi theo CURTIME tăng dần
    % ------------------------------------------------------------------
    elist = sortrows(elist, CURTIME);
    CLOCK = elist(1, CURTIME);
    src   = elist(1, SRC);

    % ------------------------------------------------------------------
    % CẤP PHÁT ĐÍCH NGẪU NHIÊN: Nếu gói tin đầu hàng đợi chưa có đích (DEST == 0),
    % tiến hành chọn ngẫu nhiên một nút nhận khác với nút nguồn.
    % ------------------------------------------------------------------
    if elist(1, DEST) == 0
        nodes = 1:NUM_NODES;
        destnodes = nodes(nodes ~= src);
        elist(1, DEST) = destnodes(randi(length(destnodes)));
    end

    % ------------------------------------------------------------------
    % Bước 3.2: Tìm TẤT CẢ các nút đang xung đột
    % ------------------------------------------------------------------
    if size(elist, 1) > 1
        collision_mask = (elist(:, CURTIME) - elist(1, CURTIME)) <= cfg.pd;
        num_colliders  = sum(collision_mask);
    else
        num_colliders = 1;
    end

    % ------------------------------------------------------------------
    % Bước 3.3: Rẽ nhánh xử lý
    % ------------------------------------------------------------------
    if num_colliders == 1

        % --------------------------------------------------------------
        % NHÁNH 1: KÊNH RỖI → TRUYỀN THÀNH CÔNG
        % --------------------------------------------------------------

        % Chốt thời điểm bắt đầu truyền (nếu là lần đầu)
        if elist(1, TXTIME) == 0
            elist(1, TXTIME) = elist(1, CURTIME);
        end

        % Thời điểm nhận = hiện tại + tổng trễ
        elist(1, RXTIME) = elist(1, CURTIME) + cfg.tdelay;

        % Lưu vào kết quả và xóa khỏi hàng đợi
        SIMRESULT = [SIMRESULT; elist(1, :)];
        elist(1, :) = [];

        % Nút vừa truyền xong → sinh gói mới cho nút đó (định dạng 7 cột)
        [elist, GENTIMECURSOR] = create_packet(src, elist, GENTIMECURSOR, ...
                                               cfg.lambda, cfg.frameslot, 7);

        % Giữ kênh bận trong suốt tdelay
        CLOCK = CLOCK + cfg.tdelay;
        danh_sach_cho = find((elist(:, CURTIME) - CLOCK) < 0);
        elist(danh_sach_cho, CURTIME) = CLOCK;

    else

        % --------------------------------------------------------------
        % NHÁNH 2: KÊNH BẬN → XẢY RA XUNG ĐỘT
        % --------------------------------------------------------------
        collider_idx = find(collision_mask);
        
        for ci = 1:length(collider_idx)
            idx = collider_idx(ci);
            
            % 1. Chốt mốc TXTIME nếu đây là lần đầu tiên gói tin thử truyền
            if elist(idx, TXTIME) == 0  
                elist(idx, TXTIME) = elist(idx, CURTIME);
            end
            
            % 2. Tăng bộ đếm va chạm TRƯỚC KHI tính toán bậc hàm mũ
            elist(idx, COLLISIONS) = elist(idx, COLLISIONS) + 1; 
            
            % 3. Tính toán thời gian lùi (Back-off) theo hàm mũ
            k  = min(elist(idx, COLLISIONS), cfg.maxbackoff);
            bk = (randi(2^k) - 1) * cfg.tbackoff;
            
            % 4. Áp dụng phạt: Cộng gộp trễ lan truyền (pd) + thời gian chờ (bk)
            elist(idx, CURTIME) = elist(idx, CURTIME) + cfg.pd + bk;
        end

    end

    % ------------------------------------------------------------------
    % Bước 3.4: Điều kiện thoát
    % ------------------------------------------------------------------
    if min(GENTIMECURSOR) > cfg.TOTALSIM
        break;
    end

end

% =====================================================================
% 4. XỬ LÝ SỐ LIỆU VÀ XUẤT ĐỒ THỊ
% =====================================================================
plot_results_busN(SIMRESULT, NUM_NODES, cfg.tdelay);

end


% =========================================================================
% HÀM PHỤ: VẼ ĐỒ THỊ VÀ IN BẢNG THỐNG KÊ CHI TIẾT THEO CẶP
% =========================================================================
function plot_results_busN(SIMRESULT, NUM_NODES, tdelay)

SRC        = 1;
DEST       = 2;
GENTIME    = 3;
TXTIME     = 4;
RXTIME     = 5;
COLLISIONS = 7;

if isempty(SIMRESULT)
    fprintf('\n================ KẾT QUẢ KB3: BUS %d NÚT ================\n', NUM_NODES);
    disp('Không có gói tin nào truyền thành công.');
    return;
end

% ------------------------------------------------------------------
% 1. Tính toán số liệu để vẽ đồ thị theo từng nút Nguồn (Gom các đích lại để tránh chia nhỏ 30 subplots)
% ------------------------------------------------------------------
stats_table = [];   % [node, throughput, num_packets, num_collisions, mean_qdelay, mean_adelay]

fig_q   = figure('Name', sprintf('Queue Delay - KB3 Bus %d Nut', NUM_NODES));
fig_acc = figure('Name', sprintf('Access Delay - KB3 Bus %d Nut', NUM_NODES));

num_cols_plot = ceil(NUM_NODES / 2); 

for n = 1:NUM_NODES
    node_data = SIMRESULT(SIMRESULT(:, SRC) == n, :);
    num_pkts  = size(node_data, 1);

    if num_pkts > 0
        q_delay   = node_data(:, RXTIME) - node_data(:, GENTIME) - tdelay;
        acc_delay = node_data(:, RXTIME) - node_data(:, TXTIME);
        collisions = sum(node_data(:, COLLISIONS));
        throughput = ((1000 * 8) / mean(node_data(:, RXTIME) - node_data(:, GENTIME))) * 10^6;

        stats_table = [stats_table; n, throughput, num_pkts, collisions, ...
                       mean(q_delay), mean(acc_delay)];

        % Vẽ Queue delay
        figure(fig_q); subplot(2, num_cols_plot, n); plot(q_delay);
        title(sprintf('Queue delay - Nut %d', n)); xlabel('Packet sequence #'); ylabel('Delay (\mus)');

        % Vẽ Access delay
        figure(fig_acc); subplot(2, num_cols_plot, n); plot(acc_delay);
        title(sprintf('Access delay - Nut %d', n)); xlabel('Packet sequence #'); ylabel('Delay (\mus)');
    end
end

% Vẽ biểu đồ cột tổng hợp
if ~isempty(stats_table)
    figure('Name', sprintf('Tong hop KB3 - Bus %d Nut', NUM_NODES));
    subplot(1, 2, 1); bar(stats_table(:, 1), stats_table(:, 2) / 1e6);
    title('Throughput theo từng nút'); xlabel('Nút'); ylabel('Throughput (Mbps)'); grid on;

    subplot(1, 2, 2); bar(stats_table(:, 1), stats_table(:, 4));
    title('Số va chạm theo từng nút'); xlabel('Nút'); ylabel('Số va chạm'); grid on;
end

% ------------------------------------------------------------------
% 2. IN BẢNG KẾT QUẢ CHUẨN ĐẸP MẮT THEO TỪNG CẶP NGUỒN -> ĐÍCH RA CONSOLE
% ------------------------------------------------------------------
fprintf('\n================ KẾT QUẢ MÔ PHỎNG (KỊCH BẢN 3: BUS %d NÚT) ================\n', NUM_NODES);
fprintf('%-10s %-10s %-20s %-15s %-15s\n', 'Nguon', 'Dich', 'Thong luong (bps)', 'So packet', 'So va cham');
fprintf('--------------------------------------------------------------------------------\n');

total_packets = 0;
total_collisions = 0;
pair_throughputs = [];

for i = 1:NUM_NODES
    for j = 1:NUM_NODES
        if i ~= j
            % Lọc dữ liệu riêng cho cặp i -> j
            pair_data = SIMRESULT(SIMRESULT(:, SRC) == i & SIMRESULT(:, DEST) == j, :);
            num_pkts_pair = size(pair_data, 1);
            
            if num_pkts_pair > 0
                coll_pair = sum(pair_data(:, COLLISIONS));
                thr_pair = ((1000 * 8) / mean(pair_data(:, RXTIME) - pair_data(:, GENTIME))) * 10^6;
                
                fprintf('%-10d %-10d %-20.2f %-15d %-15d\n', i, j, thr_pair, num_pkts_pair, coll_pair);
                
                total_packets = total_packets + num_pkts_pair;
                total_collisions = total_collisions + coll_pair;
                pair_throughputs = [pair_throughputs; thr_pair];
            end
        end
    end
end

fprintf('--------------------------------------------------------------------------------\n');
fprintf('Tổng gói thành công : %d\n', total_packets);
fprintf('Tổng va chạm        : %d\n', total_collisions);
if ~isempty(pair_throughputs)
    fprintf('Throughput TB toàn mạng: %.2f bps\n', mean(pair_throughputs));
else
    fprintf('Throughput TB toàn mạng: 0.00 bps\n');
end
fprintf('================================================================================\n');

end