function csma_cd_multi(cfg)
% CSMA_CD_MULTI - Mô phỏng mạng CSMA/CD đa phân đoạn (4 nút qua Router)
%
% ĐẦU VÀO: 
%   cfg : Cấu trúc chứa toàn bộ các thông số môi trường từ file config.m

    % =====================================================================
    % 1. KHỞI TẠO BIẾN HỆ THỐNG VÀ CẤU TRÚC MẠNG
    % =====================================================================
    nodes = [1, 2, 3, 4];
    elist1 = []; % Hàng đợi cho Bus 1 (Chứa Node 1 và 2)
    elist2 = []; % Hàng đợi cho Bus 2 (Chứa Node 3 và 4)
    SIMRESULT = [];
    CLOCK = 0;
    GENTIMECURSOR = [0 0 0 0]; % Bộ đếm thời gian sinh gói của 4 nút
    
    % Các cột định dạng của mảng elist cho kịch bản 4 nút (7 cột)
    SRC = 1; DEST = 2; TXTIME = 4; RXTIME = 5; CURTIME = 6;

    % =====================================================================
    % 2. MỒI HỆ THỐNG (Khởi tạo gói tin đầu tiên cho cả 4 nút)
    % =====================================================================
    for n = 1:4
        if n <= 2 % Nút 1, 2 thuộc LAN 1
            [elist1, GENTIMECURSOR] = create_packet(n, elist1, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
        else      % Nút 3, 4 thuộc LAN 2
            [elist2, GENTIMECURSOR] = create_packet(n, elist2, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
        end
    end

    if isempty(elist1) && isempty(elist2)
        disp('Lỗi hệ thống: Không có gói tin nào được khởi tạo!');
        return;
    end

    % =====================================================================
    % 3. VÒNG LẶP MÔ PHỎNG CHÍNH (ĐIỀU PHỐI 2 BUS SONG SONG)
    % =====================================================================
    while true
        
        % Bước 3.1: Đồng bộ thời gian của cả 2 Bus
        elist1 = sortrows(elist1, CURTIME);
        elist2 = sortrows(elist2, CURTIME);
        
        % Đồng hồ hệ thống chạy theo gói tin xuất hiện sớm nhất trên cả 2 mạng
        CLOCK = min(elist1(1, CURTIME), elist2(1, CURTIME));
        
        % Bước 3.2: Lựa chọn ngẫu nhiên nút Nguồn và nút Đích
        l_src = [elist1(1, SRC), elist2(1, SRC)];
        src = l_src(randi(length(l_src)));
        
        destnodes = nodes(nodes ~= src);
        dst = destnodes(randi(length(destnodes))); % Chọn đích ngẫu nhiên khác nguồn
        
        % Gắn đích đến và xác định Bus đang chiếm quyền truyền tải
        if src == 1 || src == 2
            bus1_active = true; bus2_active = false;
            elist1(1, DEST) = dst;
        else
            bus1_active = false; bus2_active = true;
            elist2(1, DEST) = dst;
        end
        
        % Bước 3.3: Tính toán trễ định tuyến (Nếu truyền xuyên mạng LAN)
        is_routing = ((src <= 2 && dst >= 3) || (src >= 3 && dst <= 2));
        if is_routing
            tdelay_current = cfg.tdelay + calculate_routing_delay(src, dst, cfg.td, cfg.pd);
        else
            tdelay_current = 90; % Độ trễ nội bộ trong LAN (giữ nguyên logic gốc)
        end
        
        % Bước 3.4: Đo độ chênh lệch thời gian để dò va chạm trên cả 2 Bus
        timediff1 = inf; timediff2 = inf;
        if size(elist1, 1) > 1, timediff1 = elist1(2, CURTIME) - elist1(1, CURTIME); end
        if size(elist2, 1) > 1, timediff2 = elist2(2, CURTIME) - elist2(1, CURTIME); end
        
        % Bước 3.5: Rẽ nhánh xử lý
        if timediff1 > cfg.pd && timediff2 > cfg.pd
            % -------------------------------------------------------------
            % NHÁNH 1: KÊNH RỖI Ở CẢ 2 BUS (TRUYỀN THÀNH CÔNG)
            % -------------------------------------------------------------
            if bus1_active
                if elist1(1, TXTIME) == 0, elist1(1, TXTIME) = elist1(1, CURTIME); end
                elist1(1, RXTIME) = elist1(1, CURTIME) + tdelay_current;
                SIMRESULT = [SIMRESULT; elist1(1, :)];
                elist1(1, :) = [];
            end
            
            if bus2_active
                if elist2(1, TXTIME) == 0, elist2(1, TXTIME) = elist2(1, CURTIME); end
                elist2(1, RXTIME) = elist2(1, CURTIME) + tdelay_current;
                SIMRESULT = [SIMRESULT; elist2(1, :)];
                elist2(1, :) = [];
            end
            
            % Sinh gói tin mới bù vào mạng tương ứng
            if src <= 2
                [elist1, GENTIMECURSOR] = create_packet(src, elist1, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
            else
                [elist2, GENTIMECURSOR] = create_packet(src, elist2, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 7);
            end
            
            % Giữ kênh (Bắt các gói tin sinh ra trong lúc truyền phải chờ)
            CLOCK = CLOCK + tdelay_current;
            danh_sach_cho1 = find((elist1(:, CURTIME) - CLOCK) < 0);
            elist1(danh_sach_cho1, CURTIME) = CLOCK;
            danh_sach_cho2 = find((elist2(:, CURTIME) - CLOCK) < 0);
            elist2(danh_sach_cho2, CURTIME) = CLOCK;
            
        else
            % -------------------------------------------------------------
            % NHÁNH 2: CÓ XUNG ĐỘT (GỌI HÀM BACKOFF TỪ UTILS)
            % -------------------------------------------------------------
            if timediff1 <= cfg.pd
                elist1 = execute_backoff(elist1, timediff1, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
            end
            if timediff2 <= cfg.pd
                elist2 = execute_backoff(elist2, timediff2, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
            end
        end
        
        % Bước 3.6: Điều kiện thoát vòng lặp
        if min(GENTIMECURSOR) > cfg.TOTALSIM
            break;
        end
    end

    % =====================================================================
    % 4. XỬ LÝ SỐ LIỆU VÀ XUẤT ĐỒ THỊ
    % =====================================================================
    plot_results(SIMRESULT, 4, cfg.tdelay);

end

% =========================================================================
% HÀM PHỤ TRỢ: TÍNH TRỄ ĐỊNH TUYẾN DỰA TRÊN THUẬT TOÁN DIJKSTRA
% =========================================================================
function total_router_delay = calculate_routing_delay(src, dst, td, pd)
    % Ma trận kề (Adjacency Matrix) kết nối 4 Router
    adj = [0 0 1 1; 0 0 1 1; 1 1 0 0; 1 1 0 0];               
    
    % Khởi tạo trọng số ngẫu nhiên cho các tuyến cáp
    c = randi([1, 10], 1, 4);               
    edgeweights = [0 0 c(1) c(2); 0 0 c(3) c(4); c(1) c(2) 0 0; c(3) c(4) 0 0]; 
    
    % Gọi hàm dijkstra (nằm trong file dijkstra.m tại thư mục src)
    [costs, paths] = dijkstra(adj, edgeweights);  
    pathlength = cellfun('length', paths); % Số bước nhảy (hop)
    
    rtdelay = 8; % Thời gian xử lý trễ nội bộ của Router (1Gbps)
    
    if src <= 2 && dst >= 3
        % Nguồn ở LAN 1, Đích ở LAN 2
        rcosts = costs(1:2, 3:4);
        [~, index] = min(rcosts(:));                        
        [srouter, drouter] = ind2sub(size(rcosts), index);  
        drouter = drouter + 2;                              
        total_router_delay = ((pathlength(srouter, drouter) - 1) * (rtdelay + pd));         
    else
        % Nguồn ở LAN 2, Đích ở LAN 1
        rcosts = costs(3:4, 1:2);
        [~, index] = min(rcosts(:));                        
        [srouter, drouter] = ind2sub(size(rcosts), index);  
        srouter = srouter + 2; 
        total_router_delay = (pathlength(srouter, drouter) * (td + pd));         
    end
end