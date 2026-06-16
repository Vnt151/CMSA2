% =========================================================================
% FILE CHẠY TRUNG TÂM: main.m
% Đề tài: Mô phỏng giao thức CSMA/CD trong mạng LAN
% Bộ môn: Mạng máy tính
% =========================================================================

clear all; 
clc; 
close all; % Đóng tất cả các cửa sổ đồ thị cũ (nếu có)

% 1. Thiết lập đường dẫn hệ thống (Khai báo các thư mục con với MATLAB)
addpath('src', 'utils');

% 2. Tải cấu hình môi trường mạng từ file config.m
cfg = config();

% =========================================================================
% LỰA CHỌN KỊCH BẢN MÔ PHỎNG (BẠN CHỈ CẦN THAY ĐỔI GIÁ TRỊ TẠI ĐÂY)
% =========================================================================
% Đặt kich_ban = 1 : Chạy mô phỏng mạng đơn đoạn (2 nút A và B chung đường Bus)
% Đặt kich_ban = 2 : Chạy mô phỏng mạng đa đoạn (4 nút kết nối qua Router)
kich_ban = 3; 

% =========================================================================
% QUY TRÌNH KHỞI CHẠY HỆ THỐNG
% =========================================================================
fprintf('==================================================\n');
fprintf('   BẮT ĐẦU CHƯƠNG TRÌNH MÔ PHỎNG GIAO THỨC CSMA/CD\n');
fprintf('==================================================\n');
fprintf('Thông số cấu hình hiện tại:\n');
fprintf(' - Mật độ tải (Lambda)   : %.2f\n', cfg.lambda);
fprintf(' - Thời gian mô phỏng    : %d \\mus\n', cfg.TOTALSIM);
fprintf(' - Thời gian khung hình  : %d \\mus\n', cfg.frameslot);
fprintf('--------------------------------------------------\n');

% Bấm giờ đo hiệu năng xử lý của CPU
tic; 

if kich_ban == 1
    fprintf('>> Đang thực hiện Kịch bản 1: Mạng tuyến tính đơn đoạn (2 nút)...\n');
    csma_cd_single(cfg);
    
elseif kich_ban == 2
    fprintf('>> Đang thực hiện Kịch bản 2: Mạng đa đoạn qua hệ thống Router (4 nút)...\n');
    csma_cd_multi(cfg);

elseif kich_ban == 3
    fprintf('>> Đang thực hiện Kịch bản 3: Bus chung N nút...\n');
    csma_cd_busN(cfg);
    
else
    error('Lỗi: Kịch bản lựa chọn không hợp lệ! Vui lòng chỉ chọn số 1 hoặc 2.');
end

% Hiển thị thời gian hoàn thành
run_time = toc;
fprintf('\n>> Mô phỏng hoàn thành xuất sắc!\n');
fprintf('>> Thời gian CPU xử lý: %.4f giây.\n', run_time);
fprintf('==================================================\n');