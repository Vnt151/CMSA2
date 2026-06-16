function [elist_new, GENTIMECURSOR_new] = create_packet(nodeid, elist, GENTIMECURSOR, lambda, frameslot, num_cols)
% CREATE_PACKET - Hàm sinh gói tin ngẫu nhiên theo phân phối Poisson
%
% CÁC THAM SỐ ĐẦU VÀO (INPUTS):
%   nodeid        : ID của trạm (máy tính) đang cần sinh gói tin (VD: 1, 2, 3, 4)
%   elist         : Ma trận hàng đợi gói tin hiện tại của kênh truyền
%   GENTIMECURSOR : Mảng lưu mốc thời gian sinh gói tin cuối cùng của các node
%   lambda        : Tần suất sinh gói (Lấy từ file config)
%   frameslot     : Thời gian truyền 1 khung dữ liệu (Lấy từ file config)
%   num_cols      : Định dạng số cột của gói tin (6 cột cho Kịch bản 1, 7 cột cho Kịch bản 2)
%
% ĐẦU RA (OUTPUTS):
%   elist_new         : Ma trận hàng đợi sau khi đã được chèn thêm gói tin mới
%   GENTIMECURSOR_new : Mảng mốc thời gian đã được cập nhật

    % 1. Tính toán thời gian chờ đến gói tin tiếp theo (Inter-arrival time)
    % Sử dụng hàm exprnd để lấy ngẫu nhiên theo phân phối Poisson
    interarvtime = round(frameslot * exprnd(1/lambda, 1, 1));
    
    % 2. Cập nhật mốc thời gian sinh gói (Birth time) cho node hiện tại
    GENTIMECURSOR(nodeid) = GENTIMECURSOR(nodeid) + interarvtime;
    birthtime = GENTIMECURSOR(nodeid);
    
    % 3. Khởi tạo cấu trúc gói tin (Packet) dựa trên kịch bản mạng
    if num_cols == 7
        % Định dạng cho Mạng 4 nút (Part 3)
        % Cấu trúc: [SRC, DEST, GENTIME, TXTIME, RXTIME, CURTIME, COLLISIONS]
        % Lưu ý: DEST tạm thời bằng 0, lát nữa thuật toán chính sẽ chọn ngẫu nhiên sau
        pkt = [nodeid, 0, birthtime, 0, 0, birthtime, 0];
    else
        % Định dạng cho Mạng 2 nút (Part 1)
        % Cấu trúc: [SRC, GENTIME, TXTIME, RXTIME, CURTIME, COLLISIONS]
        pkt = [nodeid, birthtime, 0, 0, birthtime, 0];
    end
    
    % 4. Thêm gói tin mới vào cuối hàng đợi
    elist_new = [elist; pkt];
    
    % 5. Cập nhật lại mốc thời gian để trả về
    GENTIMECURSOR_new = GENTIMECURSOR;
    
end