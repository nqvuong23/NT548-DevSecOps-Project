## Hướng Dẫn Cấu Hình Thủ Công (UI) Sau Khi Deploy SonarQube

**Bước 1: Đăng nhập**

1. Truy cập URL: http://sonarqube.vuongdevops.io.vn/
2. Đăng nhập bằng tài khoản mặc định (Username: admin, Password: admin).
3. Sonarqube Web sẽ thông báo thay đổi mật khẩu, hãy nhập mật khẩu mới và share với thành viên trong nhóm biết.

**Bước 2: Tạo Project**
1. Chọn tab **Projects** trên thanh menu trên cùng.
2. Bấm **Create a local project**.
3. Tại ô *Project display name* và *Project key*, nhập chính xác tên: `DevSecOps_Nhom10`.
4. Chọn **Follows the instance's default**
5. Bấm **Creat project**.

**Bước 3: Tạo Token để cấp quyền cho Jenkins**
1. Chọn dự án **DevSecOps_Nhom10** vừa tạo.
2. Tại **Project onboarding** chọn **Locally**.
3. Ở phần *Generate Tokens*:
   - Name: Nhập tên tùy ý (VD: `jenkins-token`).
   - Type: Chọn `Global Analysis Token` (hoặc Project Token).
   - Expires in: Chọn `No expiration`.
4. Bấm **Generate**. 
5. **QUAN TRỌNG:** Copy ngay đoạn mã Token vừa hiện ra và lưu tạm ra Notepad (vì nó chỉ hiện 1 lần duy nhất).

**Bước 4: Thiết lập Webhook (Quality Gate)**
1. Quay lại trang chủ SonarQube, bấm vào dự án `DevSecOps_Nhom10` vừa tạo.
2. Chọn menu **Project Settings** > **Webhooks**.
3. Bấm **Create** và điền thông tin:
   - Name: `Jenkins Webhook`
   - URL: `http://jenkins-release.jenkins.svc.cluster.local:8080/sonarqube-webhook/`
4. Bấm **Create** để lưu lại.
