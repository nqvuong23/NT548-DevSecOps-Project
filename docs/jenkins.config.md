## Hướng Dẫn Cấu Hình Thủ Công (UI) Sau Khi Deploy Jenkins

**Bước 1: Đăng nhập**
1. Mở trình duyệt web và truy cập thẳng vào: **http://jenkins.vuongdevops.io.vn**
*(Nếu Ingress chưa chạy hoặc chưa cấu hình file hosts, có thể tạo đường hầm bằng lệnh: `kubectl port-forward svc/jenkins-release 8080:8080 -n jenkins` rồi truy cập `http://localhost:8080`)*
   
2. Để lấy mật khẩu đăng nhập lần đầu của Jenkins, mở Terminal/CMD và chạy lệnh sau:
```bash
kubectl get secret --namespace jenkins jenkins-release -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode
```

3. Copy đoạn mật khẩu vừa hiện ra, quay lại trình duyệt và đăng nhập với Username là admin.

**Bước 2: Lưu Token của SonarQube và SSH Private Key vào Jenkins**
1. Ở góc trên bên phải, chọn **Manage Jenkins** (biểu tượng răng cưa) > **Credentials**.
2. Nhấp vào domain `(global)` > Bấm **Add Credentials**.
3. Điền các thông tin sau cho Token của SonarQube:
   - Kind: Chọn `Secret text`.
   - Scope: Chọn `Global`.
   - Secret: Dán đoạn mã Token của SonarQube đã copy ở Phần 1 vào đây.
   - ID: Nhập chính xác là `sonarqube-token` (Bắt buộc phải khớp với ID ghi trong file Jenkinsfile).
   - Description: `Token ket noi SonarQube`.
4. Bấm **Create**.
5. Tiếp tục tạo Credential cho SSH Private Key như sau:
   - Kind: Chọn `SSH Username with private key`.
   - Scope: Chọn `Global`.
   - ID: Nhập `jenkins-ssh-key`.
   - Username: Nhập `jenkins-ssh-key`.
   - Private Key: Chọn `Enter directly`, sau đó copy nội dung file `./jenkins_ssh_key` và điền vào đây.
   - Bấm **Create**.

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

**Bước 5: Thêm SSH Public Key vào tài khoản GitHub để cho phép Jenkins push/pull tới Repository (do Admin/Nhóm trưởng làm 1 lần duy nhất)**

**Bước 6: Cấu hình Jenkins sử dụng HashiCorp Vault**

1. Vào Manage Jenkins (biểu tượng răng cưa) > Credentials > Add Credentials. Điền các thông tin sau:
   - Kind: Chọn Vault AppRole Credential.
   - Role ID: Dán mã RoleID bạn vừa lấy ở trên.
   - Secret ID: Dán mã SecretID bạn vừa lấy ở trên.
   - ID: Nhập `jenkins-vault-approle`.
   - Bấm Create
2. Vào Manage Jenkins > System > Tìm đến mục Vault Plugin. Nhập các thông tin sau:
   - Vault URL: Nhập `http://vault.vault.svc.cluster.local:8200`
   - Vault Credentials: Chọn `jenkins-vault-approle`
   - Apply and Save

## Mẫu Pipeline test Jenkins lấy secret từ HashiCorp Vault:

```
pipeline {
    agent any
    environment {
        VAULT_CREDS = 'jenkins-vault-approle' 
    }
    stages {
        stage('Get Vault Secrets') { 
            steps {
                withVault(
                    configuration: [
                        vaultUrl: 'http://vault.vault.svc.cluster.local:8200',
                        vaultCredentialId: "${VAULT_CREDS}", 
                        engineVersion: 2
                    ],
                    vaultSecrets: [[
                        path: 'devsecops_nhom10/sonarqube/token', 
                        secretValues: [
                            [envVar: 'Token', vaultKey: 'token']
                        ]
                    ]]
                ) {
                    sh 'echo $Token' 
                }
            }
        }
    }
}
```