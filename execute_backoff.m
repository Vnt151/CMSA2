function elist = execute_backoff(elist, timediff, pd, tbackoff, maxbackoff)
% EXECUTE_BACKOFF - Hàm tính toán lùi thời gian theo hàm mũ khi xảy ra xung đột
%
% CÁC THAM SỐ ĐẦU VÀO:
%   elist      : Ma trận hàng đợi gói tin hiện tại của một kênh truyền
%   timediff   : Độ chênh lệch thời gian phát giữa 2 gói tin đầu tiên
%   pd         : Trễ lan truyền (Propagation delay)
%   tbackoff   : Đơn vị thời gian lùi (thường bằng 1 frame slot)
%   maxbackoff : Giới hạn mũ tối đa (ví dụ: 3)
%
% ĐẦU RA:
%   elist      : Ma trận hàng đợi sau khi đã được cập nhật thời gian phạt

    % 1. Tự động nhận diện cấu trúc cột (6 cột cho mạng 2 nút, 7 cột cho mạng 4 nút)
    num_cols = size(elist, 2);
    if num_cols == 7
        SRC = 1; TXTIME = 4; CURTIME = 6; COLLISIONS = 7;
    else
        SRC = 1; TXTIME = 3; CURTIME = 5; COLLISIONS = 6;
    end
    
    % 2. Cập nhật thời gian bắt đầu truyền (TXTIME) nếu là lần truyền đầu tiên
    if elist(1, TXTIME) == 0
        elist(1, TXTIME) = elist(1, CURTIME);
    end
    if elist(2, TXTIME) == 0
        elist(2, TXTIME) = elist(2, CURTIME);
    end
    
    % 3. Tăng biến đếm số lần xung đột (Collisions) lên 1 đơn vị cho cả 2 gói
    elist(1, COLLISIONS) = elist(1, COLLISIONS) + 1;
    elist(2, COLLISIONS) = elist(2, COLLISIONS) + 1;
    
    % 4. Tính toán thời gian lùi (Exponential Back-off)
    % Đảm bảo số lần xung đột dùng để tính mũ không vượt quá maxbackoff
    c1 = min(elist(1, COLLISIONS), maxbackoff);
    c2 = min(elist(2, COLLISIONS), maxbackoff);
    
    % Lấy ngẫu nhiên từ 0 đến (2^k - 1) rồi nhân với slot time
    bk1 = (randi(2^c1) - 1) * tbackoff;
    bk2 = (randi(2^c2) - 1) * tbackoff;
    
    % 5. Tính toán tổng thời gian trễ phải chịu
    node1 = elist(1, SRC);
    node2 = elist(2, SRC);
    
    delay1 = pd + timediff + bk1;
    delay2 = pd - timediff + bk2;
    
    % 6. Áp dụng thời gian phạt cho toàn bộ các gói tin của trạm tương ứng
    elist = apply_node_delay(elist, node1, delay1, SRC, CURTIME);
    elist = apply_node_delay(elist, node2, delay2, SRC, CURTIME);
    
end

% --- HÀM PHỤ TRỢ (Nằm gọn bên trong cùng file) ---
function elist = apply_node_delay(elist, node, delay, SRC, CURTIME)
    % Hàm này thay thế cho hàm delaynodepkts lồng rườm rà ở file gốc
    % Mục đích: Bắt tất cả các gói tin tiếp theo của trạm này phải lùi thời gian lại
    
    % Tìm gói tin đầu tiên của trạm này
    idx = find(elist(:, SRC) == node, 1, 'first');
    
    if ~isempty(idx)
        t_current = elist(idx, CURTIME);
        DELAYTIME = t_current + delay;
        
        % Tìm tất cả các gói tin của trạm này có thời gian dự kiến truyền < DELAYTIME
        list = find((elist(:, CURTIME) - DELAYTIME < 0) & (elist(:, SRC) == node));
        
        % Cập nhật lại thời gian truyền mới
        elist(list, CURTIME) = DELAYTIME;
    end
end