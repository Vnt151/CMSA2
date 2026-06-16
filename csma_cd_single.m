function csma_cd_single(cfg)
% CSMA_CD_SINGLE - Mô phỏng mạng CSMA/CD đơn đoạn (2 nút A và B)
%
% ĐẦU VÀO: 
%   cfg : Cấu trúc chứa toàn bộ các thông số môi trường từ file config.m

    % =====================================================================
    % 1. KHỞI TẠO BIẾN HỆ THỐNG
    % =====================================================================
    A = 1; B = 2;
    elist = [];             % Hàng đợi sự kiện (chứa các gói tin đang chờ truyền)
    SIMRESULT = [];         % Nơi lưu trữ các gói tin đã đến đích an toàn
    CLOCK = 0;              % Đồng hồ bấm giờ của hệ thống
    GENTIMECURSOR = [0 0];  % Con trỏ ghi nhớ thời gian đẻ gói cuối cùng của [Nút A, Nút B]
    
    % Các cột định dạng của mảng elist cho kịch bản mạng 2 nút (6 cột)
    SRC = 1; GENTIME = 2; TXTIME = 3; RXTIME = 4; CURTIME = 5;

    % =====================================================================
    % 2. MỒI HỆ THỐNG (Tạo 2 gói tin đầu tiên)
    % =====================================================================
    [elist, GENTIMECURSOR] = create_packet(A, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);
    [elist, GENTIMECURSOR] = create_packet(B, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);

    if isempty(elist)
        disp('Lỗi hệ thống: Không có gói tin nào được khởi tạo!');
        return;
    end

    % =====================================================================
    % 3. VÒNG LẶP MÔ PHỎNG CHÍNH (TRÁI TIM CHƯƠNG TRÌNH)
    % =====================================================================
    while true
        
        % Bước 3.1: Đồng bộ thời gian
        % Xếp hàng các gói tin ưu tiên theo thứ tự thời gian tăng dần
        elist = sortrows(elist, CURTIME);
        CLOCK = elist(1, CURTIME);
        
        src = elist(1, SRC); % Lấy ID của máy chuẩn bị truyền
        
        % Bước 3.2: Kiểm tra chênh lệch thời gian để dò va chạm
        % Bảo vệ code: Nếu hàng đợi chỉ tình cờ còn 1 gói, cho nó truyền luôn (gán chênh lệch vô cực)
        if size(elist, 1) > 1
            timediff = elist(2, CURTIME) - elist(1, CURTIME);
        else
            timediff = inf; 
        end

        % Bước 3.3: Rẽ nhánh xử lý dựa vào nguyên lý Cảm nhận sóng mang (CSMA)
        if timediff > cfg.pd
            % -------------------------------------------------------------
            % NHÁNH 1: KÊNH RỖI (TRUYỀN THÀNH CÔNG)
            % -------------------------------------------------------------
            % Nếu đây là lần truyền đầu tiên, chốt luôn thời điểm bắt đầu truyền
            if elist(1, TXTIME) == 0
                elist(1, TXTIME) = elist(1, CURTIME);
            end
            
            % Ghi nhận thời gian gói tin đến đích = Hiện tại + Tổng trễ hệ thống
            elist(1, RXTIME) = elist(1, CURTIME) + cfg.tdelay;
            
            % Cất gói tin này vào kho kết quả và xóa khỏi hàng đợi chờ
            SIMRESULT = [SIMRESULT; elist(1, :)];
            elist(1, :) = []; 
            
            % Máy này vừa rảnh tay, lập tức đẻ thêm 1 gói tin mới để duy trì mạch dữ liệu
            [elist, GENTIMECURSOR] = create_packet(src, elist, GENTIMECURSOR, cfg.lambda, cfg.frameslot, 6);
            
            % GIỮ KÊNH CHỜ: TrONG suốt thời gian truyền tdelay, mạng bị bận
            % Nếu có gói tin nào lỡ đẻ ra trong lúc này, bắt tụi nó lùi CURTIME lại bằng CLOCK
            CLOCK = CLOCK + cfg.tdelay;
            danh_sach_cho = find((elist(:, CURTIME) - CLOCK) < 0);
            elist(danh_sach_cho, CURTIME) = CLOCK;

        else
            % -------------------------------------------------------------
            % NHÁNH 2: KÊNH BẬN (XẢY RA XUNG ĐỘT)
            % -------------------------------------------------------------
            % Gọi thư viện dùng chung để tiến hành phạt Back-off
            elist = execute_backoff(elist, timediff, cfg.pd, cfg.tbackoff, cfg.maxbackoff);
        end
        
        % Bước 3.4: Điều kiện thoát vòng lặp
        % Thoát khi đồng hồ sinh gói của cả 2 máy đều vượt quá tổng thời gian yêu cầu
        if min(GENTIMECURSOR) > cfg.TOTALSIM
            break;
        end
    end
    
    % =====================================================================
    % 4. XỬ LÝ SỐ LIỆU VÀ XUẤT ĐỒ THỊ
    % =====================================================================
    % Ném thành quả cho file plot_results.m vẽ hình
    plot_results(SIMRESULT, 2, cfg.tdelay);

end