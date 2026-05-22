## Hướng Dẫn Cấu Hình Thủ Công (UI) Sau Khi Deploy Jenkins

### Bước 1: Đăng nhập

1. Mở trình duyệt web và truy cập thẳng vào: **http://jenkins.vuongdevops.io.vn**
*(Nếu Ingress chưa chạy hoặc chưa cấu hình file hosts, có thể tạo đường hầm bằng lệnh: `kubectl port-forward svc/jenkins-release 8080:8080 -n jenkins` rồi truy cập `http://localhost:8080`)*
   
2. Để lấy mật khẩu đăng nhập lần đầu của Jenkins, mở Terminal/CMD và chạy lệnh sau:
```bash
kubectl get secret --namespace jenkins jenkins-release -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

3. Copy đoạn mật khẩu vừa hiện ra, quay lại trình duyệt và đăng nhập với Username là admin.

---

### Bước 2: Lưu SSH Private Key vào Jenkins Credentials và cấu hình Git Host Key Verification

1. Ở góc trên bên phải, chọn Manage Jenkins (biểu tượng răng cưa) > Credentials > Click `Add Credentials`.
2. Điền các thông tin sau:
   - Kind: Chọn `SSH Username with private key` > Nhấn `Next`.
   - Scope: Chọn `Global`.
   - ID: Nhập `ssh-private-key`.
   - Username: Nhập `ssh-private-key`.
   - Private Key: Chọn `Enter directly`, sau đó copy nội dung file `/keys/jenkins_ssh_key` và điền vào đây.
   - Bấm Create.
3. Quay lại giao diện Manage Jenkins > Security.
4. Kéo xuống tìm mục **Git Host Key Verification Configuration**.
5. Tại mục **Host Key Verification Strategy**, chọn **No verification** (hoặc **Accept first connection**).
6. Nhấn **Save**.

---

### Bước 3: Tạo Pipeline Job

1. Quay ra trang chủ Jenkins, bấm **New Item**.
2. Nhập tên Job: `DevSecOps-Pipeline-Nhom10`.
3. Chọn loại **Pipeline** và bấm **OK**.
4. Cuộn xuống mục **Pipeline**, thiết lập như sau:
   - Definition: Chọn `Pipeline script from SCM`.
   - SCM: Chọn `Git`.
   - Repository URL: Dán link GitHub repo của nhóm vào (không phải HTTPS URL, dùng SSH).
   - Branch Specifier: `*/main`.
   - Script Path: Nhập `Jenkinsfile`.
5. Tích vào ô **GitHub hook trigger for GITScm polling** ở mục Build Triggers.
6. Bấm **Save**.

---

### Bước 4: Cấu hình GitHub Webhook (tự động trigger Pipeline khi push code - chỉ làm 1 lần duy nhất)

1. Vào GitHub repo → **Settings** → **Webhooks** → **Add webhook**.
2. Điền thông tin:
   - Payload URL: `https://jenkins.vuongdevops.io.vn/github-webhook/`
   - Content type: `application/json`
   - Which events: chọn **Just the push event**.
3. Bấm **Add webhook**.

---

### Bước 5: Thêm SSH Public Key vào GitHub Account của thành viên nhóm để cho phép Jenkins push/pull tới Repository + trigger Jenkins (do Admin/Nhóm trưởng làm 1 lần duy nhất)

---

### Bước 6: Cấu hình Jenkins sử dụng HashiCorp Vault

1. Vào Manage Jenkins (biểu tượng răng cưa) > Credentials > Add Credentials. Điền các thông tin sau:
   - Kind: Chọn `Vault AppRole Credential`.
   - Role ID: Dán mã `RoleID` bạn vừa lấy ở trên.
   - Secret ID: Dán mã `SecretID` bạn vừa lấy ở trên.
   - ID: Nhập `jenkins-vault-approle`.
   - Bấm Create
2. Vào Manage Jenkins > System > Tìm đến mục Vault Plugin. Nhập các thông tin sau:
   - Vault URL: Nhập `http://vault.vault.svc.cluster.local:8200`
   - Vault Credentials: Chọn `jenkins-vault-approle`
   - Apply and Save
