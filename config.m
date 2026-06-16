function cfg = config()
% CONFIG - File cấu hình trung tâm cho hệ thống mô phỏng CSMA/CD
% Quản lý toàn bộ thông số vật lý, thời gian và mật độ tải của mạng.

    % =====================================================================
    % 1. THÔNG SỐ ĐIỀU CHỈNH MỨC TẢI (THAY ĐỔI ĐỂ ĐÁNH GIÁ HIỆU NĂNG)
    % =====================================================================
    % Điều chỉnh biến lambda để tạo ra các điều kiện tải khác nhau:
    % - Tải nhẹ       : lambda = 0.1  hoặc 0.2
    % - Tải trung bình: lambda = 0.5  (Thông số mặc định)
    % - Tải cao       : lambda = 1.5  hoặc 2.0 (Gây nghẽn mạng)
    
    cfg.lambda = 0.1; 
    
    % =====================================================================
    % 2. THÔNG SỐ THỜI GIAN VÀ MÔI TRƯỜNG VẬT LÝ
    % =====================================================================
    cfg.TOTALSIM = 30 * 10^3;  % Tổng thời gian chạy mô phỏng (30,000 đơn vị thời gian)
    cfg.frameslot = 50;       % Thời gian truyền xong 1 khung dữ liệu
    cfg.td = 80;               % Trễ truyền dẫn dữ liệu lên kênh (Transmission delay)
    cfg.pd = 10;               % Trễ lan truyền tín hiệu trên cáp (Propagation delay)
    
    % Tổng trễ cơ bản (Tổng thời gian từ lúc bắt đầu đẩy dữ liệu đến khi nhận xong)
    cfg.tdelay = cfg.td + cfg.pd;
    
    % =====================================================================
    % 3. THÔNG SỐ THUẬT TOÁN LÙI THỜI GIAN (EXPONENTIAL BACK-OFF)
    % =====================================================================
    cfg.tbackoff = cfg.frameslot; % Đơn vị thời gian cho 1 slot chờ
    cfg.maxbackoff = 3;           % Giới hạn bậc lùi hàm mũ tối đa (2^3 = 8 slot)
    
end