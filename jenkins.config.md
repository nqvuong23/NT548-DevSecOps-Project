## Hướng Dẫn Cấu Hình Thủ Công (UI) Sau Khi Deploy Jenkins

**Bước 1: Đăng nhập**
1. Mở trình duyệt web và truy cập thẳng vào: **http://jenkins.vuongdevops.io.vn**
*(Nếu Ingress chưa chạy hoặc chưa cấu hình file hosts, có thể tạo đường hầm bằng lệnh: `kubectl port-forward svc/jenkins-release 8080:8080 -n jenkins` rồi truy cập `http://localhost:8080`)*
   
2. Để lấy mật khẩu đăng nhập lần đầu của Jenkins, mở Terminal/CMD và chạy lệnh sau:
```bash
kubectl get secret --namespace jenkins jenkins-release -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

3. Copy đoạn mật khẩu vừa hiện ra, quay lại trình duyệt và đăng nhập với Username là admin.

**Bước 2: Lưu Token của SonarQube vào Jenkins**
1. Ở menu bên trái, chọn **Manage Jenkins** > **Credentials**.
2. Nhấp vào domain `(global)` > Bấm **Add Credentials**.
3. Điền các thông tin sau:
   - Kind: Chọn `Secret text`.
   - Secret: Dán đoạn mã Token của SonarQube đã copy ở Phần 1 vào đây.
   - ID: Nhập chính xác là `sonarqube-token` (Bắt buộc phải khớp với ID ghi trong file Jenkinsfile).
   - Description: `Token ket noi SonarQube`.
4. Bấm **Create**.

**Bước 3: Tạo Pipeline Job**
1. Quay ra trang chủ Jenkins, bấm **New Item**.
2. Nhập tên Job: `DevSecOps-Pipeline-Nhom10`.
3. Chọn loại **Pipeline** và bấm **OK**.
4. Cuộn xuống mục **Pipeline**, thiết lập như sau:
   - Definition: Chọn `Pipeline script from SCM`.
   - SCM: Chọn `Git`.
   - Repository URL: Dán link GitHub repo của nhóm vào.
   - Branch Specifier: `*/main`.
   - Script Path: Nhập `Jenkinsfile`.
5. Tích vào ô **GitHub hook trigger for GITScm polling** ở mục Build Triggers.
6. Bấm **Save**.

**Bước 4: Cấu hình GitHub Webhook (tự động trigger Pipeline khi push code)**
1. Vào GitHub repo → **Settings** → **Webhooks** → **Add webhook**.
2. Điền thông tin:
   - Payload URL: `http://jenkins.vuongdevops.io.vn/github-webhook/`
   - Content type: `application/json`
   - Which events: chọn **Just the push event**.
3. Bấm **Add webhook**.
